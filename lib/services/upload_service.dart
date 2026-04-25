// Path: lib/services/upload_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/database.dart';

class UploadService {
  // ✅ 跟你 get_announcements.php 同目錄
  static const String _uploadUrl =
      '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/upload_cover.php';

  /// 上傳封面圖片，返回圖片 URL
  static Future<String?> uploadCoverImage(File imageFile, String teacherId) async {
    try {
      print('📤 上傳封面圖片: ${imageFile.path}');

      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      // 加入 teacherId 欄位
      request.fields['teacherId'] = teacherId;

      // 加入圖片文件
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('📡 上傳回應: ${response.statusCode}');
      print('📄 回應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['url'] != null) {
          print('✅ 封面上傳成功: ${data['url']}');
          return data['url'] as String;
        } else {
          print('❌ 上傳失敗: ${data['error']}');
          return null;
        }
      } else {
        print('❌ HTTP 錯誤: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 上傳異常: $e');
      return null;
    }
  }
}