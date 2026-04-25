// 路徑: lib/admin/admin_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../pages/auth/login_page.dart';
import '../services/local_storage.dart';
import '../config/database.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  List _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedMType = 'ALL';
  late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); _loadUsers(); }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await ApiService.getAllUsersForAdmin();
    if (mounted) setState(() { _users = users; _isLoading = false; });
  }

  Future<void> _logout() async {
    await LocalStorage.logout();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  void _showEditDialog(Map<String, dynamic> user) {
    final lang        = Provider.of<LanguageProvider>(context, listen: false);
    final fNameCtrl   = TextEditingController(text: user['fName']);
    final nNameCtrl   = TextEditingController(text: user['nName']);
    final emailCtrl   = TextEditingController(text: user['email']);
    final telCtrl     = TextEditingController(text: user['tel'].toString());
    final addressCtrl = TextEditingController(text: user['address']);
    String mType      = user['mType'] ?? 'STUDENT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${lang.t('edit_account')}: ${user['mId']}'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: fNameCtrl, decoration: InputDecoration(labelText: lang.isEnglish ? 'Full Name' : '全名 (fName)')),
            TextField(controller: nNameCtrl, decoration: InputDecoration(labelText: lang.isEnglish ? 'Nickname' : '暱稱 (nName)')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: telCtrl,   decoration: InputDecoration(labelText: lang.isEnglish ? 'Phone' : '電話 (Tel)'), keyboardType: TextInputType.phone),
            TextField(controller: addressCtrl, decoration: InputDecoration(labelText: lang.isEnglish ? 'Address' : '地址 (Address)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: mType,
              decoration: InputDecoration(labelText: '${lang.t('role')} (mType)'),
              items: [
                DropdownMenuItem(value: 'STUDENT', child: Text(lang.isEnglish ? 'Student (STUDENT)' : '學生 (STUDENT)')),
                DropdownMenuItem(value: 'TEACHER', child: Text(lang.isEnglish ? 'Teacher (TEACHER)' : '老師 (TEACHER)')),
                DropdownMenuItem(value: 'ADMIN',   child: Text(lang.isEnglish ? 'Admin (ADMIN)'     : '管理員 (ADMIN)')),
              ],
              onChanged: (val) { if (val != null) setDialogState(() => mType = val); },
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); setState(() => _isLoading = true);
                bool success = await ApiService.updateUserByAdmin({
                  'mId': user['mId'], 'fName': fNameCtrl.text, 'nName': nNameCtrl.text,
                  'email': emailCtrl.text, 'tel': telCtrl.text, 'address': addressCtrl.text, 'mType': mType,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? lang.t('update_success') : lang.t('update_failed')),
                    backgroundColor: success ? Colors.green : Colors.red));
                  _loadUsers();
                }
              },
              child: Text(lang.t('save_changes')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(lang.t('admin_dashboard')),
        backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
        actions: [
          // Language toggle
          TextButton(
            onPressed: () => lang.toggleLanguage(),
            child: Text(lang.isEnglish ? '中文' : 'EN', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
          IconButton(icon: const Icon(Icons.logout),  onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(icon: const Icon(Icons.people),   text: lang.isEnglish ? 'Accounts' : '帳戶管理'),
            Tab(icon: const Icon(Icons.flag),     text: lang.isEnglish ? 'Reports'  : '檢舉管理'),
            Tab(icon: const Icon(Icons.campaign), text: lang.isEnglish ? 'News'     : '最新消息'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserManagement(lang),
          ReportsManagementTab(lang: lang),
          AnnouncementManagementTab(lang: lang),
        ],
      ),
    );
  }

  Widget _buildUserManagement(LanguageProvider lang) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final query    = _searchQuery.toLowerCase();
    final filtered = _users.where((user) {
      final matchSearch = query.isEmpty || (user['mId'] ?? '').toLowerCase().contains(query) ||
          (user['fName'] ?? '').toLowerCase().contains(query) || (user['nName'] ?? '').toLowerCase().contains(query);
      final matchType = _selectedMType == 'ALL' || (user['mType'] ?? '') == _selectedMType;
      return matchSearch && matchType;
    }).toList();

    final roleFilters = [
      ('ALL',     lang.isEnglish ? 'All'     : '全部',  Colors.deepPurple, Icons.people),
      ('STUDENT', lang.isEnglish ? 'Student' : '學生',  Colors.blueAccent, Icons.person),
      ('TEACHER', lang.isEnglish ? 'Teacher' : '老師',  Colors.redAccent,  Icons.school),
      ('ADMIN',   lang.isEnglish ? 'Admin'   : '管理員', Colors.purple,    Icons.security),
    ];

    return Column(children: [
      Container(
        color: Colors.white, padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: lang.isEnglish ? 'Search ID / Name...' : '搜尋 mId / 全名 / 暱稱...',
            prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
            suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = '')) : null,
            filled: true, fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
      Container(
        color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Text('${lang.t('role')}：', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(width: 6),
            for (final item in roleFilters)
              Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
                avatar: Icon(item.$4, size: 14, color: _selectedMType == item.$1 ? item.$3 : Colors.grey[500]),
                label: Text(item.$2), selected: _selectedMType == item.$1,
                selectedColor: item.$3.withOpacity(0.15), checkmarkColor: item.$3,
                labelStyle: TextStyle(color: _selectedMType == item.$1 ? item.$3 : Colors.black54,
                    fontWeight: _selectedMType == item.$1 ? FontWeight.bold : FontWeight.normal, fontSize: 12),
                onSelected: (_) => setState(() => _selectedMType = item.$1),
              )),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text('${lang.isEnglish ? 'Total' : '共'} ${filtered.length} ${lang.isEnglish ? 'accounts' : '個帳戶'}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12))),
      ),
      Expanded(
        child: filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off, color: Colors.grey[300], size: 56), const SizedBox(height: 12),
                Text(lang.isEnglish ? 'No matching accounts' : '沒有符合的帳戶', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(8), itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final user = filtered[i];
                  return Card(
                    elevation: 2, margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: user['mType'] == 'ADMIN' ? Colors.purple : (user['mType'] == 'TEACHER' ? Colors.redAccent : Colors.blueAccent),
                        child: Icon(user['mType'] == 'ADMIN' ? Icons.security : (user['mType'] == 'TEACHER' ? Icons.school : Icons.person), color: Colors.white),
                      ),
                      title: Text("${user['fName']} (${user['mId']})", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${user['mType']} | 📞 ${user['tel']}"),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("📧 ${lang.isEnglish ? 'Email' : '電郵'}: ${user['email']}"),
                            Text("🏠 ${lang.isEnglish ? 'Address' : '地址'}: ${user['address']}"),
                            const Divider(height: 24),
                            Text("📚 ${lang.t('enrolled_courses')}:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity, padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: Text(user['enrolled_courses'] ?? lang.t('no_enrollment'),
                                  style: const TextStyle(color: Colors.black87, height: 1.5)),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(width: double.infinity, child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: Text(lang.t('edit_account')),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12)),
                              onPressed: () => _showEditDialog(user),
                            )),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

// ══ Reports Management Tab ══════════════════════════════════
class ReportsManagementTab extends StatefulWidget {
  final LanguageProvider lang;
  const ReportsManagementTab({super.key, required this.lang});
  @override
  State<ReportsManagementTab> createState() => _ReportsManagementTabState();
}

class _ReportsManagementTabState extends State<ReportsManagementTab> {
  String _filter = 'pending';

  List<Map<String, dynamic>> get _banDurations => [
    {'label': widget.lang.isEnglish ? '3 Days' : '3 天',   'days': 3,    'icon': Icons.looks_3},
    {'label': widget.lang.isEnglish ? '1 Week' : '1 星期', 'days': 7,    'icon': Icons.view_week},
    {'label': widget.lang.isEnglish ? '1 Month': '1 個月', 'days': 30,   'icon': Icons.calendar_month},
    {'label': widget.lang.isEnglish ? '1 Year' : '1 年',   'days': 365,  'icon': Icons.calendar_today},
    {'label': widget.lang.isEnglish ? 'Permanent' : '永久', 'days': null, 'icon': Icons.block},
  ];

  Future<void> _showBanDialog(String reportId, String reportedUserId, String reportedDisplayName, String reportedText) async {
    final lang = widget.lang;
    int? selectedDays = 7;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Row(children: [const Icon(Icons.gavel, color: Colors.red), const SizedBox(width: 8), Text(lang.t('mute_duration'))]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.person, size: 14, color: Colors.red), const SizedBox(width: 6),
              Text(reportedDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
            Text('ID: $reportedUserId', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ])),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Text('"$reportedText"', style: const TextStyle(color: Colors.black54, fontSize: 13, fontStyle: FontStyle.italic))),
        const SizedBox(height: 16),
        Text('${lang.isEnglish ? 'Mute Duration' : '禁言時長'}：', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _banDurations.map((d) {
          final isSelected  = selectedDays == d['days'];
          final isPermanent = d['days'] == null;
          return GestureDetector(
            onTap: () => setDialogState(() => selectedDays = d['days']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? (isPermanent ? Colors.red : Colors.deepPurple) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? (isPermanent ? Colors.red : Colors.deepPurple) : Colors.grey[300]!, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(d['icon'] as IconData, size: 16, color: isSelected ? Colors.white : (isPermanent ? Colors.red : Colors.grey[600])),
                const SizedBox(width: 6),
                Text(d['label'] as String, style: TextStyle(
                    color: isSelected ? Colors.white : (isPermanent ? Colors.red : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
              ]),
            ),
          );
        }).toList()),
        if (selectedDays == null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [const Icon(Icons.warning_amber, color: Colors.red, size: 16), const SizedBox(width: 6),
                Text(lang.t('permanent_mute_warning'), style: const TextStyle(color: Colors.red, fontSize: 12))])),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('cancel'))),
        ElevatedButton.icon(
          icon: const Icon(Icons.gavel, size: 16),
          label: Text(selectedDays == null ? lang.t('confirm_permanent_mute') : lang.t('confirm_mute')),
          style: ElevatedButton.styleFrom(backgroundColor: selectedDays == null ? Colors.red : Colors.deepPurple, foregroundColor: Colors.white),
          onPressed: () async { Navigator.pop(ctx); await _executeBan(reportId, reportedUserId, reportedDisplayName, reportedText, selectedDays); },
        ),
      ],
    )));
  }

  Future<void> _executeBan(String reportId, String userId, String displayName, String reason, int? days) async {
    final lang = widget.lang;
    DateTime? bannedUntil;
    if (days != null) bannedUntil = DateTime.now().add(Duration(days: days));
    final batch = FirebaseFirestore.instance.batch();
    batch.set(FirebaseFirestore.instance.collection('banned_users').doc(userId), {
      'userId': userId, 'displayName': displayName, 'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': 'admin', 'reason': reason,
      'bannedUntil': bannedUntil != null ? Timestamp.fromDate(bannedUntil) : null, 'durationDays': days,
    });
    batch.update(FirebaseFirestore.instance.collection('reports').doc(reportId), {
      'status': 'banned', 'processedAt': FieldValue.serverTimestamp(), 'processedBy': 'admin', 'banDurationDays': days,
    });
    await batch.commit();
    final pending = await FirebaseFirestore.instance.collection('reports').where('reportedUserId', isEqualTo: userId).get();
    for (final doc in pending.docs) {
      if ((doc.data()['status'] ?? '') == 'pending') {
        await doc.reference.update({'status': 'banned', 'processedAt': FieldValue.serverTimestamp(), 'processedBy': 'admin'});
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⛔ $displayName ($userId) ${lang.isEnglish ? 'has been muted' : '已被全域禁言'} ${days == null ? lang.t('permanent') : "$days ${lang.t('days')}"}'),
        backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
    }
  }

  Future<void> _dismissReport(String reportId) async {
    final lang       = widget.lang;
    final reportDoc  = await FirebaseFirestore.instance.collection('reports').doc(reportId).get();
    final data       = reportDoc.data() ?? {};
    final reportedUserId  = data['reportedUserId'] ?? data['reportedUser'] ?? '';
    final chatCollection  = data['chatCollection'] ?? '';
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('reports').doc(reportId),
        {'status': 'dismissed', 'processedAt': FieldValue.serverTimestamp(), 'processedBy': 'admin'});
    if (reportedUserId.isNotEmpty && chatCollection.isNotEmpty) {
      batch.delete(FirebaseFirestore.instance.collection('chat_bans').doc('${chatCollection}_$reportedUserId'));
    }
    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang.isEnglish ? '✅ Report dismissed' : '✅ 已駁回此檢舉，禁言已解除'), backgroundColor: Colors.grey, duration: const Duration(seconds: 2)));
  }

  Future<void> _unbanUser(String reportId, String userId, String displayName) async {
    final lang    = widget.lang;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(lang.t('unmute')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lang.t('unmute_confirm')), const SizedBox(height: 8),
        Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text('ID: $userId', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.t('cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lang.t('confirm_unmute'))),
      ],
    ));
    if (confirm != true) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance.collection('banned_users').doc(userId));
    batch.update(FirebaseFirestore.instance.collection('reports').doc(reportId),
        {'status': 'dismissed', 'processedAt': FieldValue.serverTimestamp()});
    await batch.commit();
    final chatBans = await FirebaseFirestore.instance.collection('chat_bans').get();
    for (final doc in chatBans.docs) { if ((doc.data()['userId'] ?? '') == userId) await doc.reference.delete(); }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${lang.isEnglish ? 'Unmuted' : '已解除'} $displayName ${lang.isEnglish ? '' : '的禁言'}'), backgroundColor: Colors.green));
  }

  Color  _statusColor(String s) => s == 'pending' ? Colors.orange : s == 'banned' ? Colors.red : Colors.grey;
  String _statusLabel(String s, LanguageProvider lang) {
    if (s == 'pending')   return lang.isEnglish ? 'Pending'   : '待審核';
    if (s == 'banned')    return lang.isEnglish ? 'Muted'     : '已禁言';
    return lang.isEnglish ? 'Dismissed' : '已駁回';
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final filterOptions = [
      ('all',       lang.isEnglish ? 'All'       : '全部',  Colors.deepPurple),
      ('pending',   lang.isEnglish ? 'Pending'   : '待審核', Colors.orange),
      ('banned',    lang.isEnglish ? 'Muted'     : '已禁言', Colors.red),
      ('dismissed', lang.isEnglish ? 'Dismissed' : '已駁回', Colors.grey),
    ];

    return Column(children: [
      Container(
        color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Text(lang.isEnglish ? 'Filter:' : '篩選：', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(width: 8),
          Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final f in filterOptions)
              Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
                label: Text(f.$2), selected: _filter == f.$1,
                selectedColor: f.$3.withOpacity(0.2), checkmarkColor: f.$3,
                labelStyle: TextStyle(color: _filter == f.$1 ? f.$3 : Colors.black54,
                    fontWeight: _filter == f.$1 ? FontWeight.bold : FontWeight.normal),
                onSelected: (_) => setState(() => _filter = f.$1),
              )),
          ]))),
        ]),
      ),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('${lang.isEnglish ? 'Error' : '錯誤'}：${snapshot.error}'));
          final allDocs = snapshot.data?.docs ?? [];
          final docs = _filter == 'all' ? allDocs : allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['status'] ?? 'pending') == _filter;
          }).toList();

          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline, color: Colors.green[300], size: 56), const SizedBox(height: 16),
              Text(_filter == 'pending' ? (lang.isEnglish ? 'No pending reports 🎉' : '目前沒有待審核的檢舉 🎉')
                  : (lang.isEnglish ? 'No matching records' : '沒有符合的紀錄'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8), itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc  = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final status               = data['status'] ?? 'pending';
              final reportedUserId       = data['reportedUserId']        ?? data['reportedUser'] ?? '';
              final reportedDisplayName  = data['reportedDisplayName']   ?? data['reportedUser'] ?? 'Unknown';
              final reportedText         = data['reportedText']          ?? '';
              final reportedByDisplayName = data['reportedByDisplayName'] ?? data['reportedBy']  ?? '';
              final channelName          = data['channelName']           ?? '';
              final teacherName          = data['teacherName']           ?? '';
              final timestamp            = data['timestamp'] as Timestamp?;
              final banDays              = data['banDurationDays'];

              return Card(
                elevation: 2, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _statusColor(status).withOpacity(0.4), width: 1.5)),
                child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 18, backgroundColor: _statusColor(status).withOpacity(0.15),
                        child: Icon(Icons.flag, color: _statusColor(status), size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(reportedDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('ID: $reportedUserId', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      if (timestamp != null) Text(_formatTimestamp(timestamp), style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12), border: Border.all(color: _statusColor(status).withOpacity(0.5))),
                        child: Text(_statusLabel(status, lang), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      if (status == 'banned' && banDays != null) ...[
                        const SizedBox(height: 4),
                        Text(banDays == null ? lang.t('permanent') : '$banDays ${lang.t('days')}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  Container(width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
                      child: Text('"$reportedText"', style: const TextStyle(fontSize: 13, color: Colors.black87, fontStyle: FontStyle.italic))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    _infoChip(Icons.person_outline, '${lang.isEnglish ? 'Reporter' : '檢舉人'}: $reportedByDisplayName', Colors.blue),
                    _infoChip(Icons.live_tv,        '${lang.isEnglish ? 'Channel'  : '頻道'}: $channelName',             Colors.purple),
                    if (teacherName.isNotEmpty) _infoChip(Icons.school, '${lang.isEnglish ? 'Teacher' : '教師'}: $teacherName', Colors.teal),
                  ]),
                  if (status == 'pending') ...[
                    const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                          icon: const Icon(Icons.close, size: 16), label: Text(lang.t('dismiss')),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[600], side: BorderSide(color: Colors.grey[400]!)),
                          onPressed: () => _dismissReport(doc.id))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton.icon(
                          icon: const Icon(Icons.gavel, size: 16), label: Text(lang.isEnglish ? 'Mute' : '禁言'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => _showBanDialog(doc.id, reportedUserId, reportedDisplayName, reportedText))),
                    ]),
                  ],
                  if (status == 'banned') ...[
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        icon: const Icon(Icons.lock_open, size: 16), label: Text(lang.t('unmute')),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                        onPressed: () => _unbanUser(doc.id, reportedUserId, reportedDisplayName))),
                  ],
                ])),
              );
            },
          );
        },
      )),
    ]);
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color), const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate().toLocal();
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ══ Announcement Management Tab ═════════════════════════════
class AnnouncementManagementTab extends StatefulWidget {
  final LanguageProvider lang;
  const AnnouncementManagementTab({super.key, required this.lang});
  @override
  State<AnnouncementManagementTab> createState() => _AnnouncementManagementTabState();
}

