// 路徑: lib/pages/teacher/teacher_home.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/database.dart';
import '../../providers/language_provider.dart';
import '../../models/member_model.dart';
import '../../services/local_storage.dart';
import '../../services/channel_service.dart';
import '../../services/upload_service.dart';

import '../common/profile_page.dart';
import '../common/feed_page.dart';
import 'create_course_page.dart';
import 'course_management.dart';
import 'teacher_income_page.dart';
import 'create_post_page.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});
  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _currentIndex = 0;
  TeacherProfile? _profile;

  TeacherChannel? _channel;
  bool _isLoadingChannel = true;
  bool _isCreatingChannel = false;
  bool _isVerifying = false;
  String? _channelError;

  List _announcements = [];
  bool _isLoadingNews = true;
  static const String _annUrl = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_announcements.php';
 // ✅ 改成這個
  static const String _mediaPipeBaseUrl = 'https://d2kry3pmi7k9be.cloudfront.net/MediaPipe.html';

  final List<Widget> _pages = [const SizedBox(), const CourseManagementPage(), const FeedPage(isTeacher: true)];

  @override
  void initState() { super.initState(); _loadData(); _loadAnnouncements(); }

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

  void _loadData() async {
    final info = await LocalStorage.getUserInfo();
    if (mounted) {
      setState(() {
        _profile = TeacherProfile(mId: info['mId'] ?? '', fName: info['fName'] ?? 'Teacher',
            nName: info['nName'] ?? '', email: info['email'] ?? '', mType: 'TEACHER',
            address: info['address'] ?? 'N/A', tel: int.tryParse(info['tel']?.toString() ?? '0') ?? 0);
      });
      _loadChannelFromFirestore(info['mId'] ?? '');
    }
  }

  Future<void> _loadChannelFromFirestore(String mId) async {
    if (mId.isEmpty) { setState(() { _isLoadingChannel = false; _channelError = 'Missing teacher ID'; }); return; }
    setState(() { _isLoadingChannel = true; _channelError = null; });
    try {
      final channel = await ChannelService.getTeacherChannel(mId);
      if (mounted) setState(() { _channel = channel; _isLoadingChannel = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingChannel = false; _channelError = e.toString(); });
    }
  }

  Future<TeacherChannel?> _verifyAndGetChannel() async {
    if (_profile == null) return null;
    setState(() { _isVerifying = true; _channelError = null; });
    try {
      final channel = await ChannelService.getVerifiedChannel(_profile!.mId, _profile!.fName);
      if (mounted) setState(() { _channel = channel; _isVerifying = false; });
      return channel;
    } catch (e) {
      if (mounted) setState(() { _isVerifying = false; _channelError = e.toString(); });
      return null;
    }
  }

  Future<void> _createOrGetChannel() async {
    if (_profile == null) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() { _isCreatingChannel = true; _channelError = null; });
    try {
      final channel = await ChannelService.getOrCreateChannel(_profile!.mId, _profile!.fName);
      if (mounted) {
        setState(() { _channel = channel; _isCreatingChannel = false; });
        if (channel != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(lang.t('channel_ready'), style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF4CAF50)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isCreatingChannel = false; _channelError = e.toString(); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _launchLive() async {
    if (_profile == null) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() => _isVerifying = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        const SizedBox(width: 12),
        Text(lang.t('verifying_channel'), style: const TextStyle(color: Colors.white)),
      ]),
      backgroundColor: const Color(0xFF6366F1), duration: const Duration(seconds: 10),
    ));
    try {
      final channel = await _verifyAndGetChannel();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (channel == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${lang.isEnglish ? 'Cannot get channel' : '無法獲取頻道'}: ${_channelError ?? ''}',
                style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
        return;
      }
      final result = await _showBroadcastSetupDialog(lang);
      if (result == null) return;
      final String roomTitle  = result['title'] ?? '${_profile!.fName} ${lang.isEnglish ? "Live" : "的直播"}';
      final String? coverUrl  = result['coverUrl'];
      await ChannelService.updateBroadcastInfo(mId: _profile!.mId, roomTitle: roomTitle, thumbnailUrl: coverUrl);
      await ChannelService.updateLastLiveTime(_profile!.mId);
      final uri = Uri.parse(_mediaPipeBaseUrl).replace(queryParameters: {
        'channelId': _profile!.mId, 'ingestServer': channel.ingestServer,
        'streamKey': channel.streamKey, 'playbackUrl': channel.playbackUrl, 'teacherName': _profile!.fName,
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.isEnglish ? 'Unable to open live page' : '無法開啟直播頁面', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${lang.isEnglish ? 'Launch failed' : '啟動失敗'}: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red));
    }
  }

  Future<Map<String, String?>?> _showBroadcastSetupDialog(LanguageProvider lang) async {
    final titleController = TextEditingController(text: '${_profile?.fName ?? "Teacher"} ${lang.isEnglish ? "Live" : "的直播"}');
    File? selectedImage;
    String? uploadedUrl;
    bool isUploading = false;

    return await showDialog<Map<String, String?>?>(
      context: context, barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(children: [
            const Icon(Icons.live_tv, color: Color(0xFF6366F1)),
            const SizedBox(width: 10),
            Text(lang.t('live_settings'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lang.isEnglish ? 'Live Title' : '直播標題',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              TextField(
                controller: titleController, maxLength: 30,
                decoration: InputDecoration(
                  hintText: lang.t('live_title_hint'), filled: true, fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(lang.t('cover_image'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: isUploading ? null : () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 600, imageQuality: 80);
                  if (picked != null) {
                    setDialogState(() { selectedImage = File(picked.path); isUploading = true; });
                    final url = await UploadService.uploadCoverImage(File(picked.path), _profile!.mId);
                    setDialogState(() { uploadedUrl = url; isUploading = false; });
                    if (url == null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(lang.isEnglish ? 'Image upload failed' : '圖片上傳失敗，請重試'), backgroundColor: Colors.orange));
                  }
                },
                child: Container(
                  width: double.infinity, height: 140,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedImage != null ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0), width: 1.5)),
                  clipBehavior: Clip.antiAlias,
                  child: selectedImage != null
                      ? Stack(fit: StackFit.expand, children: [
                          Image.file(selectedImage!, fit: BoxFit.cover),
                          if (isUploading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                          if (!isUploading && uploadedUrl != null) Positioned(top: 8, right: 8,
                              child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16))),
                        ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text(lang.isEnglish ? 'Tap to select cover image' : '點擊選擇封面圖片',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          Text(lang.isEnglish ? 'Recommended 800x600' : '建議尺寸 800x600',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                        ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: isUploading ? null : () => Navigator.pop(dialogContext, null),
                child: Text(lang.t('cancel'), style: TextStyle(color: Colors.grey[600]))),
            ElevatedButton(
              onPressed: isUploading ? null : () => Navigator.pop(dialogContext, {
                'title': titleController.text.trim().isNotEmpty ? titleController.text.trim() : '${_profile?.fName ?? "Teacher"} ${lang.isEnglish ? "Live" : "的直播"}',
                'coverUrl': uploadedUrl,
              }),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: Text(lang.t('start_live'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forceRecreateChannel() async {
    if (_profile == null) return;
    final lang    = Provider.of<LanguageProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.t('recreate_channel')),
        content: Text(lang.t('recreate_channel_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(lang.t('recreate'))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _isCreatingChannel = true; _channelError = null; });
    try {
      final channel = await ChannelService.forceRecreateChannel(_profile!.mId, _profile!.fName);
      if (mounted) {
        setState(() { _channel = channel; _isCreatingChannel = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.t('new_channel_created'), style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF4CAF50)));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isCreatingChannel = false; _channelError = e.toString(); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${lang.isEnglish ? 'Creation failed' : '建立失敗'}: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      if (_profile != null) _loadChannelFromFirestore(_profile!.mId),
      _loadAnnouncements(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final lang    = Provider.of<LanguageProvider>(context);
    Widget content = _profile == null
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
        : (_currentIndex == 0 ? _buildDashboard(lang) : _pages[_currentIndex]);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white, elevation: 10,
        indicatorColor: const Color(0xFF6366F1).withOpacity(0.2),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard, color: Color(0xFF6366F1)),
              label: lang.t('nav_dashboard')),
          NavigationDestination(icon: const Icon(Icons.video_library_outlined),
              selectedIcon: const Icon(Icons.video_library, color: Color(0xFF6366F1)),
              label: lang.t('nav_courses')),
          NavigationDestination(icon: const Icon(Icons.dynamic_feed_outlined),
              selectedIcon: const Icon(Icons.dynamic_feed, color: Color(0xFF6366F1)),
              label: lang.isEnglish ? 'Feed' : '社群'),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCoursePage())),
              icon: const Icon(Icons.add),
              label: Text(lang.t('create_course'), style: const TextStyle(fontWeight: FontWeight.bold)))
          : _currentIndex == 2
              ? FloatingActionButton.extended(
                  backgroundColor: Colors.orange, foregroundColor: Colors.white,
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage()));
                    setState(() {});
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(lang.t('new_post'), style: const TextStyle(fontWeight: FontWeight.bold)))
              : null,
    );
  }

  Widget _buildDashboard(LanguageProvider lang) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshAll, color: const Color(0xFF6366F1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.t('welcome'), style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 4),
                Text(_profile?.fName ?? 'Teacher', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Text('ID: ${_profile?.mId ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6366F1), width: 2)),
                  child: CircleAvatar(radius: 26, backgroundColor: Colors.white,
                      child: Text(_profile?.fName[0] ?? 'T',
                          style: const TextStyle(color: Color(0xFF6366F1), fontSize: 22, fontWeight: FontWeight.bold))),
                ),
              ),
            ]),
            const SizedBox(height: 40),
            _buildLiveCard(lang),
            const SizedBox(height: 40),
            _buildIncomeCard(lang),
            const SizedBox(height: 30),
            Text(lang.t('workspace'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            Row(children: [
              _buildMenuCard(icon: Icons.book,   title: lang.isEnglish ? 'My Courses' : '我的課程', description: lang.t('nav_courses'), onTap: () => setState(() => _currentIndex = 1)),
              const SizedBox(width: 16),
              _buildMenuCard(icon: Icons.person, title: lang.t('profile'), description: lang.isEnglish ? 'View profile' : '查看個人資料',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _buildMenuCard(icon: Icons.forum, title: lang.isEnglish ? 'Community' : '社群管理', description: lang.isEnglish ? 'Community' : '社群',
                  onTap: () => setState(() => _currentIndex = 2)),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ]),
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
            const SizedBox(height: 20),
          ]),
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
          Text(lang.t('no_announcements'), style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ]),
      );
    }
    return Column(children: _announcements.take(5).map((ann) =>
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _AnnouncementCard(announcement: ann))).toList());
  }

  Widget _buildIncomeCard(LanguageProvider lang) {
    return GestureDetector(
      onTap: () {
        if (_profile == null) return;
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => TeacherIncomePage(mId: _profile!.mId, teacherName: _profile!.fName)));
      },
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFF59E0B), size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lang.t('income_report'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(lang.t('view_earnings'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
        ]),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String title, required String description, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 28)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _buildLiveCard(LanguageProvider lang) {
    final bool isLoading = _isLoadingChannel || _isCreatingChannel || _isVerifying;
    return GestureDetector(
      onTap: isLoading ? null : _launchLive,
      onLongPress: _channel != null ? _forceRecreateChannel : null,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _channel != null ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)] : [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: (_channel != null ? const Color(0xFF4CAF50) : const Color(0xFFFF416C)).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: isLoading
                  ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Icon(Icons.podcasts, color: Colors.white, size: 36),
            ),
            _buildStatusBadge(lang),
          ]),
          const SizedBox(height: 24),
          Text(_getCardTitle(lang), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_getCardSubtitle(lang), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, height: 1.4)),
          if (_channelError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16), const SizedBox(width: 8),
                Expanded(child: Text(_channelError!, style: const TextStyle(color: Colors.white, fontSize: 12))),
                TextButton(
                  onPressed: _createOrGetChannel,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(lang.t('retry'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildStatusBadge(LanguageProvider lang) {
    Widget badge(Widget child, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: child);

    if (_isLoadingChannel)  return badge(Row(children: [const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), const SizedBox(width: 6), Text(lang.t('loading'),   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), Colors.white.withOpacity(0.3));
    if (_isCreatingChannel) return badge(Row(children: [const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), const SizedBox(width: 6), Text(lang.t('creating'),  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), Colors.orange);
    if (_isVerifying)       return badge(Row(children: [const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), const SizedBox(width: 6), Text(lang.t('verifying'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), Colors.blue);
    if (_channel != null)   return badge(Row(children: [const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16), const SizedBox(width: 6), Text(lang.t('ready'),    style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold))]), Colors.white);
    return badge(Row(children: [const Icon(Icons.add_circle_outline, color: Color(0xFFFF416C), size: 16), const SizedBox(width: 6), Text(lang.t('new_badge'), style: const TextStyle(color: Color(0xFFFF416C), fontWeight: FontWeight.bold))]), Colors.white);
  }

  String _getCardTitle(LanguageProvider lang) {
    if (_isLoadingChannel)  return lang.isEnglish ? 'Loading...'           : '載入中...';
    if (_isCreatingChannel) return lang.isEnglish ? 'Creating Channel...'  : '建立頻道中...';
    if (_isVerifying)       return lang.isEnglish ? 'Verifying Channel...' : '驗證頻道中...';
    if (_channel != null)   return lang.isEnglish ? 'Start Broadcasting'   : '開始直播';
    return lang.isEnglish ? 'Create Live Channel' : '建立直播頻道';
  }

  String _getCardSubtitle(LanguageProvider lang) {
    if (_isLoadingChannel)  return lang.isEnglish ? 'Checking your channel status...' : '正在檢查頻道狀態...';
    if (_isCreatingChannel) return lang.isEnglish ? 'Setting up your live channel...' : '正在設定你的直播頻道...';
    if (_isVerifying)       return lang.isEnglish ? 'Verifying channel with AWS...'   : '正在驗證 AWS 頻道...';
    if (_channel != null)   return lang.isEnglish ? 'Your channel is ready! Tap to start streaming.' : '頻道已就緒！點擊開始直播。';
    return lang.isEnglish ? 'First time? Tap to create your personal live channel.' : '首次使用？點擊建立你的個人直播頻道。';
  }
}

// ── Announcement Card ──────────────────────────────────────────
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