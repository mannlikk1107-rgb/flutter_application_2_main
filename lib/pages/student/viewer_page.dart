// Path: lib/pages/student/viewer_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/ivs_service.dart';

class _Gift {
  final String actTypeId;
  final String emoji;
  final String name;
  final int cost;
  final Color color;
  const _Gift({required this.actTypeId, required this.emoji, required this.name, required this.cost, required this.color});
}

const List<_Gift> _gifts = [
  _Gift(actTypeId: 'attG01', emoji: '⭐', name: 'Star',    cost: 10,  color: Color(0xFFFFC107)),
  _Gift(actTypeId: 'attG02', emoji: '❤️', name: 'Heart',   cost: 30,  color: Color(0xFFE91E63)),
  _Gift(actTypeId: 'attG03', emoji: '👑', name: 'Crown',   cost: 60,  color: Color(0xFF9C27B0)),
  _Gift(actTypeId: 'attG04', emoji: '💎', name: 'Diamond', cost: 100, color: Color(0xFF2196F3)),
];

const String _giftApiUrl = 'http://3.25.85.107/Research/Web/TestFYP/api/gift.php';

// ── 弹幕数据模型 ──
class _DanmakuItem {
  final String id;
  final String text;
  final bool isGift;
  final Color accentColor;
  const _DanmakuItem({
    required this.id,
    required this.text,
    required this.isGift,
    required this.accentColor,
  });
}

class ViewerPage extends StatefulWidget {
  final Channel channel;
  final String? userId;
  final String? displayName;
  const ViewerPage({super.key, required this.channel, this.userId, this.displayName});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _isLive = false;
  String? _errorMessage;
  bool _isMuted = false;
  bool _isInFullScreen = false;

  final TextEditingController _messageController = TextEditingController();
  bool _showChat = true;
  late final String _chatCollectionName;

  final Set<String> _localBannedUserIds = {};
  Timer? _heartbeatTimer;
  String? _presenceDocId;
  Timer? _chatRefreshTimer;

  bool _isSendingGift = false;
  OverlayEntry? _giftOverlayEntry;

  // ── 弹幕相关 ──
  final StreamController<_DanmakuItem> _danmakuStreamCtrl = StreamController<_DanmakuItem>.broadcast();
  StreamSubscription<QuerySnapshot>? _danmakuSub;
  final Set<String> _seenDanmakuIds = {};
  bool _danmakuFirstLoad = true;
  bool _danmakuEnabled = true;
  double _danmakuFontSize = 18;
  double _danmakuOpacity = 0.85;

