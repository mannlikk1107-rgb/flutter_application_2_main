import 'dart:convert';          // ← 新增此行
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/database.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';

import 'register_page.dart';
import '../teacher/teacher_home.dart';
import '../student/student_home.dart';
import '../../admin/admin_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await LocalStorage.getSavedCredentials();
    if (saved != null && mounted) {
      setState(() {
        _usernameCtrl.text = saved['username'] ?? '';
        _passwordCtrl.text = saved['password'] ?? '';
        _rememberMe = true;
      });
      _login();
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.login(
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );

      if (res['success'] == true) {
        await LocalStorage.saveUserInfo(res);
        if (_rememberMe) {
          await LocalStorage.saveCredentials(
            username: _usernameCtrl.text,
            password: _passwordCtrl.text,
          );
        } else {
          await LocalStorage.clearCredentials();
        }
        if (!mounted) return;
        await Provider.of<UserProvider>(context, listen: false).loadUser();
        if (!mounted) return;

        final role = res['mType'];
        if (role == 'ADMIN') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
        } else if (role == 'TEACHER') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherHomePage()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentHomePage()));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Forgot Password — 三步驟
  // Step 0: 輸入 email → 呼叫 API 確認用戶存在
  // Step 1: 輸入重置碼（模擬，固定是 "reset"）
  // Step 2: 輸入新密碼兩次 → 呼叫 API 更新
  // ═══════════════════════════════════════════════════════════════
  void _showForgotPasswordSheet() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    int step = 0;

    final emailCtrl    = TextEditingController();
    final codeCtrl     = TextEditingController();
    final newPassCtrl  = TextEditingController();
    final confPassCtrl = TextEditingController();

    bool obscureNew  = true;
    bool obscureConf = true;
    bool isLoading   = false;

    String? emailError;
    String? codeError;
    String? newPassError;
    String? confPassError;

    final baseUrl = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {

          // ── inline 錯誤輸入框 ────────────────────────────────────
          Widget buildField({
            required TextEditingController controller,
            required String label,
            required String hint,
            required IconData icon,
            String? errorText,
            bool isPassword = false,
            bool obscure = false,
            VoidCallback? onToggle,
            TextInputType keyboardType = TextInputType.text,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: errorText != null ? Colors.red.shade400 : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: errorText != null
                            ? Colors.red.withOpacity(0.08)
                            : Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    obscureText: isPassword && obscure,
                    keyboardType: keyboardType,
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: hint,
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(
                        icon,
                        color: errorText != null ? Colors.red.shade400 : const Color(0xFF6366F1),
                      ),
                      suffixIcon: isPassword
                          ? IconButton(
                              icon: Icon(
                                obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: onToggle,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: errorText != null
                      ? Padding(
                          padding: const EdgeInsets.only(left: 12, top: 5, bottom: 2),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, size: 14, color: Colors.red.shade400),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  errorText,
                                  style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }

          Widget buildButton(String label, VoidCallback? onPressed) => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(label,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              );

          Widget buildBack(int target) => TextButton.icon(
                onPressed: () => setSheet(() {
                  step = target;
                  emailError = codeError = newPassError = confPassError = null;
                }),
                icon: const Icon(Icons.arrow_back_ios_new, size: 13, color: Colors.grey),
                label: Text(lang.t('back'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              );

          Widget buildStepBar() => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = i == step;
                  final done   = i < step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: done || active ? const Color(0xFF6366F1) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              );

          // API 錯誤訊息對照
          String resolveError(String msg) {
            switch (msg) {
              case 'email_not_found': return lang.t('email_not_found');
              case 'code_incorrect':  return lang.t('code_incorrect');
              default:                return msg;
            }
          }

          // ════════════════════════════════════════════════════════
          // Step 0 — 輸入 email，API 確認用戶是否存在
          // ════════════════════════════════════════════════════════
          Widget stepEmail() => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(lang.t('forgot_password'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(lang.t('forgot_password_hint'),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  buildField(
                    controller: emailCtrl,
                    label: lang.t('email'),
                    hint: lang.t('enter_your_email'),
                    icon: Icons.email_outlined,
                    errorText: emailError,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  buildButton(lang.t('send_reset_code'), () async {
                    final email = emailCtrl.text.trim();

                    if (email.isEmpty) {
                      setSheet(() => emailError = lang.t('email_required'));
                      return;
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
                      setSheet(() => emailError = lang.t('email_invalid'));
                      return;
                    }

                    setSheet(() { isLoading = true; emailError = null; });

                    try {
                      final res = await http.post(
                        Uri.parse('$baseUrl/check_reset_email.php'),
                        body: {'email': email},
                      );
                      final data = jsonDecode(res.body);

                      if (data['success'] == true) {
                        setSheet(() { isLoading = false; step = 1; });
                      } else {
                        setSheet(() {
                          isLoading  = false;
                          emailError = resolveError(data['message'] ?? 'error');
                        });
                      }
                    } catch (e) {
                      setSheet(() {
                        isLoading  = false;
                        emailError = lang.t('network_error_retry');
                      });
                    }
                  }),
                ],
              );

          // ════════════════════════════════════════════════════════
          // Step 1 — 輸入重置碼（模擬固定是 "reset"）
          // ════════════════════════════════════════════════════════
          Widget stepCode() => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(lang.t('enter_reset_code'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(lang.t('enter_reset_code_hint'),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  buildField(
                    controller: codeCtrl,
                    label: lang.t('reset_code'),
                    // placeholder 提示用戶答案
                    hint: 'reset',
                    icon: Icons.vpn_key_outlined,
                    errorText: codeError,
                  ),
                  const SizedBox(height: 24),
                  buildButton(lang.t('verify_code'), () {
                    final code = codeCtrl.text.trim();

                    if (code.isEmpty) {
                      setSheet(() => codeError = lang.t('code_required'));
                      return;
                    }
                    // 純客戶端比對，固定字串 "reset"
                    if (code != 'reset') {
                      setSheet(() => codeError = lang.t('code_incorrect'));
                      return;
                    }

                    setSheet(() { codeError = null; step = 2; });
                  }),
                  const SizedBox(height: 8),
                  buildBack(0),
                ],
              );

          // ════════════════════════════════════════════════════════
          // Step 2 — 新密碼，呼叫 API 更新資料庫
          // ════════════════════════════════════════════════════════
          Widget stepNewPassword() => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(lang.t('set_new_password'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(lang.t('set_new_password_hint'),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  buildField(
                    controller: newPassCtrl,
                    label: lang.t('new_password'),
                    hint: '',
                    icon: Icons.lock_outline,
                    errorText: newPassError,
                    isPassword: true,
                    obscure: obscureNew,
                    onToggle: () => setSheet(() => obscureNew = !obscureNew),
                  ),
                  const SizedBox(height: 16),
                  buildField(
                    controller: confPassCtrl,
                    label: lang.t('confirm_new_password'),
                    hint: '',
                    icon: Icons.lock_outline,
                    errorText: confPassError,
                    isPassword: true,
                    obscure: obscureConf,
                    onToggle: () => setSheet(() => obscureConf = !obscureConf),
                  ),
                  const SizedBox(height: 24),
                  buildButton(lang.t('reset_password'), () async {
                    final pw1 = newPassCtrl.text;
                    final pw2 = confPassCtrl.text;
                    bool hasError = false;

                    if (pw1.isEmpty) {
                      newPassError = lang.t('password_required');
                      hasError = true;
                    } else if (pw1.length < 6) {
                      newPassError = lang.t('password_too_short');
                      hasError = true;
                    } else {
                      newPassError = null;
                    }

                    if (pw2.isEmpty) {
                      confPassError = lang.t('confirm_password_required');
                      hasError = true;
                    } else if (pw1.isNotEmpty && pw1 != pw2) {
                      confPassError = lang.t('password_mismatch');
                      hasError = true;
                    } else {
                      confPassError = null;
                    }

                    if (hasError) { setSheet(() {}); return; }

                    setSheet(() => isLoading = true);

                    try {
                      final res = await http.post(
                        Uri.parse('$baseUrl/reset_password.php'),
                        body: {
                          'email':        emailCtrl.text.trim(),
                          'reset_code':   codeCtrl.text.trim(),
                          'new_password': pw1,
                        },
                      );
                      final data = jsonDecode(res.body);

                      if (data['success'] == true) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang.t('password_reset_ok')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        setSheet(() {
                          isLoading     = false;
                          confPassError = resolveError(data['message'] ?? 'error');
                        });
                      }
                    } catch (e) {
                      setSheet(() {
                        isLoading     = false;
                        confPassError = lang.t('network_error_retry');
                      });
                    }
                  }),
                  const SizedBox(height: 8),
                  buildBack(1),
                ],
              );

          // ── 主體 ───────────────────────────────────────────────
          return Container(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 0,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                buildStepBar(),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(step),
                    child: step == 0
                        ? stepEmail()
                        : step == 1
                            ? stepCode()
                            : stepNewPassword(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: size.height * 0.4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80)),
                  ),
                ),
                Positioned(
                  top: 60, right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.language, color: Colors.white),
                    onPressed: () => lang.toggleLanguage(),
                  ),
                ),
                SizedBox(
                  height: size.height * 0.4,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_rounded, size: 60, color: Colors.white),
                        const SizedBox(height: 10),
                        Text(lang.t('app_title'),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text("Learn without limits",
                            style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _usernameCtrl,
                      label: lang.t('email'),
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordCtrl,
                      label: lang.t('password'),
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isObscure: _isObscure,
                      onTogglePass: () => setState(() => _isObscure = !_isObscure),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(lang.t('login'),
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22, height: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              activeColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(lang.t('remember_me'),
                              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCircleShortcut(
                          icon: Icons.person_add_rounded,
                          label: lang.t('register'),
                          onTap: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                        ),
                        const SizedBox(width: 40),
                        _buildCircleShortcut(
                          icon: Icons.lock_reset_rounded,
                          label: lang.t('forgot_password'),
                          onTap: _showForgotPasswordSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleShortcut({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onTogglePass,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && isObscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      isObscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey),
                  onPressed: onTogglePass)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
    );
  }
}