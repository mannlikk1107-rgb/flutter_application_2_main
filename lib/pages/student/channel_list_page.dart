// Path: lib/pages/student/channel_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/language_provider.dart';
import '../../services/ivs_service.dart';
import '../../services/channel_service.dart';
import '../../services/local_storage.dart';
import 'viewer_page.dart';

class ChannelListPage extends StatefulWidget {
  const ChannelListPage({super.key});

  @override
  State<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends State<ChannelListPage> {
  List<Channel> _channels = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _currentUserId = '';
  String _currentDisplayName = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadChannels();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await LocalStorage.getUserInfo();
    final userId = userInfo['mId'] ?? '';
    final displayName = (userInfo['nName']?.isNotEmpty == true)
        ? userInfo['nName']!
        : (userInfo['fName']?.isNotEmpty == true)
            ? userInfo['fName']!
            : 'User_$userId';
    if (mounted) {
      setState(() {
        _currentUserId = userId;
        _currentDisplayName = displayName;
      });
    }
  }

  Future<void> _loadChannels() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final liveChannels = await IVSApiService.fetchLiveChannels();
      final broadcastInfo = await ChannelService.getAllBroadcastInfo();
      final enrichedChannels = liveChannels.map((channel) {
        final teacherId = channel.teacherId ?? channel.id;
        final info = broadcastInfo[teacherId];
        if (info != null) {
          return channel.copyWithFirestoreData(
            roomTitle: (info['roomTitle'] as String?)?.isNotEmpty == true ? info['roomTitle'] as String : null,
            thumbnailUrl: (info['thumbnailUrl'] as String?)?.isNotEmpty == true ? info['thumbnailUrl'] as String : null,
          );
        }
        return channel;
      }).toList();
      if (mounted) setState(() { _channels = enrichedChannels; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Failed to load: $e'; _isLoading = false; });
    }
  }

  void _openChannel(Channel channel) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (channel.playbackUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang.t('no_playback_url')),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ViewerPage(
        channel: channel,
        userId: _currentUserId,
        displayName: _currentDisplayName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('live_channels'),
          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
            onPressed: _loadChannels,
          ),
        ],
      ),
      body: _buildBody(lang),
    );
  }

  Widget _buildBody(LanguageProvider lang) {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: Color(0xFF6366F1)),
          const SizedBox(height: 16),
          Text(lang.t('loading_channels'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        ]),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            Text(lang.t('connection_error'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadChannels,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(lang.t('try_again')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ]),
        ),
      );
    }

    if (_channels.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.live_tv_rounded, size: 48, color: Color(0xFF6366F1)),
          ),
          const SizedBox(height: 20),
          Text(lang.t('no_live_channels'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(lang.t('wait_teacher'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadChannels,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(lang.t('refresh')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChannels,
      color: const Color(0xFF6366F1),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.podcasts_rounded, color: Color(0xFFEF4444), size: 18),
                ),
                const SizedBox(width: 10),
                Text(lang.t('recommended'),
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ChannelCard(
                  channel: _channels[index],
                  onTap: () => _openChannel(_channels[index]),
                ),
                childCount: _channels.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Channel Card ──
class _ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  const _ChannelCard({required this.channel, required this.onTap});

  // 根据 chatCollectionName 推导出 viewers 集合名
  String get _presenceCollection =>
      'viewers_${channel.chatCollectionName.replaceFirst("messages_", "")}';

  @override
  Widget build(BuildContext context) {
    final teacher = channel.teacherName ?? 'Teacher';
    final title = (channel.roomTitle?.isNotEmpty == true) ? channel.roomTitle! : channel.name;
    final hasImage = channel.thumbnailUrl != null && channel.thumbnailUrl!.isNotEmpty;
    final initial = teacher.isNotEmpty ? teacher[0].toUpperCase() : '?';
    final color = _avatarColor(teacher);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              hasImage
                  ? Image.network(channel.thumbnailUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(initial, color),
                      loadingBuilder: (_, child, progress) => progress == null ? child : _buildPlaceholder(initial, color))
                  : _buildPlaceholder(initial, color),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(height: 30, decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.5), Colors.transparent]))),
              ),
              // 实时观众数
              Positioned(
                bottom: 5, left: 6,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(_presenceCollection)
                      .where('active', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = _countActiveViewers(snapshot.data);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.visibility_rounded, size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text(_formatViewerCount(count),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                    ]);
                  },
                ),
              ),
              Positioned(top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(6)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 5, color: Colors.white),
                    SizedBox(width: 3),
                    Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(child: Text(initial, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(title,
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600, height: 1.1),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(teacher, style: const TextStyle(color: Color(0xFFB0B8C9), fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // 只统计心跳在 90 秒内的观众（ViewerPage 每 30 秒心跳一次,给 3 倍容错）
  int _countActiveViewers(QuerySnapshot? snap) {
    if (snap == null) return 0;
    final cutoff = DateTime.now().subtract(const Duration(seconds: 90));
    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
      if (lastSeen == null || lastSeen.isAfter(cutoff)) count++;
    }
    return count;
  }

  String _formatViewerCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    return '$count';
  }

  Color _avatarColor(String name) {
    const colors = [Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFF59E0B),
                    Color(0xFF8B5CF6), Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFF10B981)];
    int hash = 0;
    for (int i = 0; i < name.length; i++) { hash = name.codeUnitAt(i) + ((hash << 5) - hash); }
    return colors[hash.abs() % colors.length];
  }

  Widget _buildPlaceholder(String initial, Color color) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.06)])),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.live_tv_rounded, color: color.withOpacity(0.2), size: 28),
        const SizedBox(height: 4),
        Text(initial, style: TextStyle(color: color.withOpacity(0.25), fontSize: 22, fontWeight: FontWeight.bold)),
      ])),
    );
  }
}