  String get _userId => widget.userId ?? 'guest_${DateTime.now().millisecondsSinceEpoch % 10000}';
  String get _displayName => widget.displayName ?? 'Guest';
  String get _presenceCollection => 'viewers_${widget.channel.chatCollectionName.replaceFirst("messages_", "")}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatCollectionName = widget.channel.chatCollectionName;
    _initPlayer();
    _listenToBans();
    _startPresence();
    _initDanmakuStream();
    _chatRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }

  void _initDanmakuStream() {
    _danmakuSub = FirebaseFirestore.instance
        .collection(_chatCollectionName)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) {
      if (_danmakuFirstLoad) {
        for (final doc in snap.docs) _seenDanmakuIds.add(doc.id);
        _danmakuFirstLoad = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final doc = change.doc;
        if (_seenDanmakuIds.contains(doc.id)) continue;
        _seenDanmakuIds.add(doc.id);

        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final userId = data['userId'] as String? ?? '';
        if (_localBannedUserIds.contains(userId)) continue;
        final text = data['text'] as String? ?? '';
        final displayName = data['displayName'] as String? ?? '';
        if (text.isEmpty) continue;
        final isGift = data['isGift'] == true;

        _danmakuStreamCtrl.add(_DanmakuItem(
          id: doc.id,
          text: isGift ? text : '$displayName: $text',
          isGift: isGift,
          accentColor: isGift
              ? Colors.amber
              : (userId == _userId ? Colors.amberAccent : Colors.white),
        ));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _removePresence();
    } else if (state == AppLifecycleState.resumed) {
      _startPresence();
    }
  }

  Future<void> _startPresence() async {
    try {
      _presenceDocId = _userId;
      await FirebaseFirestore.instance.collection(_presenceCollection).doc(_presenceDocId).set({
        'userId': _userId, 'displayName': _displayName,
        'active': true, 'lastSeen': FieldValue.serverTimestamp(), 'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
    } catch (e) { debugPrint('❌ Presence start error: $e'); }
  }

  Future<void> _sendHeartbeat() async {
    if (_presenceDocId == null) return;
    try {
      await FirebaseFirestore.instance.collection(_presenceCollection).doc(_presenceDocId)
          .update({'lastSeen': FieldValue.serverTimestamp(), 'active': true});
    } catch (e) { debugPrint('⚠️ Heartbeat error: $e'); }
  }

  Future<void> _removePresence() async {
    _heartbeatTimer?.cancel(); _heartbeatTimer = null;
    if (_presenceDocId == null) return;
    try {
      await FirebaseFirestore.instance.collection(_presenceCollection).doc(_presenceDocId)
          .update({'active': false, 'lastSeen': FieldValue.serverTimestamp()});
    } catch (e) { debugPrint('⚠️ Remove presence error: $e'); }
  }

  void _showGiftPanel() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final teacherId = widget.channel.teacherId ?? '';
    if (teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang.t('gift_no_teacher')), backgroundColor: Colors.orange,
      ));
      return;
    }
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => _GiftPanel(
        gifts: _gifts,
        onGiftSelected: (gift) { Navigator.pop(ctx); _confirmAndSendGift(gift); },
      ),
    );
  }

  void _confirmAndSendGift(_Gift gift) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.t('send_gift_dialog_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(gift.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(gift.name, style: TextStyle(color: gift.color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text('${gift.cost} ACoin', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('${lang.t('send_to')} ${widget.channel.teacherName ?? widget.channel.name}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(lang.t('cancel'), style: const TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            icon: Text(gift.emoji),
            label: Text(lang.t('confirm_send')),
            style: ElevatedButton.styleFrom(backgroundColor: gift.color, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(ctx); _sendGift(gift); },
          ),
        ],
      ),
    );
  }

  Future<void> _sendGift(_Gift gift) async {
    if (_isSendingGift) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() => _isSendingGift = true);
    final teacherId = widget.channel.teacherId ?? '';

    try {
      final response = await http.post(
        Uri.parse(_giftApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'studentId': _userId, 'teacherId': teacherId, 'actTypeId': gift.actTypeId, 'channelName': widget.channel.name}),
      );
      final result = jsonDecode(response.body);
      if (!mounted) return;

      if (result['status'] == 'success') {
        final newTotal = double.tryParse(result['studentNewTotal'].toString()) ?? 0.0;
        Provider.of<UserProvider>(context, listen: false).updateBalance(newTotal);
        FirebaseFirestore.instance.collection(_chatCollectionName).add({
          'userId': _userId, 'displayName': _displayName,
          'text': '${gift.emoji} $_displayName sent ${gift.name}!',
          'timestamp': FieldValue.serverTimestamp(), 'isGift': true,
        });
        _showGiftAnimation(gift);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Text(gift.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('${gift.name} sent! -${gift.cost} ACoin'),
          ]),
          backgroundColor: gift.color, duration: const Duration(seconds: 3),
        ));
      } else if (result['status'] == 'insufficient') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('💰 ${result['message']}'), backgroundColor: Colors.orange, duration: const Duration(seconds: 3),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ ${result['message'] ?? lang.t('gift_failed')}'),
          backgroundColor: Colors.red, duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${lang.t('network_error')}: $e'), backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSendingGift = false);
    }
  }

  void _showGiftAnimation(_Gift gift) {
    _giftOverlayEntry?.remove();
    _giftOverlayEntry = OverlayEntry(
      builder: (ctx) => _GiftAnimationOverlay(
        gift: gift,
        teacherName: widget.channel.teacherName ?? widget.channel.name,
        onDone: () { _giftOverlayEntry?.remove(); _giftOverlayEntry = null; },
      ),
    );
    Overlay.of(context).insert(_giftOverlayEntry!);
  }

  void _listenToBans() {
    FirebaseFirestore.instance.collection('chat_bans').snapshots().listen((snapshot) {
      if (!mounted) return;
      final now = DateTime.now();
      final bannedIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['chatCollection'] != _chatCollectionName) continue;
        final bannedUntil = (data['bannedUntil'] as Timestamp?)?.toDate();
        final userId = data['userId'] ?? '';
        if (bannedUntil != null && now.isBefore(bannedUntil) && userId.isNotEmpty) bannedIds.add(userId);
      }
      setState(() { _localBannedUserIds.clear(); _localBannedUserIds.addAll(bannedIds); });
    });
  }

  Future<void> _initPlayer() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      _videoController?.dispose(); _videoController = null;
      if (widget.channel.playbackUrl.isEmpty) throw Exception('No playback URL');
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.channel.playbackUrl));
      await controller.initialize();
      controller.play();
      controller.setVolume(_isMuted ? 0 : 1);
      _videoController = controller;
      if (mounted) setState(() { _isLoading = false; _isLive = true; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isLive = false; _errorMessage = null; });
    }
  }

  Future<void> _safeRefresh() async {
    if (_isInFullScreen) {
      _isInFullScreen = false;
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await _initPlayer();
  }

  void _toggleMute() {
    setState(() { _isMuted = !_isMuted; _videoController?.setVolume(_isMuted ? 0 : 1); });
  }

  // ── 改为竖屏全屏 ──
  void _enterFullScreen() {
    if (_videoController == null || !_isLive) return;
    _isInFullScreen = true;
    // 保持竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenPlayer(
        videoController: _videoController!,
        isMuted: _isMuted,
        onToggleMute: _toggleMute,
        onRefresh: _safeRefresh,
        channelName: widget.channel.teacherName ?? widget.channel.name,
        danmakuStream: _danmakuStreamCtrl.stream,
        initialDanmakuEnabled: _danmakuEnabled,
        initialDanmakuFontSize: _danmakuFontSize,
        initialDanmakuOpacity: _danmakuOpacity,
        onDanmakuChanged: (e, s, o) {
          _danmakuEnabled = e;
          _danmakuFontSize = s;
          _danmakuOpacity = o;
        },
      ),
    )).then((_) {
      _isInFullScreen = false;
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (mounted) setState(() {});
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final now = DateTime.now();
    final myId = _userId;

    try {
      final chatBanDoc = await FirebaseFirestore.instance.collection('chat_bans').doc('${_chatCollectionName}_$myId').get();
      if (chatBanDoc.exists) {
        final bannedUntil = (chatBanDoc['bannedUntil'] as Timestamp).toDate();
        if (now.isBefore(bannedUntil)) {
          final remaining = bannedUntil.difference(now);
          final timeStr = '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.t('muted_chat_temp').replaceAll('{time}', timeStr)),
            backgroundColor: Colors.orange,
          ));
          return;
        }
      }
    } catch (_) {}

    try {
      final banDoc = await FirebaseFirestore.instance.collection('banned_users').doc(myId).get();
      if (banDoc.exists) {
        final data = banDoc.data() as Map<String, dynamic>;
        final bannedUntilRaw = data['bannedUntil'];
        if (bannedUntilRaw == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.t('muted_perm')), backgroundColor: Colors.red,
          ));
          return;
        }
        final bannedUntil = (bannedUntilRaw as Timestamp).toDate();
        if (now.isBefore(bannedUntil)) {
          final remaining = bannedUntil.difference(now);
          final timeStr = '${remaining.inDays}d ${remaining.inHours % 24}h';
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.t('muted_temp_admin').replaceAll('{time}', timeStr)),
            backgroundColor: Colors.red,
          ));
          return;
        }
      }
    } catch (_) {}

    FirebaseFirestore.instance.collection(_chatCollectionName).add({
      'userId': _userId, 'displayName': _displayName,
      'text': _messageController.text.trim(), 'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
  }

  void _reportMessage(Map<String, dynamic> messageData, String messageDocId) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final reportedUserId      = messageData['userId'] ?? '';
    final reportedDisplayName = messageData['displayName'] ?? 'Unknown';
    final reportedText        = messageData['text'] ?? '';
    if (reportedUserId.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Row(children: [
          const Icon(Icons.flag, color: Colors.orange),
          const SizedBox(width: 8),
          Text(lang.t('report_message'), style: const TextStyle(color: Colors.white)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${lang.t('reported_user')} $reportedDisplayName',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          Text('${lang.t('account_id')} $reportedUserId',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
            child: Text('"$reportedText"', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(lang.t('cancel'), style: const TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.flag, size: 16),
            label: Text(lang.t('confirm_report')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final bannedUntil = DateTime.now().add(const Duration(minutes: 30));
              await FirebaseFirestore.instance.collection('chat_bans')
                  .doc('${_chatCollectionName}_$reportedUserId').set({
                'userId': reportedUserId, 'displayName': reportedDisplayName,
                'chatCollection': _chatCollectionName, 'channelName': widget.channel.name,
                'bannedUntil': Timestamp.fromDate(bannedUntil),
                'bannedAt': FieldValue.serverTimestamp(),
                'bannedByUserId': _userId, 'bannedByDisplayName': _displayName, 'type': 'user_report',
              });
              setState(() => _localBannedUserIds.add(reportedUserId));
              await FirebaseFirestore.instance.collection('reports').add({
                'reportedUserId': reportedUserId, 'reportedDisplayName': reportedDisplayName,
                'reportedText': reportedText, 'reportedByUserId': _userId,
                'reportedByDisplayName': _displayName, 'chatCollection': _chatCollectionName,
                'channelName': widget.channel.name, 'messageId': messageDocId,
                'timestamp': FieldValue.serverTimestamp(), 'status': 'pending',
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(lang.t('reported_success').replaceAll('{name}', reportedDisplayName)),
                backgroundColor: Colors.orange,
              ));
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removePresence();
    _chatRefreshTimer?.cancel();
    _giftOverlayEntry?.remove();
    _videoController?.dispose();
    _messageController.dispose();
    _danmakuSub?.cancel();
    _danmakuStreamCtrl.close();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          if (_isLive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 8, color: Colors.white), SizedBox(width: 4),
                Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.channel.name, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (widget.channel.teacherName != null)
              Text(widget.channel.teacherName!, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ])),
        ]),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(_presenceCollection).where('active', isEqualTo: true).snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.visibility, size: 14, color: Colors.green[300]),
                  const SizedBox(width: 4),
                  Text('$count', style: TextStyle(color: Colors.green[300], fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              );
            },
          ),
          IconButton(
            icon: Icon(_showChat ? Icons.chat : Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
        ],
      ),
      body: Column(children: [
        AspectRatio(aspectRatio: 16 / 9, child: _buildPlayer()),
        Expanded(child: _showChat ? _buildChatRoom() : _buildStreamerInfo()),
      ]),
    );
  }

  Widget _buildPlayer() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (_isLoading) {
      return Container(color: Colors.black, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 12),
        Text(lang.t('player_loading'), style: const TextStyle(color: Colors.white70)),
      ])));
    }
    if (_errorMessage != null || !_isLive || _videoController == null) {
      return Container(color: Colors.black, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.tv_off, size: 48, color: Colors.grey[600]),
        const SizedBox(height: 12),
        Text(lang.t('not_streaming'), style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _initPlayer,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(lang.t('retry')),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
        ),
      ])));
    }
    return Stack(children: [
      Positioned.fill(child: VideoPlayer(_videoController!)),
      Positioned(left: 0, right: 0, bottom: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent])),
          child: Row(children: [
            _playerIconButton(Icons.refresh, _initPlayer),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)),
              child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const Spacer(),
            _playerIconButton(_isMuted ? Icons.volume_off : Icons.volume_up, _toggleMute),
            _playerIconButton(Icons.fullscreen, _enterFullScreen),
          ]),
        )),
    ]);
  }

  Widget _playerIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6), margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  bool _isTeacherMessage(String userId, String displayName) {
    if (widget.channel.teacherId != null && widget.channel.teacherId!.isNotEmpty && userId == widget.channel.teacherId) return true;
    if (userId.startsWith('TEACHER_') || displayName.startsWith('主播_') || displayName.startsWith('Streamer_')) return true;
    return false;
  }

  String _getChatDisplayName(String userId, String displayName) {
    if (_isTeacherMessage(userId, displayName)) {
      return widget.channel.teacherName?.isNotEmpty == true ? widget.channel.teacherName! : 'Live Streamer';
    }
    return displayName;
  }

  Widget _buildChatRoom() {
    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      color: const Color(0xFF1a1a2e),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: const Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.chat_bubble, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Text(lang.t('chat_room'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              child: Text('👤 $_displayName', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(_chatCollectionName)
                .orderBy('timestamp', descending: false).limitToLast(50).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text(
                lang.t('chat_failed'), style: TextStyle(color: Colors.grey[500])));
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator(color: Colors.white54));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.grey[700], size: 40),
                  const SizedBox(height: 12),
                  Text(lang.t('no_messages'), style: TextStyle(color: Colors.grey[500])),
                ]));
              }
              final thirtyMinsAgo = DateTime.now().subtract(const Duration(minutes: 30));
              final messages = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as Timestamp?;
                if (timestamp == null) return true;
                return timestamp.toDate().isAfter(thirtyMinsAgo);
              }).toList();
              if (messages.isEmpty) {
                return Center(child: Text(
                  lang.t('no_latest_msg'), style: TextStyle(color: Colors.grey[500])));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final doc  = messages[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final text   = data['text'] ?? '';
                  final userId = data['userId'] ?? '';
                  final rawDisplayName = data['displayName'] ?? userId;
                  final isMe       = userId == _userId;
                  final isStreamer  = _isTeacherMessage(userId, rawDisplayName);
                  final isGift     = data['isGift'] == true;

                  if (_localBannedUserIds.contains(userId)) return const SizedBox.shrink();
                  final chatName = _getChatDisplayName(userId, rawDisplayName);

                  if (isGift) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.1)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Text(text, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!isMe && !isStreamer)
                        GestureDetector(
                          onTap: () => _reportMessage(data, doc.id),
                          child: Padding(padding: const EdgeInsets.only(right: 6, top: 2),
                              child: Icon(Icons.flag, size: 14, color: Colors.orange[300])),
                        ),
                      if (isStreamer) _badge(lang.t('badge_streamer'), Colors.red)
                      else if (isMe) _badge(lang.t('badge_me'), Colors.amber),
                      Text('$chatName: ', style: TextStyle(
                        color: isStreamer ? Colors.red[300] : isMe ? Colors.amber : Colors.deepPurple[200],
                        fontWeight: FontWeight.bold, fontSize: 13,
                      )),
                      Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
                    ]),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5),
              border: const Border(top: BorderSide(color: Colors.white12, width: 0.5))),
          child: SafeArea(top: false, child: Row(children: [
            GestureDetector(
              onTap: _isSendingGift ? null : _showGiftPanel,
              child: Container(
                padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _isSendingGift ? Colors.grey[800] : Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle, border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: _isSendingGift
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
                    : const Text('🎁', style: TextStyle(fontSize: 20)),
              ),
            ),
            Expanded(
              child: Builder(builder: (ctx) {
                final lang = Provider.of<LanguageProvider>(ctx);
                return TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: lang.t('say_something'),
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true, fillColor: Colors.grey[900],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                );
              }),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ])),
        ),
      ]),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStreamerInfo() {
    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      color: const Color(0xFF1a1a2e),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24, backgroundColor: Colors.deepPurple,
            child: Text(
              (widget.channel.teacherName ?? widget.channel.name).isNotEmpty
                  ? (widget.channel.teacherName ?? widget.channel.name)[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.channel.teacherName ?? widget.channel.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_isLive ? lang.t('streaming_now') : lang.t('not_live'),
                style: TextStyle(color: _isLive ? Colors.green : Colors.grey[500], fontSize: 14)),
          ])),
        ]),
      ]),
    );
  }
}

