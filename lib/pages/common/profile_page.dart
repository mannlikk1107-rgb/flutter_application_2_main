// 路徑: lib/pages/common/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fNameController;
  late TextEditingController _nNameController;
  late TextEditingController _telController;
  late TextEditingController _addressController;

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  bool _isObscureCurrent = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;
  bool _isEditMode = false;
  bool _isPasswordExpanded = false;
  bool _isUpdatingProfile = false;
  bool _isChangingPassword = false;

  late AnimationController _passwordAnimController;
  late Animation<double> _passwordAnimation;

  @override
  void initState() {
    super.initState();
    final u = Provider.of<UserProvider>(context, listen: false);
    _fNameController   = TextEditingController(text: u.fName);
    _nNameController   = TextEditingController(text: u.nName);
    _telController     = TextEditingController(text: u.tel);
    _addressController = TextEditingController(text: u.address);
    _passwordAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _passwordAnimation = CurvedAnimation(parent: _passwordAnimController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fNameController.dispose(); _nNameController.dispose();
    _telController.dispose(); _addressController.dispose();
    _currentPasswordController.dispose(); _newPasswordController.dispose();
    _confirmNewPasswordController.dispose(); _passwordAnimController.dispose();
    super.dispose();
  }

  void _togglePasswordSection() {
    setState(() => _isPasswordExpanded = !_isPasswordExpanded);
    _isPasswordExpanded ? _passwordAnimController.forward() : _passwordAnimController.reverse();
    if (!_isPasswordExpanded) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();
    }
  }

  void _enterEditMode() => setState(() => _isEditMode = true);

  void _cancelEditMode() {
    final u = Provider.of<UserProvider>(context, listen: false);
    _fNameController.text = u.fName; _nNameController.text = u.nName;
    _telController.text = u.tel; _addressController.text = u.address;
    setState(() => _isEditMode = false);
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUpdatingProfile = true);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final u    = Provider.of<UserProvider>(context, listen: false);
    final result = await ApiService.updateProfile(
      mId: u.mId, fName: _fNameController.text,
      nName: _nNameController.text, tel: _telController.text, address: _addressController.text,
    );
    if (mounted) {
      setState(() { _isUpdatingProfile = false; if (result['success'] == true) _isEditMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true ? lang.t('profile_updated') : (result['message'] ?? lang.t('update_failed'))),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ));
      if (result['success'] == true) await u.updateUserProfile(result['user']);
    }
  }

  Future<void> _changePassword() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty || _confirmNewPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('fill_all_password_fields')))); return;
    }
    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('password_mismatch')))); return;
    }
    setState(() => _isChangingPassword = true);
    final u = Provider.of<UserProvider>(context, listen: false);
    final result = await ApiService.changePassword(mId: u.mId, currentPassword: _currentPasswordController.text, newPassword: _newPasswordController.text);
    if (mounted) {
      setState(() => _isChangingPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true ? lang.t('password_changed') : (result['message'] ?? lang.t('update_failed'))),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ));
      if (result['success'] == true) _togglePasswordSection();
    }
  }

  Future<void> _logout() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('logout_confirm_title')),
        content: Text(lang.t('logout_confirm_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(lang.t('logout')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await Provider.of<UserProvider>(context, listen: false).logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang         = Provider.of<LanguageProvider>(context);
    final u            = Provider.of<UserProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(lang.t('profile')),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => lang.toggleLanguage(),
              child: Text(
                lang.isEnglish ? '中文' : 'EN',
                style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Column(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: primaryColor.withOpacity(0.12),
                  child: Text(
                    u.fName.isNotEmpty ? u.fName[0].toUpperCase() : 'U',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 14),
                Text("${u.fName} ${u.nName}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(u.email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: Text('ID: ${u.mId}', style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
            const SizedBox(height: 28),

            // Personal Info
            _SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(Icons.person, color: primaryColor, size: 20), const SizedBox(width: 8),
                  Text(lang.t('personal_info'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                ]),
                if (!_isEditMode)
                  TextButton.icon(onPressed: _enterEditMode, icon: const Icon(Icons.edit, size: 16), label: Text(lang.t('edit')),
                      style: TextButton.styleFrom(foregroundColor: primaryColor))
                else
                  TextButton.icon(onPressed: _cancelEditMode, icon: const Icon(Icons.close, size: 16), label: Text(lang.t('cancel')),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[600])),
              ]),
              if (!_isEditMode) ...[
                const SizedBox(height: 12),
                _InfoRow(label: lang.t('full_name'), value: u.fName),
                _InfoRow(label: lang.t('nickname'),  value: u.nName),
                _InfoRow(label: lang.t('phone'),     value: u.tel),
                _InfoRow(label: lang.t('address'),   value: u.address),
              ],
              if (_isEditMode) ...[
                const SizedBox(height: 16),
                Form(key: _formKey, child: Column(children: [
                  _buildTF(controller: _fNameController, label: lang.t('full_name'), icon: Icons.badge_outlined,
                      validator: (v) => v!.isEmpty ? lang.t('field_required') : null),
                  const SizedBox(height: 14),
                  _buildTF(controller: _nNameController, label: lang.t('nickname'), icon: Icons.face_outlined,
                      validator: (v) => v!.isEmpty ? lang.t('field_required') : null),
                  const SizedBox(height: 14),
                  _buildTF(controller: _telController, label: lang.t('phone'), icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? lang.t('field_required') : null),
                  const SizedBox(height: 14),
                  _buildTF(controller: _addressController, label: lang.t('address'), icon: Icons.home_outlined,
                      maxLines: 2, validator: (v) => v!.isEmpty ? lang.t('field_required') : null),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _isUpdatingProfile ? null : _updateProfile,
                    icon: _isUpdatingProfile
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isUpdatingProfile ? lang.t('saving') : lang.t('save_changes')),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
                ])),
              ],
            ])),
            const SizedBox(height: 16),

            // Change Password
            _SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: _togglePasswordSection,
                borderRadius: BorderRadius.circular(8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Icon(Icons.lock_outline, color: Colors.orange[700], size: 20), const SizedBox(width: 8),
                    Text(lang.t('change_password'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                  ]),
                  AnimatedRotation(turns: _isPasswordExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 300),
                      child: Icon(Icons.keyboard_arrow_down, color: Colors.orange[700])),
                ]),
              ),
              SizeTransition(
                sizeFactor: _passwordAnimation,
                child: Column(children: [
                  const SizedBox(height: 16),
                  _buildPWField(controller: _currentPasswordController, label: lang.t('current_password'),
                      isObscure: _isObscureCurrent, onToggle: () => setState(() => _isObscureCurrent = !_isObscureCurrent)),
                  const SizedBox(height: 14),
                  _buildPWField(controller: _newPasswordController, label: lang.t('new_password'),
                      isObscure: _isObscureNew, onToggle: () => setState(() => _isObscureNew = !_isObscureNew)),
                  const SizedBox(height: 14),
                  _buildPWField(controller: _confirmNewPasswordController, label: lang.t('confirm_new_password'),
                      isObscure: _isObscureConfirm, onToggle: () => setState(() => _isObscureConfirm = !_isObscureConfirm)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _isChangingPassword ? null : _changePassword,
                    icon: _isChangingPassword
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock_reset),
                    label: Text(_isChangingPassword ? lang.t('changing') : lang.t('confirm_change_password')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
                ]),
              ),
            ])),
            const SizedBox(height: 16),

            // Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: Text(lang.t('logout')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTF({required TextEditingController controller, required String label, required IconData icon,
      String? Function(String?)? validator, TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, maxLines: maxLines, validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12)),
    );
  }

  Widget _buildPWField({required TextEditingController controller, required String label,
      required bool isObscure, required VoidCallback onToggle}) {
    return TextField(
      controller: controller, obscureText: isObscure,
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.lock_outline, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          suffixIcon: IconButton(icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: onToggle)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500))),
        const SizedBox(width: 12),
        Expanded(child: Text(value.isNotEmpty ? value : '—', style: const TextStyle(fontSize: 14, color: Colors.black87))),
      ]),
    );
  }
}
