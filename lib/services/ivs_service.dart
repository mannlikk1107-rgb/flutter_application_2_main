// Path: lib/services/ivs_service.dart
// ✅ 只改了 Channel 類，加了 thumbnailUrl / roomTitle / viewerCount
// IVSApiService 完全不變

import 'dart:convert';
import 'package:http/http.dart' as http;

/// 頻道模型 - 增加封面圖、標題、觀看人數
class Channel {
  final String id;
  final String name;
  final String playbackUrl;
  final bool isLive;
  final String? latencyMode;
  final String? teacherId;
  final String? teacherName;
  final String? ingestEndpoint;

  // ✅ 新增欄位
  final String? thumbnailUrl;   // 封面圖片 URL
  final String? roomTitle;      // 直播標題
  final int viewerCount;        // 觀看人數

  Channel({
    required this.id,
    required this.name,
    required this.playbackUrl,
    required this.isLive,
    this.latencyMode,
    this.teacherId,
    this.teacherName,
    this.ingestEndpoint,
    this.thumbnailUrl,
    this.roomTitle,
    this.viewerCount = 0,
  });

  /// 獲取聊天室 Collection 名稱
  String get chatCollectionName {
    final chatId = teacherId ?? id;
    return 'messages_$chatId';
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};

    return Channel(
      id: json['id'] ?? json['arn']?.split('/')?.last ?? '',
      name: json['name'] ?? '未命名頻道',
      playbackUrl: json['playbackUrl'] ?? '',
      isLive: json['isLive'] ?? false,
      latencyMode: json['latencyMode'],
      teacherId: tags['teacherId'] ?? json['teacherId'],
      teacherName: tags['teacherName'] ?? json['teacherName'],
      ingestEndpoint: json['ingestEndpoint'],
      // ✅ 新欄位 — 先從 json 讀，後面會從 Firestore 補充
      thumbnailUrl: json['thumbnailUrl'],
      roomTitle: json['roomTitle'],
      viewerCount: json['viewerCount'] ?? 0,
    );
  }

  /// ✅ 用 Firestore 的額外資料來補充此 Channel
  Channel copyWithFirestoreData({
    String? thumbnailUrl,
    String? roomTitle,
    int? viewerCount,
  }) {
    return Channel(
      id: id,
      name: name,
      playbackUrl: playbackUrl,
      isLive: isLive,
      latencyMode: latencyMode,
      teacherId: teacherId,
      teacherName: teacherName,
      ingestEndpoint: ingestEndpoint,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      roomTitle: roomTitle ?? this.roomTitle,
      viewerCount: viewerCount ?? this.viewerCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'playbackUrl': playbackUrl,
      'isLive': isLive,
      'latencyMode': latencyMode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'ingestEndpoint': ingestEndpoint,
      'thumbnailUrl': thumbnailUrl,
      'roomTitle': roomTitle,
      'viewerCount': viewerCount,
    };
  }
}

/// IVS API 服務（完全不變）
class IVSApiService {
  static const String _apiUrl =
      'https://4vuvkyig4nhnrsxkjdpemxs5by0lujul.lambda-url.ap-northeast-1.on.aws/';

  static const String _fallbackApiUrl =
      'https://22ye7xklsuy2agzcjmgy5p36lm0spvkw.lambda-url.ap-northeast-1.on.aws/';

  static Future<List<Channel>> fetchChannels() async {
    try {
      print('📡 Fetching channels from getIVSChannels Lambda...');

      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 15));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['channels'] != null) {
          final List<dynamic> channelsJson = data['channels'];
          final channels =
              channelsJson.map((ch) => Channel.fromJson(ch)).toList();
          print('✅ Loaded ${channels.length} channels from API');
          return channels;
        }
      }

      return await _fetchFromFallbackApi();
    } catch (e) {
      print('❌ Primary API failed: $e');
      return await _fetchFromFallbackApi();
    }
  }

  static Future<List<Channel>> fetchLiveChannels() async {
    final allChannels = await fetchChannels();
    final liveChannels = allChannels.where((ch) => ch.isLive).toList();
    print('🔴 Live channels: ${liveChannels.length} / ${allChannels.length}');
    return liveChannels;
  }

  static Future<List<Channel>> _fetchFromFallbackApi() async {
    try {
      print('📡 Trying fallback API...');

      final response = await http
          .post(
            Uri.parse(_fallbackApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'list'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['channels'] != null) {
          final List<dynamic> channelsJson = data['channels'];
          final channels =
              channelsJson.map((ch) => Channel.fromJson(ch)).toList();
          print('✅ Loaded ${channels.length} channels from fallback');
          return channels;
        }
      }

      throw Exception('Failed to load channels');
    } catch (e) {
      print('❌ Fallback API also failed: $e');
      rethrow;
    }
  }

  static Future<Channel?> getChannelDetails(String channelArn) async {
    try {
      final response = await http
          .post(
            Uri.parse(_fallbackApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'verify',
              'channelArn': channelArn,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['exists'] == true) {
          final ch = data['channel'];
          return Channel(
            id: ch['arn']?.split('/')?.last ?? '',
            name: ch['name'] ?? '',
            playbackUrl: ch['playbackUrl'] ?? '',
            isLive: ch['state'] == 'LIVE',
            ingestEndpoint: ch['ingestEndpoint'],
          );
        }
      }

      return null;
    } catch (e) {
      print('❌ Get channel details failed: $e');
      return null;
    }
  }
}