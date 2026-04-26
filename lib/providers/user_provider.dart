import 'package:flutter/material.dart';
import '../services/local_storage.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  String _mId = '';
  String _fName = '';
  String _nName = '';
  String _email = '';
  String _mType = '';
  String _tel = '';
  String _address = '';
  double _balance = 0.0;
  bool _isLoggedIn = false;

  // Getters
  String get mId => _mId;
  String get fName => _fName;
  String get nName => _nName;
  String get email => _email;
  String get mType => _mType;
  String get tel => _tel;
  String get address => _address;
  double get balance => _balance;
  bool get isLoggedIn => _isLoggedIn;

  UserProvider() {
    loadUser();
  }

  // ✅ 登入成功後直接呼叫，將 API 回傳的使用者資料存入 Provider 和 LocalStorage
  Future<void> setUser(Map<String, dynamic> user) async {
    _mId = user['mId']?.toString() ?? '';
    _fName = user['fName']?.toString() ?? '';
    _nName = user['nName']?.toString() ?? '';
    _email = user['email']?.toString() ?? '';
    _mType = user['mType']?.toString() ?? 'STUDENT';
    _tel = user['tel']?.toString() ?? '';
    _address = user['address']?.toString() ?? '';
    _isLoggedIn = _mId.isNotEmpty;
    notifyListeners();

    // 儲存到本地，以便下次 App 啟動自動載入
    await LocalStorage.saveUserInfo({
      'mId': _mId,
      'fName': _fName,
      'nName': _nName,
      'email': _email,
      'mType': _mType,
      'tel': _tel,
      'address': _address,
    });

    if (_mId.isNotEmpty) await refreshBalance();
  }

  Future<void> loadUser() async {
    final userInfo = await LocalStorage.getUserInfo();
    
    if (userInfo.isNotEmpty && (userInfo['mId']?.isNotEmpty ?? false)) {
      _mId = userInfo['mId'] ?? '';
      _fName = userInfo['fName'] ?? '';
      _nName = userInfo['nName'] ?? '';
      _email = userInfo['email'] ?? '';
      _mType = userInfo['mType'] ?? '';
      _tel = userInfo['tel'] ?? '';
      _address = userInfo['address'] ?? '';
      _isLoggedIn = true;
      
      if (_mId.isNotEmpty) await refreshBalance();
    } else {
      _isLoggedIn = false;
    }
    
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    if (_mId.isNotEmpty) {
      _balance = await ApiService.getWalletBalance(_mId);
      notifyListeners();
    }
  }

  // 送禮成功後直接用回傳值更新餘額，不需要再 call API
  void updateBalance(double newBalance) {
    _balance = newBalance;
    notifyListeners();
  }

  Future<void> logout() async {
    await LocalStorage.logout();
    
    _mId = '';
    _fName = '';
    _nName = '';
    _email = '';
    _mType = '';
    _tel = '';
    _address = '';
    _balance = 0.0;
    _isLoggedIn = false;
    
    notifyListeners();
  }

  Future<void> updateUserProfile(Map<String, dynamic> newInfo) async {
    // 更新 Provider 欄位（使用 toString 確保型別正確）
    if (newInfo.containsKey('mId')) _mId = newInfo['mId']?.toString() ?? _mId;
    if (newInfo.containsKey('fName')) _fName = newInfo['fName']?.toString() ?? _fName;
    if (newInfo.containsKey('nName')) _nName = newInfo['nName']?.toString() ?? _nName;
    if (newInfo.containsKey('email')) _email = newInfo['email']?.toString() ?? _email;
    if (newInfo.containsKey('mType')) _mType = newInfo['mType']?.toString() ?? _mType;
    if (newInfo.containsKey('tel')) _tel = newInfo['tel']?.toString() ?? _tel;
    if (newInfo.containsKey('address')) _address = newInfo['address']?.toString() ?? _address;

    // 將現有資訊與更新資訊合併後存入本地
    Map<String, dynamic> fullUserInfo = {
      'mId': _mId,
      'fName': _fName,
      'nName': _nName,
      'email': _email,
      'mType': _mType,
      'tel': _tel,
      'address': _address,
    };
    await LocalStorage.saveUserInfo(fullUserInfo);
    notifyListeners();
  }
}