// 路徑: lib/pages/common/user_profile_page.dart
// ✅ 新檔案: 點頭像進入的個人頁 (含關注按鈕 + 該使用者所有動態)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/database.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ivs_service.dart';
import 'feed_page.dart'; // 共用 Post / PostCard

class UserProfilePage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const UserProfilePage({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  List<Post> _posts = [];
  Map<String, dynamic> _userInfo = {};
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isLive = false;
  int _followerCount = 0;
  int _postCount = 0;
  bool _followLoading = false;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _displayName = widget.targetUserName;
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchProfile(), _checkLiveStatus()]);
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}'
          '/api/get_user_posts.php'
          '?targetId=${widget.targetUserId}&viewerId=${userProvider.mId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final user = Map<String, dynamic>.from(data['user'] ?? {});
// ✅ 新的 — fName 優先
        final name = (user['fName']?.toString().isNotEmpty == true)
            ? user['fName'].toString()
            : (user['nName']?.toString().isNotEmpty == true
                ? user['nName'].toString()
                : widget.targetUserName);
          if (!mounted) return;
          setState(() {
            _userInfo = user;
            _displayName = name;
            _isFollowing = user['isFollowing'] == true;
            _followerCount = int.tryParse(user['followerCount']?.toString() ?? '0') ?? 0;
            _postCount = int.tryParse(user['postCount']?.toString() ?? '0') ?? 0;
            _posts = (data['posts'] as List).map((json) => Post.fromJson(json)).toList();
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _checkLiveStatus() async {
    try {
      final liveChannels = await IVSApiService.fetchLiveChannels();
      final ids = liveChannels
          .map((c) => c.teacherId ?? c.id)
          .whereType<String>()
          .toSet();
      if (!mounted) return;
      setState(() => _isLive = ids.contains(widget.targetUserId));
    } catch (e) {
      debugPrint('Error checking live: $e');
    }
  }

  Future<void> _toggleFollow() async {
    HapticFeedback.mediumImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (userProvider.mId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('please_login_first'))),
      );
      return;
    }
    if (userProvider.mId == widget.targetUserId) return;

    setState(() => _followLoading = true);

    // 樂觀更新
    final oldState = _isFollowing;
    setState(() {
      _isFollowing = !oldState;
      _followerCount += (_isFollowing ? 1 : -1);
    });

    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/toggle_follow.php';
      final response = await http.post(Uri.parse(url), body: {
        'followerMId': userProvider.mId,
        'followingMId': widget.targetUserId,
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;
          setState(() {
            _isFollowing = data['isFollowing'] == true;
            _followLoading = false;
          });
          return;
        }
      }
      // 失敗: 還原
      if (!mounted) return;
      setState(() {
        _isFollowing = oldState;
        _followerCount += (oldState ? 1 : -1);
        _followLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('operation_failed'))));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFollowing = oldState;
        _followerCount += (oldState ? 1 : -1);
        _followLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('network_error_retry'))));
    }
  }

  void _removePost(String postId) {
    setState(() {
      _posts.removeWhere((p) => p.id == postId);
      if (_postCount > 0) _postCount--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final isOwn = userProvider.mId == widget.targetUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: Text(
          _displayName,
          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: const Color(0xFF6366F1),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(lang, isOwn)),
                  if (_posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(lang.t('no_posts'), style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = _posts[index];
                            return PostCard(
                              post: post,
                              isLive: _isLive,
                              showAvatarTap: false, // 已在個人頁, 不再跳轉
                              onLikeChanged: (postId, newLikeCount, isLiked) {
                                setState(() {
                                  final i = _posts.indexWhere((p) => p.id == postId);
                                  if (i != -1) {
                                    _posts[i].likeCount = newLikeCount;
                                    _posts[i].isLiked = isLiked;
                                  }
                                });
                              },
                              onCommentAdded: (postId, newCommentCount) {
                                setState(() {
                                  final i = _posts.indexWhere((p) => p.id == postId);
                                  if (i != -1) _posts[i].commentCount = newCommentCount;
                                });
                              },
                              onPostDeleted: _removePost,
                            );
                          },
                          childCount: _posts.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(LanguageProvider lang, bool isOwn) {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          // 大頭像 + LIVE
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(_isLive ? 3 : 0),
                decoration: _isLive
                    ? const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)]),
                      )
                    : null,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                    ),
                  ),
                ),
              ),
              if (_isLive)
                Positioned(
                  bottom: -4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _displayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          if (_userInfo['mType'] != null && _userInfo['mType'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _userInfo['mType'].toString(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat(_postCount.toString(), lang.t('stat_posts')),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 28),
              ),
              _buildStat(_followerCount.toString(), lang.t('stat_followers')),
            ],
          ),
          const SizedBox(height: 18),
          if (!isOwn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _followLoading ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey.shade100 : const Color(0xFF6366F1),
                  foregroundColor: _isFollowing ? const Color(0xFF1E293B) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: _isFollowing
                        ? BorderSide(color: Colors.grey.shade300, width: 1)
                        : BorderSide.none,
                  ),
                  elevation: 0,
                ),
                child: _followLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isFollowing ? lang.t('unfollow') : lang.t('follow'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}