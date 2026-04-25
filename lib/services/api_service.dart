import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/database.dart';
import '../models/course_model.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 15);

  // ========== 認證相關 ==========
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String userType = 'auto',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(DatabaseConfig.getLoginUrl()),
        body: {'username': username, 'password': password, 'userType': userType},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> adminLogin({
    required String username, 
    required String password
  }) async {
    return login(username: username, password: password, userType: 'ADMIN');
  }

  static Future<bool> register({
    required String fName,
    required String nName,
    required String email,
    required String password,
    required String address,
    required String tel,
    required String mType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(DatabaseConfig.getRegisterUrl()),
        body: {
          'fName': fName, 'nName': nName, 'email': email, 'password': password,
          'address': address, 'tel': tel, 'mType': mType, 'loginMethod': 'SYSTEM'
        },
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            return data['success'] == true;
          } catch (e) {
            return true;
          }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ========== 錢包相關 ==========
  static Future<double> getWalletBalance(String memberId) async {
    try {
      final response = await http.post(
        Uri.parse(DatabaseConfig.getWalletUrl()),
        body: {'mId': memberId},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return double.tryParse(data['balance'].toString()) ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint("Balance error: $e");
    }
    return 0.0;
  }

  static Future<bool> buyACoin(String mId, double amount) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/buy_acoin.php';
      final response = await http.post(Uri.parse(url), body: {
        'mId': mId,
        'amount': amount.toString(),
      });
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint("Buy ACoin Error: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getACoinHistory(String mId) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_acoin_history.php';
      final response = await http.post(Uri.parse(url), body: {'mId': mId});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['history'] ?? [];
        }
      }
    } catch (e) {
      debugPrint("History Error: $e");
    }
    return [];
  }

  // ========== 課程相關 ==========
  static Future<List<dynamic>> getAllCourses() async {
    try {
      final response = await http.get(Uri.parse(DatabaseConfig.getCoursesUrl())).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['courses'] ?? [];
      }
    } catch (e) {
      debugPrint("Get courses error: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getStudentCourses(String mId) async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_my_courses.php?mId=$mId';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['courses'] ?? [];
      }
    } catch (e) {
      debugPrint("Get student courses error: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getTeacherCourses(String mId) async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_teacher_courses.php?mId=$mId';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['courses'] ?? [];
      }
    } catch (e) {
      debugPrint("Get teacher courses error: $e");
    }
    return [];
  }

  static Future<bool> createCourse(Map<String, dynamic> data) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/create_course.php';
      final response = await http.post(Uri.parse(url), body: data);
      final resData = jsonDecode(response.body);
      return resData['success'] == true;
    } catch (e) {
      debugPrint("Create course error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> enrollCourse({
    required String memberId,
    required String courseId,
    required double price,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(DatabaseConfig.enrollUrl()),
        body: {'mId': memberId, 'cId': courseId, 'amount': price.toString()},
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Server Error'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getCourseContent(String cId, String mId) async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_course_content.php?cId=$cId&mId=$mId';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Get content error: $e");
    }
    return {'success': false, 'isEnrolled': false, 'lessons': []};
  }

  static Future<Map<String, dynamic>> addLesson({
    required String cId,
    required String lName,
    required String videoUrl,
    required String duration,
  }) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/add_lesson.php';
      final response = await http.post(Uri.parse(url), body: {
        'cId': cId,
        'lName': lName,
        'video': videoUrl,
        'duration': duration,
      }).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; 
      } else {
        return {'success': false, 'message': 'HTTP Status Code: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint("API addLesson Error: $e");
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String mId,
    required String fName,
    required String nName,
    required String tel,
    required String address,
  }) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/update_profile.php';
      final response = await http.post(Uri.parse(url), body: {
        'mId': mId,
        'fName': fName,
        'nName': nName,
        'tel': tel,
        'address': address,
      });
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      debugPrint("Update Profile Error: $e");
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  static Future<bool> deleteCourse(String cId) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/delete_course.php';
      final response = await http.post(Uri.parse(url), body: {'cId': cId});
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ========== 作業相關 ==========
  static Future<List<dynamic>> getAssignments(String cId, {String? mId}) async {
    try {
      String url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_assignments.php?cId=$cId';
      if (mId != null) url += '&mId=$mId';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['assignments'] ?? [];
      }
    } catch (e) { 
      debugPrint("Get assignments error: $e"); 
    }
    return [];
  }

  static Future<bool> createAssignment({
    required String cId,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/create_assignment.php';
      final response = await http.post(Uri.parse(url), body: {
        'cId': cId,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
      });
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) { 
      return false; 
    }
  }

  static Future<bool> createAssignmentWithFile({
    required String cId,
    required String title,
    required DateTime dueDate,
    required File file,
  }) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/create_assignment.php';
      var request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['cId'] = cId;
      request.fields['title'] = title;
      request.fields['dueDate'] = dueDate.toIso8601String();
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        var json = jsonDecode(respStr);
        return json['success'] == true;
      }
    } catch (e) {
      debugPrint("Create assignment with file error: $e");
    }
    return false;
  }

  static Future<List<dynamic>> getSubmissions(String aId) async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_submissions.php?aId=$aId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['submissions'] ?? [];
      }
    } catch (e) { 
      debugPrint("Get submissions error: $e"); 
    }
    return [];
  }

  static Future<bool> submitAssignment(String aId, String mId, File file) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/submit_assignment.php';
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['aId'] = aId;
      request.fields['mId'] = mId;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        var json = jsonDecode(respStr);
        return json['success'] == true;
      }
    } catch (e) { 
      debugPrint("Submit assignment error: $e"); 
    }
    return false;
  }

  static Future<bool> updateAssignmentGrade({
    required String subId,
    required String grade,
    required String feedback,
  }) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/update_assignment_grade.php';
      final response = await http.post(Uri.parse(url), body: {
        'subId': subId,
        'grade': grade,
        'feedback': feedback,
      });
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint("Update Grade Error: $e");
      return false;
    }
  }

  // ========== 管理員功能 ==========
  static Future<List<dynamic>> getAllUsersForAdmin() async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_all_users_admin.php';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['users'] ?? [];
      }
    } catch (e) { 
      debugPrint("Get users error: $e"); 
    }
    return [];
  }

  static Future<bool> updateUserByAdmin(Map<String, dynamic> userData) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/update_user_admin.php';
      final response = await http.post(Uri.parse(url), body: {
        'mId': userData['mId'].toString(),
        'fName': userData['fName'].toString(),
        'nName': userData['nName'].toString(),
        'mType': userData['mType'].toString(),
        'email': userData['email'].toString(),
        'tel': userData['tel'].toString(),
        'address': userData['address'].toString(),
      });
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) { 
      return false; 
    }
  }

  // ========== 訊息 (Message) 相關 ==========
  static Future<List<CourseMessage>> getCourseMessages(String cId) async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_course_messages.php?cId=$cId';
      debugPrint('🔍 Fetching messages from: $url');
      
      final res = await http.get(Uri.parse(url));
      debugPrint('📥 Response status: ${res.statusCode}');
      debugPrint('📥 Response body: ${res.body}');
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final messages = data['messages'] as List? ?? [];
          debugPrint('📨 Messages count: ${messages.length}');
          return messages.map((j) => CourseMessage.fromJson(j)).toList();
        }
      }
    } catch (e) { 
      debugPrint("Get Messages Error: $e"); 
    }
    return [];
  }

  static Future<bool> addCourseMessage(String cId, String mId, String content) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/add_course_message.php';
      debugPrint('📤 Adding message: cId=$cId, mId=$mId, content=$content');
      
      final res = await http.post(
        Uri.parse(url),
        body: {'cId': cId, 'mId': mId, 'content': content}
      );
      
      debugPrint('📥 Response: ${res.body}');
      final data = jsonDecode(res.body);
      return data['success'] == true;
    } catch (e) { 
      debugPrint("Add message error: $e");
      return false; 
    }
  }

  // ========== 刪除功能 ==========
  static Future<bool> deleteItem(String apiName, Map<String, String> body) async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/$apiName';
      debugPrint('🗑️ Deleting with: $url, body: $body');
      
      final res = await http.post(Uri.parse(url), body: body);
      debugPrint('📥 Delete response: ${res.body}');
      
      final data = jsonDecode(res.body);
      return data['success'] == true;
    } catch (e) { 
      debugPrint("Delete error: $e");
      return false; 
    }
  }

  static Future<bool> deleteLesson(String lId) async {
    return deleteItem('delete_lesson.php', {'lId': lId});
  }

  static Future<bool> deleteFile(String fileId) async {
    return deleteItem('delete_file.php', {'id': fileId});
  }

  static Future<bool> deleteAssignment(String aId) async {
    return deleteItem('delete_assignment.php', {'aId': aId});
  }

  static Future<bool> deleteMessage(String msgId) async {
    return deleteItem('delete_message.php', {'msgId': msgId});
  }

  // ========== 修改密碼 ==========
  static Future<Map<String, dynamic>> changePassword({
    required String mId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      const url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/change_password.php';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'mId': mId,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint("Change Password Error: $e");
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // ========== 診斷工具 ==========
  static Future<Map<String, dynamic>> testAllUrls() async {
    try {
      final response = await http.get(Uri.parse(DatabaseConfig.baseUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return {'success': true, 'workingBaseUrl': DatabaseConfig.baseUrl, 'data': 'OK'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
    return {'success': false, 'message': 'Connection failed'};
  }
// ========== 社群動態 (Feed) 相關 ==========
  static Future<List<dynamic>> getFeedPosts() async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/get_feed_posts.php';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['posts'] ?? [];
        }
      }
    } catch (e) {
      debugPrint("Get feed error: $e");
    }
    return [];
  }

  static Future<bool> createFeedPost({
    required String mId,
    required String content,
    File? image,
  }) async {
    try {
      final url = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/create_post.php';
      var request = http.MultipartRequest('POST', Uri.parse(url));
      
      request.fields['mId'] = mId;
      request.fields['content'] = content;
      
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        var json = jsonDecode(respStr);
        return json['success'] == true;
      }
    } catch (e) {
      debugPrint("Create post error: $e");
    }
    return false;
  }
}
