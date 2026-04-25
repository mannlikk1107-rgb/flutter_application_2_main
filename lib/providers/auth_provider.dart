import 'package:flutter/material.dart';
import '../models/member_model.dart';
import '../services/local_storage.dart';

class AuthProvider extends ChangeNotifier {
  Member? _currentUser;
  bool get isLoggedIn => _currentUser != null;
  Member? get user => _currentUser;

  // App 啟動時檢查狀態
  Future<void> checkLoginStatus() async {
    final info = await LocalStorage.getUserInfo();
    if (info['mId'] != null && info['mId']!.isNotEmpty) {
      // 簡單還原 Member 物件
      _currentUser = Member(
        mId: info['mId']!,
        fName: info['fName']!,
        nName: info['nName']!,
        email: info['email']!,
        mType: info['mType']!,
        address: '', // LocalStorage 沒存的欄位需處理
        tel: 0,
      );
      notifyListeners(); // 通知所有監聽者刷新 UI
    }
  }

  void setUser(Member member) {
    _currentUser = member;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    LocalStorage.logout();
    notifyListeners();
  }
}
