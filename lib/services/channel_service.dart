import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// 教師頻道資料模型
class TeacherChannel {
  final String mId;
  final String channelArn;
  final String channelName;
  final String ingestServer;
  final String streamKey;
  final String playbackUrl;
  final DateTime createdAt;
  final DateTime? lastLiveAt;

  TeacherChannel({
    required this.mId,
    required this.channelArn,
    required this.channelName,
    required this.ingestServer,
    required this.streamKey,
    required this.playbackUrl,
    required this.createdAt,
    this.lastLiveAt,
  });

  factory TeacherChannel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherChannel(
      mId: doc.id,
      channelArn: data['channelArn'] ?? '',
      channelName: data['channelName'] ?? '',
      ingestServer: data['ingestServer'] ?? '',
      streamKey: data['streamKey'] ?? '',
      playbackUrl: data['playbackUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLiveAt: (data['lastLiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'channelArn': channelArn,
      'channelName': channelName,
      'ingestServer': ingestServer,
      'streamKey': streamKey,
      'playbackUrl': playbackUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLiveAt': lastLiveAt != null ? Timestamp.fromDate(lastLiveAt!) : null,
    };
  }
  
  /// ✅ 檢查頻道資料是否完整
  bool get isValid {
    return channelArn.isNotEmpty && 
           ingestServer.isNotEmpty && 
           streamKey.isNotEmpty && 
           playbackUrl.isNotEmpty;
  }
}