class _AnnouncementManagementTabState extends State<AnnouncementManagementTab> {
  static const String _getUrl    = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_announcements.php';
  static const String _createUrl = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/create_announcement.php';
  static const String _deleteUrl = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/delete_announcement.php';

  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _selectedCategory = 'general';
  bool _isPosting  = false;
  bool _isLoading  = true;
  List _announcements = [];

  Map<String, Map<String, dynamic>> get _categories => {
    'general':     {'label': widget.lang.isEnglish ? '📢 General'     : '📢 一般消息', 'color': const Color(0xFF6366F1)},
    'update':      {'label': widget.lang.isEnglish ? '🔄 Update'      : '🔄 版本更新', 'color': const Color(0xFF22C55E)},
    'maintenance': {'label': widget.lang.isEnglish ? '🔧 Maintenance' : '🔧 系統維護', 'color': const Color(0xFFF59E0B)},
  };

  @override
  void initState() { super.initState(); _loadAnnouncements(); }

  @override
  void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final resp = await http.get(Uri.parse(_getUrl));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted && data['success'] == true) { setState(() { _announcements = data['announcements'] ?? []; _isLoading = false; }); return; }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _postAnnouncement() async {
    final lang    = widget.lang;
    final title   = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.isEnglish ? 'Please fill in title and content' : '請填寫標題和內容'), backgroundColor: Colors.orange)); return;
    }
    setState(() => _isPosting = true);
    try {
      final resp = await http.post(Uri.parse(_createUrl), body: {'title': title, 'content': content, 'category': _selectedCategory});
      final data = jsonDecode(resp.body);
      if (mounted) {
        if (data['success'] == true) {
          _titleCtrl.clear(); _contentCtrl.clear(); setState(() => _selectedCategory = 'general');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(lang.isEnglish ? '✅ Announcement published!' : '✅ 消息已發布！'), backgroundColor: Colors.green));
          _loadAnnouncements();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(data['message'] ?? (lang.isEnglish ? 'Publish failed' : '發布失敗')), backgroundColor: Colors.red));
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.t('network_err')), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isPosting = false);
  }

  Future<void> _deleteAnnouncement(String annId, String title) async {
    final lang    = widget.lang;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(lang.t('confirm_delete_title')),
      content: Text('${lang.isEnglish ? 'Delete' : '確定要刪除'} 「$title」${lang.isEnglish ? '?' : '嗎？'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.t('cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(lang.t('delete'))),
      ],
    ));
    if (confirm != true) return;
    try {
      final resp = await http.post(Uri.parse(_deleteUrl), body: {'annId': annId});
      final data = jsonDecode(resp.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['success'] == true ? (lang.isEnglish ? '✅ Deleted' : '✅ 已刪除') : (lang.isEnglish ? 'Delete failed' : '刪除失敗')),
          backgroundColor: data['success'] == true ? Colors.green : Colors.red));
        if (data['success'] == true) _loadAnnouncements();
      }
    } catch (_) {}
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Publish form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.add_circle, color: Colors.deepPurple, size: 20), const SizedBox(width: 8),
              Text(lang.t('publish_announcement'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
            ]),
            const SizedBox(height: 14),
            Text(lang.isEnglish ? 'Category' : '分類', style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: _categories.entries.map((e) {
              final isSelected = _selectedCategory == e.key;
              final color      = e.value['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: isSelected ? color : Colors.grey[100], borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? color : Colors.grey[300]!, width: 1.5)),
                  child: Text(e.value['label'] as String, style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            TextField(controller: _titleCtrl,
                decoration: InputDecoration(labelText: lang.isEnglish ? 'Title' : '標題',
                    hintText: lang.isEnglish ? 'e.g. System Maintenance Notice' : '例如：系統維護通知',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
            const SizedBox(height: 12),
            TextField(controller: _contentCtrl, maxLines: 4,
                decoration: InputDecoration(labelText: lang.isEnglish ? 'Content' : '內容',
                    hintText: lang.isEnglish ? 'Enter announcement content...' : '輸入公告內容...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _isPosting ? null : _postAnnouncement,
              icon: _isPosting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              label: Text(_isPosting ? lang.t('posting') : lang.t('publish')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
          ]),
        ),
        const SizedBox(height: 20),

        // Published list
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${lang.t('published_announcements')} (${_announcements.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.deepPurple), onPressed: _loadAnnouncements),
        ]),
        const SizedBox(height: 8),

        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_announcements.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Icon(Icons.campaign_outlined, color: Colors.grey[300], size: 48), const SizedBox(height: 8),
            Text(lang.t('no_announcements_yet'), style: TextStyle(color: Colors.grey[400])),
          ])))
        else
          ...(_announcements.map((ann) {
            final category = ann['category'] ?? 'general';
            final catStyle = _categories[category] ?? _categories['general']!;
            final color    = catStyle['color'] as Color;
            return Card(
              elevation: 1, margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3), width: 1)),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(catStyle['label'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
                  const Spacer(),
                  Text(_formatDate(ann['createdAt']), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  const SizedBox(width: 6),
                  GestureDetector(
                      onTap: () => _deleteAnnouncement(ann['annId'], ann['title'] ?? ''),
                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
                ]),
                const SizedBox(height: 8),
                Text(ann['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(ann['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
              ])),
            );
          }).toList()),
      ]),
    );
  }
}
