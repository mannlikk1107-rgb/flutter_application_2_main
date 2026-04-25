// 路徑: lib/pages/student/student_home.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/database.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../common/profile_page.dart';
import '../common/feed_page.dart';
import 'course_browser.dart';
import 'my_courses.dart';
import 'top_up_page.dart';
import 'channel_list_page.dart';
import 'tasks_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});
  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const StudentDashboard(),
    const CourseBrowserPage(),
    const MyCoursesPage(),
    const FeedPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home),        label: lang.t('nav_home')),
          BottomNavigationBarItem(icon: const Icon(Icons.explore),     label: lang.t('nav_explore')),
          BottomNavigationBarItem(icon: const Icon(Icons.play_lesson), label: lang.t('nav_my_courses')),
          BottomNavigationBarItem(icon: const Icon(Icons.group),       label: lang.t('nav_community')),
          BottomNavigationBarItem(icon: const Icon(Icons.person),      label: lang.t('nav_profile')),
        ],
      ),
    );
  }
}

// ── Student Dashboard ────────────────────────────────────────
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List _announcements = [];
  bool _isLoadingNews = true;

  static const String _annUrl = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_announcements.php';

  @override
  void initState() { super.initState(); _loadAnnouncements(); }

  Future<void> _loadAnnouncements() async {
    try {
      final resp = await http.get(Uri.parse(_annUrl));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted && data['success'] == true) {
          setState(() { _announcements = data['announcements'] ?? []; _isLoadingNews = false; }); return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingNews = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang         = Provider.of<LanguageProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAnnouncements,
          color: const Color(0xFF6366F1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lang.t('welcome'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(userProvider.fName.isNotEmpty ? userProvider.fName : 'Student',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 28),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(lang.isEnglish ? 'ACoins Balance' : 'ACoin 餘額',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('${userProvider.balance} ACoin',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lang.isEnglish ? 'Quick Actions' : '快捷功能',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 16),
                    Row(children: [
                      _buildQuickAction(Icons.add_card,      lang.isEnglish ? 'A Coin' : '積分', const Color(0xFF6366F1),
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpPage()))),
                      const SizedBox(width: 12),
                      _buildQuickAction(Icons.live_tv,       lang.isEnglish ? 'Live'   : '直播', const Color(0xFF7C3AED),
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChannelListPage()))),
                      const SizedBox(width: 12),
                      _buildQuickAction(Icons.casino_rounded, lang.isEnglish ? 'Tasks'  : '任務', const Color(0xFFFF6B6B),
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()))),
                    ]),
                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChannelListPage())),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))]),
                        child: Row(children: [
                          Container(width: 50, height: 50,
                              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.live_tv_rounded, color: Color(0xFF7C3AED), size: 28)),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lang.isEnglish ? 'Watch Live' : '觀看直播',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            Text(lang.isEnglish ? 'Join live classes' : '加入即時課堂',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ])),
                          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 28),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(lang.t('latest_announcements'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      if (!_isLoadingNews)
                        GestureDetector(
                          onTap: _loadAnnouncements,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
                            child: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1), size: 20),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    _buildAnnouncementSection(lang),
                    const SizedBox(height: 16),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementSection(LanguageProvider lang) {
    if (_isLoadingNews) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF6366F1))));
    if (_announcements.isEmpty) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(children: [
          Icon(Icons.inbox_outlined, color: Colors.grey[300], size: 36), const SizedBox(height: 8),
          Text(lang.t('no_announcements_yet'), style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ]),
      );
    }
    return Column(children: _announcements.take(5).map((ann) =>
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _AnnouncementCard(announcement: ann))).toList());
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))]),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ── Announcement Card ────────────────────────────────────────
class _AnnouncementCard extends StatefulWidget {
  final Map announcement;
  const _AnnouncementCard({required this.announcement});
  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _expanded = false;

  static const Map<String, Map<String, dynamic>> _categoryStyle = {
    'general':     {'label_en': 'General',     'label_zh': '一般',   'icon': Icons.campaign_outlined,     'color': Color(0xFF6366F1)},
    'update':      {'label_en': 'Update',      'label_zh': '更新',   'icon': Icons.system_update_rounded, 'color': Color(0xFF22C55E)},
    'maintenance': {'label_en': 'Maintenance', 'label_zh': '維護',   'icon': Icons.build_outlined,        'color': Color(0xFFF59E0B)},
    'feature':     {'label_en': 'New Feature', 'label_zh': '新功能', 'icon': Icons.auto_awesome_outlined, 'color': Color(0xFF8B5CF6)},
    'live':        {'label_en': 'Live',        'label_zh': '直播',   'icon': Icons.podcasts_rounded,      'color': Color(0xFFEF4444)},
    'roadmap':     {'label_en': 'Roadmap',     'label_zh': '路線圖', 'icon': Icons.map_outlined,          'color': Color(0xFF0EA5E9)},
  };

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final lang     = Provider.of<LanguageProvider>(context);
    final ann      = widget.announcement;
    final category = ann['category'] ?? 'general';
    final style    = _categoryStyle[category] ?? _categoryStyle['general']!;
    final color    = style['color'] as Color;
    final icon     = style['icon'] as IconData;
    final label    = lang.isEnglish ? style['label_en'] as String : style['label_zh'] as String;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_formatDate(ann['createdAt']), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            const SizedBox(width: 6),
            AnimatedRotation(turns: _expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 18)),
          ]),
          const SizedBox(height: 12),
          Text(ann['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          AnimatedCrossFade(
            firstChild:  Padding(padding: const EdgeInsets.only(top: 6), child: Text(ann['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4))),
            secondChild: Padding(padding: const EdgeInsets.only(top: 6), child: Text(ann['content'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5))),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ]),
      ),
    );
  }
}