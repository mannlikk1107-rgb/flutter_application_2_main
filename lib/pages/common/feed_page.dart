import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/database.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ivs_service.dart';
import 'user_profile_page.dart';

// ═══════════════════════════════════════════════════════════════
// 主頁面 - 帶 TabBar (老師版僅顯示自己動態)
// ═══════════════════════════════════════════════════════════════
class FeedPage extends StatefulWidget {
  final bool isTeacher;
  const FeedPage({super.key, this.isTeacher = false});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  Set<String> _liveTeacherIds = {};

  @override
  void initState() {
    super.initState();
    if (!widget.isTeacher) {
      _tabController = TabController(length: 2, vsync: this);
    }
    _loadLiveStatus();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadLiveStatus() async {
    try {
      final liveChannels = await IVSApiService.fetchLiveChannels();
      if (!mounted) return;
      setState(() {
        _liveTeacherIds = liveChannels
            .map((c) => c.teacherId ?? c.id)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
      });
    } catch (e) {
      debugPrint('Error loading live status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    if (widget.isTeacher) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        appBar: AppBar(
          title: Text(lang.isEnglish ? 'My Posts' : '我的動態',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: MyOwnPostsFeed(
          liveTeacherIds: _liveTeacherIds,
          onRefreshLive: _loadLiveStatus,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(lang.t('community_feed'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(text: lang.t('tab_following')),
            Tab(text: lang.t('tab_all')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FollowingFeed(
            liveTeacherIds: _liveTeacherIds,
            onRefreshLive: _loadLiveStatus,
          ),
          AllPostsFeed(
            liveTeacherIds: _liveTeacherIds,
            onRefreshLive: _loadLiveStatus,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 1: 關注頁面 — 頭像列 + 篩選貼文
// ═══════════════════════════════════════════════════════════════
class FollowingFeed extends StatefulWidget {
  final Set<String> liveTeacherIds;
  final VoidCallback onRefreshLive;
  const FollowingFeed({
    super.key,
    required this.liveTeacherIds,
    required this.onRefreshLive,
  });

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed> with AutomaticKeepAliveClientMixin {
  List<FollowedUser> _following = [];
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _selectedTeacherId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchFollowing(), _fetchPosts()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchFollowing() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.mId.isEmpty) return;
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}'
          '/api/get_following_list.php?userId=${userProvider.mId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _following = (data['following'] as List)
                .map((json) => FollowedUser.fromJson(json))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching following: $e');
    }
  }

  Future<void> _fetchPosts() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.mId.isEmpty) return;
    try {
      String url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}'
          '/api/get_following_posts.php?userId=${userProvider.mId}';
      if (_selectedTeacherId != null) {
        url += '&teacherId=$_selectedTeacherId';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _posts = (data['posts'] as List).map((json) => Post.fromJson(json)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching following posts: $e');
    }
  }

  void _selectTeacher(String? teacherId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTeacherId = teacherId;
      _isLoading = true;
    });
    _fetchPosts().then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _refresh() async {
    widget.onRefreshLive();
    await _loadAll();
  }

  void _removePost(String postId) {
    setState(() {
      _posts.removeWhere((p) => p.id == postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = Provider.of<LanguageProvider>(context);

    return Column(
      children: [
        if (_following.isNotEmpty) _buildAvatarRow(lang),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _following.isEmpty
                  ? _buildEmptyFollowingState(lang)
                  : _posts.isEmpty
                      ? _buildNoPostsState(lang)
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: const Color(0xFF6366F1),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _posts.length,
                            itemBuilder: (context, index) {
                              final post = _posts[index];
                              return PostCard(
                                post: post,
                                isLive: widget.liveTeacherIds.contains(post.userId),
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
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildAvatarRow(LanguageProvider lang) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _following.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAvatarItem(
              name: lang.t('avatar_all'),
              isSelected: _selectedTeacherId == null,
              isLive: false,
              onTap: () => _selectTeacher(null),
              isAllButton: true,
            );
          }
          final user = _following[index - 1];
          final isLive = widget.liveTeacherIds.contains(user.mId);
          return _buildAvatarItem(
            name: user.displayName,
            initial: user.initial,
            isSelected: _selectedTeacherId == user.mId,
            isLive: isLive,
            onTap: () => _selectTeacher(user.mId),
            onLongPress: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(
                    targetUserId: user.mId,
                    targetUserName: user.displayName,
                  ),
                ),
              ).then((_) => _loadAll());
            },
          );
        },
      ),
    );
  }

  Widget _buildAvatarItem({
    required String name,
    String? initial,
    required bool isSelected,
    required bool isLive,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool isAllButton = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(isLive ? 2.5 : (isSelected ? 2 : 0)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isLive
                        ? const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)],
                          )
                        : null,
                    border: !isLive && isSelected
                        ? Border.all(color: const Color(0xFF6366F1), width: 2.5)
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: isAllButton
                        ? const Color(0xFF6366F1).withOpacity(0.1)
                        : const Color(0xFF6366F1).withOpacity(0.15),
                    child: isAllButton
                        ? const Icon(Icons.public, color: Color(0xFF6366F1), size: 24)
                        : Text(
                            initial ?? 'U',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                  ),
                ),
                if (isLive)
                  Positioned(
                    bottom: -2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFollowingState(LanguageProvider lang) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF6366F1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Center(
            child: Text(
              lang.t('no_following'),
              style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              lang.t('no_following_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPostsState(LanguageProvider lang) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF6366F1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Center(
            child: Text(lang.t('no_posts'), style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 2: 所有動態 — 原本的 Feed 邏輯
// ═══════════════════════════════════════════════════════════════
class AllPostsFeed extends StatefulWidget {
  final Set<String> liveTeacherIds;
  final VoidCallback onRefreshLive;
  const AllPostsFeed({
    super.key,
    required this.liveTeacherIds,
    required this.onRefreshLive,
  });

  @override
  State<AllPostsFeed> createState() => _AllPostsFeedState();
}

class _AllPostsFeedState extends State<AllPostsFeed> with AutomaticKeepAliveClientMixin {
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}'
          '/api/get_feed_posts.php?userId=${userProvider.mId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _posts = (data['posts'] as List).map((json) => Post.fromJson(json)).toList();
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    widget.onRefreshLive();
    await _fetchPosts();
  }

  void _removePost(String postId) {
    setState(() {
      _posts.removeWhere((p) => p.id == postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = Provider.of<LanguageProvider>(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF6366F1),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Center(child: Text(lang.t('no_posts'), style: TextStyle(color: Colors.grey[500], fontSize: 16))),
            const SizedBox(height: 8),
            Center(child: Text(lang.t('first_post'), style: TextStyle(color: Colors.grey[400], fontSize: 14))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF6366F1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return PostCard(
            post: post,
            isLive: widget.liveTeacherIds.contains(post.userId),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 老師專用：只看自己的動態
// ═══════════════════════════════════════════════════════════════
class MyOwnPostsFeed extends StatefulWidget {
  final Set<String> liveTeacherIds;
  final VoidCallback onRefreshLive;
  const MyOwnPostsFeed({
    super.key,
    required this.liveTeacherIds,
    required this.onRefreshLive,
  });

  @override
  State<MyOwnPostsFeed> createState() => _MyOwnPostsFeedState();
}

class _MyOwnPostsFeedState extends State<MyOwnPostsFeed> with AutomaticKeepAliveClientMixin {
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.mId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}'
          '/api/get_my_posts.php?mId=${userProvider.mId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _posts = (data['posts'] as List).map((j) => Post.fromJson(j)).toList();
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Fetch my posts error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    widget.onRefreshLive();
    await _fetchPosts();
  }

  void _removePost(String postId) {
    setState(() {
      _posts.removeWhere((p) => p.id == postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF6366F1),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Icon(Icons.post_add_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Center(
              child: Text(
                lang.isEnglish ? 'No posts yet' : '尚未發佈任何動態',
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                lang.isEnglish ? 'Tap + to create your first post' : '點擊右下角 + 發佈第一則動態',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF6366F1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return PostCard(
            post: post,
            isLive: widget.liveTeacherIds.contains(post.userId),
            showAvatarTap: false,
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 資料模型
// ═══════════════════════════════════════════════════════════════
class FollowedUser {
  final String mId;
  final String fName;
  final String nName;
  final String mType;
  final int postCount;

  FollowedUser({
    required this.mId,
    required this.fName,
    required this.nName,
    required this.mType,
    required this.postCount,
  });

  String get displayName {
    if (fName.isNotEmpty) return fName;
    if (nName.isNotEmpty) return nName;
    return 'User';
  }

  String get initial {
    final name = displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  factory FollowedUser.fromJson(Map<String, dynamic> json) {
    return FollowedUser(
      mId: json['mId']?.toString() ?? '',
      fName: json['fName']?.toString() ?? '',
      nName: json['nName']?.toString() ?? '',
      mType: json['mType']?.toString() ?? '',
      postCount: int.tryParse(json['postCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class Post {
  final String id;
  final String userId;
  final String userName; // 固定顯示全名 (fName)
  final String? userAvatar;
  final String content;
  final String? imageUrl;
  int likeCount;
  int commentCount;
  final DateTime createdAt;
  bool isLiked;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['imageUrl'];
    if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/uploads/posts/$imageUrl';
    }

    // ── 固定顯示全名：優先 fName，fallback teacherName ──
    final String fullName = (json['fName']?.toString() ?? '').trim();
    final String fallbackName = (json['teacherName']?.toString() ?? '').trim();
    final String resolvedName = fullName.isNotEmpty ? fullName : (fallbackName.isNotEmpty ? fallbackName : '用戶');

    return Post(
      id: json['postId']?.toString() ?? '',
      userId: json['mId']?.toString() ?? '',
      userName: resolvedName,
      userAvatar: json['userAvatar'],
      content: json['content'] ?? '',
      imageUrl: imageUrl,
      likeCount: int.tryParse(json['likeCount']?.toString() ?? '0') ?? 0,
      commentCount: int.tryParse(json['commentCount']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['createDate'] ?? '') ?? DateTime.now(),
      isLiked: json['isLiked'] == 1 || json['isLiked'] == true,
    );
  }
}

// ✅ 扁平評論模型（用於 API 接收）
class PostCommentFlat {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createDate;
  int likeCount;
  bool isLiked;
  final String? parentId;
  final String? parentUserName;

  PostCommentFlat({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createDate,
    required this.likeCount,
    required this.isLiked,
    this.parentId,
    this.parentUserName,
  });

  factory PostCommentFlat.fromJson(Map<String, dynamic> json) {
    // 評論也固定取全名
    final String fullName = (json['fName']?.toString() ?? '').trim();
    final String fallbackName = (json['userName']?.toString() ?? '').trim();
    final String resolvedName = fullName.isNotEmpty ? fullName : (fallbackName.isNotEmpty ? fallbackName : '匿名');

    return PostCommentFlat(
      id: json['commentId']?.toString() ?? '',
      userId: json['mId']?.toString() ?? '',
      userName: resolvedName,
      content: json['content'] ?? '',
      createDate: DateTime.tryParse(json['createDate'] ?? '') ?? DateTime.now(),
      likeCount: int.tryParse(json['likeCount']?.toString() ?? '0') ?? 0,
      isLiked: json['isLiked'] == 1 || json['isLiked'] == true,
      parentId: json['parentId']?.toString(),
      parentUserName: json['parentUserName']?.toString(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PostCard — 單個貼文卡片 (含摺疊式回覆)
// ═══════════════════════════════════════════════════════════════
class PostCard extends StatefulWidget {
  final Post post;
  final bool isLive;
  final bool showAvatarTap;
  final Function(String, int, bool) onLikeChanged;
  final Function(String, int) onCommentAdded;
  final Function(String) onPostDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.isLive = false,
    this.showAvatarTap = true,
    required this.onLikeChanged,
    required this.onCommentAdded,
    required this.onPostDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
  }

  String _formatDate(DateTime date) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 7) {
      return '${date.year}/${date.month}/${date.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}${lang.t('days_ago')}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}${lang.t('hours_ago')}';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}${lang.t('minutes_ago')}';
    } else {
      return lang.t('just_now');
    }
  }

  void _openUserProfile() {
    if (!widget.showAvatarTap) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          targetUserId: widget.post.userId,
          targetUserName: widget.post.userName,
        ),
      ),
    );
  }

  Future<void> _sharePost() async {
    HapticFeedback.mediumImpact();
    String shareText = "${widget.post.userName}: ${widget.post.content}";
    try {
      if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) {
        final response = await http.get(Uri.parse(widget.post.imageUrl!));
        final temp = await getTemporaryDirectory();
        final path = '${temp.path}/share_${widget.post.id}.jpg';
        await File(path).writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(path)], text: shareText);
      } else {
        await Share.share(shareText);
      }
    } catch (e) {
      debugPrint('分享出錯: $e');
      await Share.share(shareText);
    }
  }

  Future<void> _toggleLike() async {
    HapticFeedback.mediumImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.mId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('please_login_first'))),
      );
      return;
    }

    final bool newLikedState = !_isLiked;
    final int newLikeCount = _likeCount + (newLikedState ? 1 : -1);

    setState(() {
      _isLiked = newLikedState;
      _likeCount = newLikeCount;
    });
    widget.onLikeChanged(widget.post.id, newLikeCount, newLikedState);

    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/toggle_like.php';
      final response = await http.post(Uri.parse(url), body: {
        'postId': widget.post.id,
        'mId': userProvider.mId,
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          setState(() {
            _isLiked = !newLikedState;
            _likeCount = _likeCount + (newLikedState ? -1 : 1);
          });
          widget.onLikeChanged(widget.post.id, _likeCount, _isLiked);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? Provider.of<LanguageProvider>(context, listen: false).t('operation_failed'))),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLiked = !newLikedState;
        _likeCount = _likeCount + (newLikedState ? -1 : 1);
      });
      widget.onLikeChanged(widget.post.id, _likeCount, _isLiked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('network_error_retry'))),
      );
    }
  }

  Future<void> _deletePost() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.t('delete_post'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(lang.t('delete_post_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lang.t('delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/delete_post.php';
      final response = await http.post(Uri.parse(url), body: {'postId': widget.post.id, 'mId': userProvider.mId});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.t('post_deleted')), backgroundColor: Colors.green),
          );
          widget.onPostDeleted(widget.post.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? lang.t('delete')), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('network_error_retry')), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<PostCommentFlat>> _fetchFlatComments(String postId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}'
          '/api/get_comments.php?postId=$postId&userId=${userProvider.mId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['comments'] as List)
              .map((json) => PostCommentFlat.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }
    return [];
  }

  Future<void> _toggleCommentLike(String commentId, StateSetter setModalState) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.mId.isEmpty) return;
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/toggle_comment_like.php';
      final response = await http.post(Uri.parse(url), body: {
        'commentId': commentId,
        'mId': userProvider.mId,
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) setModalState(() {});
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
    }
  }

  // ─── 構建單個評論項目 ───────────────────────────────────────
  // FIX: 用 Flexible 包裹用戶名與回覆標籤，防止 Row overflow
  Widget _buildCommentItem(
    PostCommentFlat c, {
    required bool isReply,
    required VoidCallback onReply,
    required StateSetter setModalState,
  }) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 50.0 : 15.0, right: 15.0, top: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頭像
          CircleAvatar(
            radius: isReply ? 12 : 18,
            backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
            child: Text(
              c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: isReply ? 10 : 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 內容區
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── FIX: 用 Row + Flexible 防止 overflow ──
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.parentUserName != null && c.parentUserName!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${lang.t('reply')} @${c.parentUserName}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(c.content, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(
                    _formatDate(c.createDate),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: onReply,
                    child: Text(
                      lang.t('reply'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // 點讚按鈕
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: Icon(
                c.isLiked ? Icons.favorite : Icons.favorite_border,
                color: c.isLiked ? Colors.red : Colors.grey,
                size: 18,
              ),
              onPressed: () => _toggleCommentLike(c.id, setModalState),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Text('${c.likeCount}', style: const TextStyle(fontSize: 10)),
          ]),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(String replyingToUserName, VoidCallback onCancel) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Text(
            '${lang.t('replying_to_prefix')} $replyingToUserName',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(onTap: onCancel, child: const Icon(Icons.close, size: 16)),
      ]),
    );
  }

  // ✅ 摺疊式回覆評論區底部彈窗
  void _showIGCommentSheet(BuildContext context, String postId) {
    String? _replyingToId;
    String _replyingToUserName = "";
    Set<String> _expandedCommentIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final lang = Provider.of<LanguageProvider>(context, listen: false);

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Text(
                    lang.t('comments_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<PostCommentFlat>>(
                    future: _fetchFlatComments(postId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            lang.t('no_comments'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final allComments = snapshot.data!;
                      final mainComments = allComments
                          .where((c) =>
                              c.parentId == null ||
                              c.parentId == "0" ||
                              c.parentId!.isEmpty)
                          .toList();

                      return ListView.builder(
                        itemCount: mainComments.length,
                        itemBuilder: (context, index) {
                          final main = mainComments[index];
                          final replies =
                              allComments.where((c) => c.parentId == main.id).toList();
                          final isExpanded = _expandedCommentIds.contains(main.id);

                          return Column(
                            children: [
                              _buildCommentItem(
                                main,
                                isReply: false,
                                onReply: () {
                                  setModalState(() {
                                    _replyingToId = main.id;
                                    _replyingToUserName = main.userName;
                                  });
                                },
                                setModalState: setModalState,
                              ),
                              if (replies.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 72.0, bottom: 8, top: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        if (isExpanded) {
                                          _expandedCommentIds.remove(main.id);
                                        } else {
                                          _expandedCommentIds.add(main.id);
                                        }
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Container(
                                            width: 24,
                                            height: 1,
                                            color: Colors.grey[300]),
                                        const SizedBox(width: 8),
                                        Text(
                                          isExpanded
                                              ? (lang.t('hide_replies'))
                                              : (lang.isEnglish
                                                  ? '—— View ${replies.length} replies'
                                                  : '—— 查看 ${replies.length} 則回覆'),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (isExpanded)
                                ...replies.map(
                                  (reply) => _buildCommentItem(
                                    reply,
                                    isReply: true,
                                    onReply: () {
                                      setModalState(() {
                                        _replyingToId = main.id;
                                        _replyingToUserName = reply.userName;
                                      });
                                    },
                                    setModalState: setModalState,
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_replyingToId != null)
                  _buildReplyIndicator(_replyingToUserName, () {
                    setModalState(() {
                      _replyingToId = null;
                      _replyingToUserName = "";
                    });
                  }),
                _buildCommentInputArea(postId, _replyingToId, () {
                  setModalState(() {
                    _replyingToId = null;
                    _replyingToUserName = "";
                  });
                }),
              ]),
            );
          },
        );
      },
    ).whenComplete(() {
      widget.onCommentAdded(postId, _commentCount);
    });
  }

  Widget _buildCommentInputArea(
      String postId, String? replyingToId, VoidCallback onCommentSuccess) {
    final TextEditingController controller = TextEditingController();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final FocusNode focusNode = FocusNode();

    return Container(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: replyingToId != null
                  ? lang.t('replying_hint')
                  : lang.t('add_comment_hint'),
              border: InputBorder.none,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            if (controller.text.trim().isEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(lang.t('comment_required'))));
              return;
            }
            try {
              final url =
                  '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/add_comment.php';
              final body = {
                'postId': postId,
                'mId': userProvider.mId,
                'content': controller.text.trim(),
              };
              if (replyingToId != null) body['parentId'] = replyingToId;
              final response = await http.post(Uri.parse(url), body: body);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['success'] == true) {
                  setState(() => _commentCount++);
                  widget.onCommentAdded(postId, _commentCount);
                  focusNode.unfocus();
                  controller.clear();
                  onCommentSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(lang.t('comment_posted_ok')),
                        backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(data['message'] ?? lang.t('operation_failed')),
                        backgroundColor: Colors.red),
                  );
                }
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(lang.t('network_error_retry')),
                    backgroundColor: Colors.red),
              );
            }
          },
          child: Text(lang.t('publish_btn'),
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildAvatarWithLive() {
    final avatar = Container(
      padding: EdgeInsets.all(widget.isLive ? 2 : 0),
      decoration: widget.isLive
          ? const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)]),
            )
          : null,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
        child: Text(
          widget.post.userName.isNotEmpty ? widget.post.userName[0].toUpperCase() : 'U',
          style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
        ),
      ),
    );

    if (!widget.isLive) return avatar;

    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        bottom: -3,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                  color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bool isOwnPost = widget.post.userId == userProvider.mId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            GestureDetector(
              onTap: _openUserProfile,
              child: _buildAvatarWithLive(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _openUserProfile,
                behavior: HitTestBehavior.opaque,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        widget.post.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isLive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  Text(_formatDate(widget.post.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
              ),
            ),
            if (isOwnPost)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'delete') _deletePost();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(lang.t('delete_post'),
                          style: const TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(widget.post.content,
              style: const TextStyle(fontSize: 15, height: 1.5)),
        ),

        if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: Image.network(
                        widget.post.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 100),
                      ),
                    ),
                  ),
                );
              },
              child: Image.network(
                widget.post.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Text('$_likeCount ${lang.t('likes_count')}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 16),
            Text('$_commentCount ${lang.t('comments_count')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.grey,
                size: 26,
              ),
              onPressed: _toggleLike,
            ),
            GestureDetector(
              onTap: () => _showIGCommentSheet(context, widget.post.id),
              child: Row(children: [
                const Icon(Icons.mode_comment_outlined, size: 24, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$_commentCount',
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ]),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_outlined, size: 24),
              color: Colors.grey,
              onPressed: _sharePost,
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}