/// 頻道服務 - 管理教師與 IVS 頻道的綁定
class ChannelService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'teacher_channels';
  
  // Lambda API URL
  static const String _apiUrl = 
      'https://22ye7xklsuy2agzcjmgy5p36lm0spvkw.lambda-url.ap-northeast-1.on.aws/';

  /// 獲取教師的頻道（如果存在）- 僅從 Firestore 讀取
  static Future<TeacherChannel?> getTeacherChannel(String mId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(mId).get();
      if (doc.exists) {
        final channel = TeacherChannel.fromFirestore(doc);
        // ✅ 檢查資料完整性
        if (!channel.isValid) {
          print('⚠️ 頻道資料不完整，需要重新創建');
          return null;
        }
        return channel;
      }
      return null;
    } catch (e) {
      print('❌ 獲取頻道失敗: $e');
      return null;
    }
  }

  /// 檢查教師是否已有頻道
  static Future<bool> hasChannel(String mId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(mId).get();
      return doc.exists;
    } catch (e) {
      print('❌ 檢查頻道失敗: $e');
      return false;
    }
  }

  /// ✅ 驗證 AWS IVS 頻道是否還存在
  static Future<bool> verifyChannelExists(String channelArn) async {
    if (channelArn.isEmpty) {
      print('⚠️ channelArn 為空，無法驗證');
      return false;
    }
    
    try {
      print('🔍 驗證頻道是否存在: $channelArn');
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verify',
          'channelArn': channelArn,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 驗證 API 回應: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('❌ 驗證 API 錯誤: ${response.statusCode} - ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body);
      final exists = data['exists'] == true;
      
      print(exists ? '✅ 頻道存在於 AWS' : '❌ 頻道不存在於 AWS（已被刪除）');
      return exists;
      
    } catch (e) {
      print('❌ 驗證頻道失敗: $e');
      return false;
    }
  }

  /// ✅ 刪除 Firestore 中的頻道記錄
  static Future<void> deleteChannelRecord(String mId) async {
    try {
      await _firestore.collection(_collection).doc(mId).delete();
      print('🗑️ 已刪除 Firestore 頻道記錄: $mId');
    } catch (e) {
      print('❌ 刪除頻道記錄失敗: $e');
    }
  }

  /// ✅ 為教師創建新頻道並綁定（每個教師獨立頻道）
  static Future<TeacherChannel?> createAndBindChannel(String mId, String teacherName) async {
    try {
      print('🚀 為教師 $mId ($teacherName) 創建新頻道...');
      
      // 呼叫 Lambda API 創建 IVS 頻道，傳入 teacherId
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'create',
          'teacherId': mId,           // ✅ 傳入教師 ID
          'teacherName': teacherName, // ✅ 傳入教師名稱
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 創建 API 回應: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        final errorBody = response.body;
        print('❌ API 錯誤詳情: $errorBody');
        throw Exception('API 錯誤: ${response.statusCode} - $errorBody');
      }

      final data = jsonDecode(response.body);
      
      if (data['success'] != true) {
        final errorMsg = data['error'] ?? '創建失敗';
        final errorType = data['errorType'] ?? 'Unknown';
        print('❌ 創建失敗: $errorType - $errorMsg');
        throw Exception('$errorType: $errorMsg');
      }

      print('✅ IVS 頻道創建成功: ${data['channel']['arn']}');
      print('📺 播放網址: ${data['streamConfig']['playbackUrl']}');
      print('🔑 串流金鑰: ${data['streamConfig']['streamKey']?.substring(0, 20)}...');

      // 存入 Firestore，綁定教師（使用 mId 作為 document ID）
      final channel = TeacherChannel(
        mId: mId,
        channelArn: data['channel']['arn'] ?? '',
        channelName: data['channel']['name'] ?? '',
        ingestServer: data['streamConfig']['ingestServer'] ?? '',
        streamKey: data['streamConfig']['streamKey'] ?? '',
        playbackUrl: data['streamConfig']['playbackUrl'] ?? '',
        createdAt: DateTime.now(),
      );

      // ✅ 驗證回傳的資料
      if (!channel.isValid) {
        print('❌ API 回傳的頻道資料不完整');
        throw Exception('頻道資料不完整');
      }

      // ✅ 使用 mId 作為 document ID，確保每個教師只有一個頻道記錄
      await _firestore.collection(_collection).doc(mId).set(channel.toFirestore());
      
      print('✅ 頻道已綁定到教師 $mId');
      
      return channel;
      
    } catch (e) {
      print('❌ 創建頻道失敗: $e');
      rethrow;
    }
  }

  /// 更新最後直播時間
  static Future<void> updateLastLiveTime(String mId) async {
    try {
      // ✅ 先檢查文檔是否存在
      final doc = await _firestore.collection(_collection).doc(mId).get();
      if (!doc.exists) {
        print('⚠️ 頻道記錄不存在，跳過更新直播時間');
        return;
      }
      
      await _firestore.collection(_collection).doc(mId).update({
        'lastLiveAt': Timestamp.now(),
      });
      print('✅ 已更新直播時間');
    } catch (e) {
      print('❌ 更新直播時間失敗: $e');
    }
  }

  /// ✅ 更新直播信息（標題 + 封面圖）— 開播前調用
  static Future<void> updateBroadcastInfo({
    required String mId,
    required String roomTitle,
    String? thumbnailUrl,
  }) async {
    try {
      final doc = await _firestore.collection(_collection).doc(mId).get();
      if (!doc.exists) {
        print('⚠️ 頻道記錄不存在，無法更新直播信息');
        return;
      }

      final Map<String, dynamic> updateData = {
        'roomTitle': roomTitle,
        'lastLiveAt': Timestamp.now(),
      };

      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        updateData['thumbnailUrl'] = thumbnailUrl;
      }

      await _firestore.collection(_collection).doc(mId).update(updateData);
      print('✅ 已更新直播信息: title=$roomTitle, thumbnail=$thumbnailUrl');
    } catch (e) {
      print('❌ 更新直播信息失敗: $e');
    }
  }

  /// ✅ 獲取所有正在直播的頻道的額外信息（標題、封面）
  /// 用於學生端 channel_list_page 補充 IVS 頻道數據
  static Future<Map<String, Map<String, dynamic>>> getAllBroadcastInfo() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final Map<String, Map<String, dynamic>> result = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        result[doc.id] = {
          'roomTitle': data['roomTitle'] ?? '',
          'thumbnailUrl': data['thumbnailUrl'] ?? '',
        };
      }

      print('✅ 獲取了 ${result.length} 個頻道的直播信息');
      return result;
    } catch (e) {
      print('❌ 獲取直播信息失敗: $e');
      return {};
    }
  }

  /// ✅ 獲取並驗證頻道（用於啟動直播前）
  /// 這個方法會驗證 AWS 頻道是否存在，如果不存在會自動重新創建
  static Future<TeacherChannel?> getVerifiedChannel(String mId, String teacherName) async {
    print('🔄 獲取並驗證頻道...');
    
    // 1. 先嘗試獲取現有頻道
    final existing = await getTeacherChannel(mId);
    
    if (existing != null) {
      print('📺 找到現有頻道記錄: ${existing.channelArn}');
      
      // 2. ✅ 驗證頻道是否還存在於 AWS IVS
      final channelExists = await verifyChannelExists(existing.channelArn);
      
      if (channelExists) {
        print('✅ 頻道有效，可以使用');
        return existing;
      } else {
        // 3. 頻道已被刪除，清理 Firestore 記錄
        print('⚠️ 頻道已被刪除，清理舊記錄並重新創建...');
        await deleteChannelRecord(mId);
      }
    }
    
    // 4. 創建新頻道
    print('🆕 正在創建新頻道...');
    return await createAndBindChannel(mId, teacherName);
  }

  /// ✅ 獲取或創建頻道（主要入口方法）- 包含驗證邏輯
  static Future<TeacherChannel?> getOrCreateChannel(String mId, String teacherName) async {
    return await getVerifiedChannel(mId, teacherName);
  }

  /// ✅ 強制重新創建頻道（用於手動重置）
  static Future<TeacherChannel?> forceRecreateChannel(String mId, String teacherName) async {
    print('🔄 強制重新創建頻道...');
    // 刪除舊記錄
    await deleteChannelRecord(mId);
    // 創建新頻道
    return await createAndBindChannel(mId, teacherName);
  }
  
  /// ✅ 測試 API 連接
  static Future<bool> testApiConnection() async {
    try {
      print('🧪 測試 API 連接...');
      final response = await http.get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));
      
      print('📡 API 測試回應: ${response.statusCode}');
      print('📄 回應內容: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ API 連接測試失敗: $e');
      return false;
    }
  }
}