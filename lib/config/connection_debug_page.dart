import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/database.dart';

class ConnectionDebugPage extends StatefulWidget {
  const ConnectionDebugPage({super.key});

  @override
  State<ConnectionDebugPage> createState() => _ConnectionDebugPageState();
}

class _ConnectionDebugPageState extends State<ConnectionDebugPage> {
  String _debugInfo = '正在診斷連接問題...';
  bool _isTesting = true;
  final List<String> _testSteps = []; // 改為 final
  String _currentWorkingUrl = '';

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  void _addTestStep(String step, bool isSuccess) {
    setState(() {
      _testSteps.add('${isSuccess ? '✅' : '❌'} $step');
    });
  }

  void _runDiagnostics() async {
    _testSteps.clear();
    setState(() {
      _isTesting = true;
      _debugInfo = '開始網絡診斷...\n';
      _currentWorkingUrl = '';
    });

    final StringBuffer sb = StringBuffer();
    
    try {
      // 步驟 1: 顯示所有可能的 URL
      _addTestStep('檢查配置的 URL', true);
      sb.writeln('📍 配置的基礎 URL: ${DatabaseConfig.baseUrl}');
      sb.writeln('🔗 登入 URL: ${DatabaseConfig.getLoginUrl()}');
      sb.writeln('🧪 測試 URL: ${DatabaseConfig.getTestUrl()}');
      sb.writeln('---');
      sb.writeln('🔄 所有測試 URL:');
      for (final url in DatabaseConfig.getAlternativeUrls()) {
        sb.writeln('   • $url');
      }
      sb.writeln('---');

      // 步驟 2: 測試 URL 連接
      _addTestStep('測試 URL 連接', false);
      sb.writeln('🧪 尋找可用的伺服器 URL...');
      
      final testResult = await ApiService.testAllUrls();
      
      if (testResult['success'] == true) {
        _testSteps[_testSteps.length - 1] = '✅ 測試 URL 連接';
        _currentWorkingUrl = testResult['workingBaseUrl'];
        sb.writeln('✅ 找到可用的 URL: $_currentWorkingUrl');
        sb.writeln('📊 測試響應: ${testResult['data']}');
      } else {
        _testSteps[_testSteps.length - 1] = '❌ 測試 URL 連接';
        sb.writeln('❌ 所有 URL 測試失敗');
        sb.writeln('💥 錯誤: ${testResult['message']}');
      }
      sb.writeln('---');

      // 步驟 3: 測試登入 API（只有在找到可用 URL 時）
      if (testResult['success'] == true) {
        _addTestStep('測試登入 API', false);
        sb.writeln('🔐 測試登入功能...');
        
        try {
          final loginResult = await ApiService.adminLogin(
            username: 'admin',
            password: 'adminedu',
          );
          
          if (loginResult['success'] == true) {
            _testSteps[_testSteps.length - 1] = '✅ 測試登入 API';
            sb.writeln('✅ 登入 API 正常');
            sb.writeln('👤 用戶: ${loginResult['user']}');
          } else {
            _testSteps[_testSteps.length - 1] = '⚠️ 登入 API 返回錯誤';
            sb.writeln('⚠️ 登入失敗: ${loginResult['message']}');
            sb.writeln('ℹ️  這可能是正常的，如果用戶名/密碼不正確');
          }
        } catch (e) {
          _testSteps[_testSteps.length - 1] = '❌ 測試登入 API';
          sb.writeln('❌ 登入 API 錯誤: $e');
        }
      }

    } catch (e) {
      sb.writeln('💥 診斷過程出錯: $e');
    } finally {
      sb.writeln('---');
      sb.writeln('🔚 診斷完成');
      
      setState(() {
        _debugInfo = sb.toString();
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('連接診斷 - 新路徑'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isTesting ? null : _runDiagnostics,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 當前工作 URL
              if (_currentWorkingUrl.isNotEmpty)
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '成功連接!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('可用 URL: $_currentWorkingUrl'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // 測試步驟
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '測試步驟',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._testSteps.map((step) => Text(step)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 診斷結果
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '詳細診斷',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isTesting
                          ? const Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 16),
                                Text('正在診斷...'),
                              ],
                            )
                          : SelectableText(
                              _debugInfo,
                              style: const TextStyle(
                                fontFamily: 'Monospace',
                                fontSize: 12,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isTesting ? null : _runDiagnostics,
        backgroundColor: Colors.green,
        child: const Icon(Icons.wifi_find),
      ),
    );
  }
}