// ── Gift Panel ──
class _GiftPanel extends StatelessWidget {
  final List<_Gift> gifts;
  final void Function(_Gift) onGiftSelected;
  const _GiftPanel({required this.gifts, required this.onGiftSelected});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a2e), borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text(lang.t('send_gift_title'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(lang.t('send_gift_sub'), style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: gifts.map((gift) => _GiftItem(gift: gift, onTap: () => onGiftSelected(gift))).toList(),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _GiftItem extends StatelessWidget {
  final _Gift gift;
  final VoidCallback onTap;
  const _GiftItem({required this.gift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: gift.color.withOpacity(0.15), shape: BoxShape.circle,
            border: Border.all(color: gift.color.withOpacity(0.5), width: 2),
          ),
          child: Center(child: Text(gift.emoji, style: const TextStyle(fontSize: 32))),
        ),
        const SizedBox(height: 8),
        Text(gift.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 12),
            const SizedBox(width: 3),
            Text('${gift.cost}', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }
}

// ── Gift Animation ──
class _GiftAnimationOverlay extends StatefulWidget {
  final _Gift gift;
  final String teacherName;
  final VoidCallback onDone;
  const _GiftAnimationOverlay({required this.gift, required this.teacherName, required this.onDone});

  @override
  State<_GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<_GiftAnimationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20),
    ]).animate(_ctrl);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_ctrl);
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Positioned(
      left: 0, right: 0, top: 100, bottom: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [widget.gift.color.withOpacity(0.85), widget.gift.color.withOpacity(0.6)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: widget.gift.color.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.gift.emoji, style: const TextStyle(fontSize: 60)),
                    const SizedBox(height: 8),
                    Text(widget.gift.name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${lang.t('send_to')} ${widget.teacherName}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${widget.gift.cost} ACoin',
                          style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Full Screen Player (竖屏,含弹幕) ──
class _FullScreenPlayer extends StatefulWidget {
  final VideoPlayerController videoController;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final Future<void> Function() onRefresh;
  final String channelName;
  final Stream<_DanmakuItem> danmakuStream;
  final bool initialDanmakuEnabled;
  final double initialDanmakuFontSize;
  final double initialDanmakuOpacity;
  final void Function(bool enabled, double fontSize, double opacity) onDanmakuChanged;

  const _FullScreenPlayer({
    required this.videoController,
    required this.isMuted,
    required this.onToggleMute,
    required this.onRefresh,
    required this.channelName,
    required this.danmakuStream,
    required this.initialDanmakuEnabled,
    required this.initialDanmakuFontSize,
    required this.initialDanmakuOpacity,
    required this.onDanmakuChanged,
  });

  @override
  State<_FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<_FullScreenPlayer> {
  bool _showControls = true;
  late bool _muted;
  late bool _danmakuEnabled;
  late double _danmakuFontSize;
  late double _danmakuOpacity;

  @override
  void initState() {
    super.initState();
    _muted = widget.isMuted;
    _danmakuEnabled = widget.initialDanmakuEnabled;
    _danmakuFontSize = widget.initialDanmakuFontSize;
    _danmakuOpacity = widget.initialDanmakuOpacity;
    _scheduleHideControls();
  }

  @override
  void dispose() {
    widget.onDanmakuChanged(_danmakuEnabled, _danmakuFontSize, _danmakuOpacity);
    super.dispose();
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showControls = false); });
  }

  void _onTapVideo() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _toggleMute() { setState(() => _muted = !_muted); widget.onToggleMute(); }

  void _toggleDanmaku() {
    setState(() => _danmakuEnabled = !_danmakuEnabled);
    widget.onDanmakuChanged(_danmakuEnabled, _danmakuFontSize, _danmakuOpacity);
  }

  void _openDanmakuSettings() {
    setState(() => _showControls = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _DanmakuSettingsSheet(
        fontSize: _danmakuFontSize,
        opacity: _danmakuOpacity,
        onFontSizeChanged: (v) {
          setState(() => _danmakuFontSize = v);
          widget.onDanmakuChanged(_danmakuEnabled, _danmakuFontSize, _danmakuOpacity);
        },
        onOpacityChanged: (v) {
          setState(() => _danmakuOpacity = v);
          widget.onDanmakuChanged(_danmakuEnabled, _danmakuFontSize, _danmakuOpacity);
        },
      ),
    ).then((_) => _scheduleHideControls());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTapVideo,
        child: Stack(fit: StackFit.expand, children: [
          // 视频 — 竖屏下按宽度铺满,16:9 居中显示
// 视频 — 填满屏幕并裁剪 (cover 效果)
Positioned.fill(
  child: FittedBox(
    fit: BoxFit.cover,
    child: SizedBox(
      width: widget.videoController.value.size.width,
      height: widget.videoController.value.size.height,
      child: VideoPlayer(widget.videoController),
    ),
  ),
),

          // 弹幕层
          Positioned.fill(
            child: IgnorePointer(
              child: _DanmakuOverlay(
                stream: widget.danmakuStream,
                enabled: _danmakuEnabled,
                fontSize: _danmakuFontSize,
                opacity: _danmakuOpacity,
              ),
            ),
          ),

          // 顶部栏 — 返回 + 标题
          if (_showControls)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Text('LIVE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.channelName,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ),
            ),

          // 底部栏 — 左: 弹幕开关 + 设置;右: 音量 + 刷新 + 退出
          if (_showControls)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    _controlButton(
                      _danmakuEnabled ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
                      _toggleDanmaku,
                      active: _danmakuEnabled,
                    ),
                    const SizedBox(width: 8),
                    _controlButton(Icons.tune_rounded, _openDanmakuSettings),
                    const Spacer(),
                    _controlButton(_muted ? Icons.volume_off : Icons.volume_up, _toggleMute),
                    const SizedBox(width: 8),
                    _controlButton(Icons.refresh, widget.onRefresh),
                    const SizedBox(width: 8),
                    _controlButton(Icons.fullscreen_exit, () => Navigator.of(context).pop()),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active ? Colors.deepPurple.withOpacity(0.75) : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: Colors.deepPurpleAccent, width: 1) : null,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── 弹幕叠加层 ──
class _DanmakuOverlay extends StatefulWidget {
  final Stream<_DanmakuItem> stream;
  final bool enabled;
  final double fontSize;
  final double opacity;

  const _DanmakuOverlay({
    required this.stream,
    required this.enabled,
    required this.fontSize,
    required this.opacity,
  });

  @override
  State<_DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<_DanmakuOverlay> {
  static const int _kTrackCount = 5;
  late StreamSubscription<_DanmakuItem> _sub;
  final List<_BulletRuntime> _bullets = [];
  final List<DateTime> _trackLastSpawn =
      List.filled(_kTrackCount, DateTime.fromMillisecondsSinceEpoch(0), growable: false);
  int _nextKey = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_onItem);
  }

  void _onItem(_DanmakuItem item) {
    if (!mounted || !widget.enabled) return;
    int track = 0;
    DateTime oldest = _trackLastSpawn[0];
    for (int i = 1; i < _trackLastSpawn.length; i++) {
      if (_trackLastSpawn[i].isBefore(oldest)) {
        oldest = _trackLastSpawn[i];
        track = i;
      }
    }
    _trackLastSpawn[track] = DateTime.now();
    setState(() {
      _bullets.add(_BulletRuntime(key: _nextKey++, item: item, track: track));
    });
  }

  void _removeBullet(int key) {
    if (!mounted) return;
    setState(() => _bullets.removeWhere((b) => b.key == key));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = widget.fontSize * 2.4;
        const topPadding = 60.0; // 竖屏下避开顶部状态栏/标题
        return Stack(
          clipBehavior: Clip.none,
          children: _bullets.map((b) {
            return _DanmakuBullet(
              key: ValueKey(b.key),
              item: b.item,
              top: topPadding + b.track * trackHeight,
              screenWidth: constraints.maxWidth,
              fontSize: widget.fontSize,
              opacity: widget.opacity,
              onDone: () => _removeBullet(b.key),
            );
          }).toList(),
        );
      },
    );
  }
}

