// 修正：移除未使用的 material.dart import (如果測試中不需要 Icons 等)
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/main.dart'; // 請確保這裡的 package name 正確

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 修正：將 MyApp 改為 EduLiveApp
    await tester.pumpWidget(const EduLiveApp());

    // 驗證 App 是否能正常啟動並顯示登入按鈕
    // 注意：因為多語言載入可能需要時間，這裡做最基礎的 Widget 建構測試
    await tester.pumpAndSettle();
    
    // 這裡假設預設語言是英文，尋找 'Login' 文字
    // 如果找不到，測試會失敗，這有助於確認 App 是否崩潰
    expect(find.text('Login'), findsOneWidget);
  });
}
