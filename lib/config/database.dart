class DatabaseConfig {
  // 伺服器基礎路徑 (請確認 IP 是否變動)
  static const String baseUrl = 'http://3.25.85.107';
  static const String projectPath = '/Research/Web/TestFYP';

  // API Endpoints
  static String getLoginUrl() => '$baseUrl$projectPath/api/Login.php';
  static String getRegisterUrl() => '$baseUrl$projectPath/api/Register.php';
  
  // 業務邏輯 API (假設你將建立這些 PHP 檔案)
  static String getCoursesUrl() => '$baseUrl$projectPath/api/get_courses.php';
  static String getWalletUrl() => '$baseUrl$projectPath/api/get_wallet_balance.php';
  static String enrollUrl() => '$baseUrl$projectPath/api/enroll_course.php';
  static String uploadUrl() => '$baseUrl$projectPath/api/upload_file.php';
  
  // 測試用
  static String getTestUrl() => '$baseUrl/api_test.php'; // 如果有的話

  static List<String> getAlternativeUrls() {
    return [baseUrl, '$baseUrl$projectPath'];
  }
}
