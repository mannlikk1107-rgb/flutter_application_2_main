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

  Future<void> loadUser() async {
    final userInfo = await LocalStorage.getUserInfo();
    
    if (userInfo.isNotEmpty) {
      _mId = userInfo['mId'] ?? '';
      _fName = userInfo['fName'] ?? '';
      _nName = userInfo['nName'] ?? '';
      _email = userInfo['email'] ?? '';
      _mType = userInfo['mType'] ?? '';
      _tel = userInfo['tel']?.toString() ?? '';
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

  // ✅ 新增：送禮成功後直接用回傳值更新餘額，不需要再 call API
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
    _mId = newInfo['mId']?.toString() ?? _mId;
    _fName = newInfo['fName']?.toString() ?? _fName;
    _nName = newInfo['nName']?.toString() ?? _nName;
    _email = newInfo['email']?.toString() ?? _email;
    _mType = newInfo['mType']?.toString() ?? _mType;
    _tel = newInfo['tel']?.toString() ?? _tel;
    _address = newInfo['address']?.toString() ?? _address;

    Map<String, dynamic> fullUserInfo =
        Map<String, dynamic>.from(await LocalStorage.getUserInfo());
    
    newInfo.forEach((key, value) {
      fullUserInfo[key] = value;
    });

    await LocalStorage.saveUserInfo(fullUserInfo);
    notifyListeners();
  }
}