class _BulletRuntime {
  final int key;
  final _DanmakuItem item;
  final int track;
  _BulletRuntime({required this.key, required this.item, required this.track});
}

// ── 单条弹幕 ──
class _DanmakuBullet extends StatefulWidget {
  final _DanmakuItem item;
  final double top;
  final double screenWidth;
  final double fontSize;
  final double opacity;
  final VoidCallback onDone;

  const _DanmakuBullet({
    super.key,
    required this.item,
    required this.top,
    required this.screenWidth,
    required this.fontSize,
    required this.opacity,
    required this.onDone,
  });

  @override
  State<_DanmakuBullet> createState() => _DanmakuBulletState();
}

class _DanmakuBulletState extends State<_DanmakuBullet> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final GlobalKey _contentKey = GlobalKey();
  double _contentWidth = 0;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    // 竖屏下屏幕更窄,速度相应调快一些
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.item.isGift ? 7000 : 6000),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        setState(() {
          _contentWidth = box.size.width;
          _measured = true;
        });
      }
      _ctrl.forward().whenComplete(() { if (mounted) widget.onDone(); });
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final totalDistance = widget.screenWidth + _contentWidth;
        final x = widget.screenWidth - totalDistance * _ctrl.value;
        return Positioned(
          top: widget.top,
          left: x,
          child: Opacity(
            opacity: _measured ? widget.opacity : 0,
            child: child,
          ),
        );
      },
      child: Container(
        key: _contentKey,
        child: widget.item.isGift ? _buildGiftBullet() : _buildNormalBullet(),
      ),
    );
  }

  Widget _buildNormalBullet() {
    return Text(
      widget.item.text,
      style: TextStyle(
        color: widget.item.accentColor,
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w600,
        shadows: const [
          Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2),
          Shadow(color: Colors.black, offset: Offset(-1, -1), blurRadius: 2),
          Shadow(color: Colors.black87, blurRadius: 3),
        ],
      ),
    );
  }

  Widget _buildGiftBullet() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.fontSize * 0.85,
        vertical: widget.fontSize * 0.4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFF6F00), Color(0xFFE91E63)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(widget.fontSize * 1.5),
        border: Border.all(color: Colors.yellowAccent.shade400, width: 1.8),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.7), blurRadius: 14, spreadRadius: 1),
          BoxShadow(color: Colors.pinkAccent.withOpacity(0.45), blurRadius: 22, spreadRadius: 3),
        ],
      ),
      child: Text(
        widget.item.text,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.fontSize * 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          shadows: const [
            Shadow(color: Colors.black38, offset: Offset(1, 1), blurRadius: 2),
            Shadow(color: Color(0xFFB71C1C), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

// ── 弹幕设置面板 (紧凑化) ──
class _DanmakuSettingsSheet extends StatefulWidget {
  final double fontSize;
  final double opacity;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onOpacityChanged;

  const _DanmakuSettingsSheet({
    required this.fontSize,
    required this.opacity,
    required this.onFontSizeChanged,
    required this.onOpacityChanged,
  });

  @override
  State<_DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<_DanmakuSettingsSheet> {
  late double _fontSize;
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _opacity = widget.opacity;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 36, height: 3,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(children: [
          const Icon(Icons.subtitles_rounded, color: Colors.deepPurpleAccent, size: 16),
          const SizedBox(width: 6),
          Text(lang.t('danmaku_settings'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),

        // 预览区 (紧凑)
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade900, Colors.black],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: _opacity,
            child: Text(
              'Demo: Hello! 👋',
              style: TextStyle(
                color: Colors.white,
                fontSize: _fontSize,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2),
                  Shadow(color: Colors.black, offset: Offset(-1, -1), blurRadius: 2),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 字体大小
        Row(children: [
          const Icon(Icons.format_size, color: Colors.white60, size: 14),
          const SizedBox(width: 4),
          Text(lang.t('danmaku_font_size'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
            child: Text('${_fontSize.round()}',
                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: _fontSize, min: 12, max: 30, divisions: 9,
            activeColor: Colors.deepPurpleAccent,
            inactiveColor: Colors.white12,
            onChanged: (v) {
              setState(() => _fontSize = v);
              widget.onFontSizeChanged(v);
            },
          ),
        ),

        // 透明度
        Row(children: [
          const Icon(Icons.opacity, color: Colors.white60, size: 14),
          const SizedBox(width: 4),
          Text(lang.t('danmaku_opacity'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
            child: Text('${(_opacity * 100).round()}%',
                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: _opacity, min: 0.3, max: 1.0, divisions: 7,
            activeColor: Colors.deepPurpleAccent,
            inactiveColor: Colors.white12,
            onChanged: (v) {
              setState(() => _opacity = v);
              widget.onOpacityChanged(v);
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 34,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(lang.t('done'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}