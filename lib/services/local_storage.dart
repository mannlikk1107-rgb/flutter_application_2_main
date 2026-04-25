import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyMId = 'mId';
  static const String _keyFName = 'fName';
  static const String _keyNName = 'nName';
  static const String _keyMType = 'mType';
  static const String _keyEmail = 'email';

  // ── Remember Me keys ──
  static const String _keySavedUsername = 'saved_username';
  static const String _keySavedPassword = 'saved_password';
  static const String _keyRememberMe = 'remember_me';

  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMId, userInfo['mId']?.toString() ?? '');
    await prefs.setString(_keyFName, userInfo['fName'] ?? '');
    await prefs.setString(_keyNName, userInfo['nName'] ?? '');
    await prefs.setString(_keyMType, userInfo['mType'] ?? 'STUDENT');
    await prefs.setString(_keyEmail, userInfo['email'] ?? '');
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  static Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'mId': prefs.getString(_keyMId) ?? '',
      'fName': prefs.getString(_keyFName) ?? '',
      'nName': prefs.getString(_keyNName) ?? '',
      'mType': prefs.getString(_keyMType) ?? 'STUDENT',
      'email': prefs.getString(_keyEmail) ?? '',
    };
  }

  /// 登出：清除全部（包含 Remember Me），避免回到 LoginPage 自動登入
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── Remember Me ─────────────────────────────────────────

  static Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedUsername, username);
    await prefs.setString(_keySavedPassword, password);
    await prefs.setBool(_keyRememberMe, true);
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_keyRememberMe) ?? false;
    if (!remember) return null;
    final username = prefs.getString(_keySavedUsername);
    final password = prefs.getString(_keySavedPassword);
    if (username == null || password == null) return null;
    return {'username': username, 'password': password};
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedUsername);
    await prefs.remove(_keySavedPassword);
    await prefs.setBool(_keyRememberMe, false);
  }
}