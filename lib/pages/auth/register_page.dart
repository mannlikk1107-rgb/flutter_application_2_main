import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  String _fName = '';
  String _nName = '';
  String _email = '';
  String _pass = '';
  String _addr = '';
  String _tel = '';
  String _mType = 'STUDENT'; 

  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => _isLoading = true);

    try {
      // 這裡對應 ApiService.register 的具名參數
      await ApiService.register(
        fName: _fName, 
        nName: _nName, 
        email: _email, 
        password: _pass,
        address: _addr, 
        tel: _tel, 
        mType: _mType
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('success')))
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('register'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 使用 initialValue 避免 value deprecated 警告
              DropdownButtonFormField<String>(
                initialValue: _mType, 
                decoration: InputDecoration(
                  labelText: lang.t('role'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                items: [
                  DropdownMenuItem(value: 'STUDENT', child: Text(lang.t('student'))),
                  DropdownMenuItem(value: 'TEACHER', child: Text(lang.t('teacher'))),
                ],
                onChanged: (val) => setState(() => _mType = val!),
              ),
              const SizedBox(height: 16),
              
              _field(lang.t('fName'), (v)=>_fName=v!),
              _field(lang.t('nName'), (v)=>_nName=v!),
              _field(lang.t('email'), (v)=>_email=v!, isEmail: true),
              _field(lang.t('password'), (v)=>_pass=v!, isPass: true),
              _field(lang.t('tel'), (v)=>_tel=v!, isNum: true),
              _field(lang.t('address'), (v)=>_addr=v!),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text(lang.t('submit')),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, Function(String?) save, {bool isPass=false, bool isEmail=false, bool isNum=false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        obscureText: isPass,
        keyboardType: isEmail ? TextInputType.emailAddress : (isNum ? TextInputType.phone : TextInputType.text),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        onSaved: save,
      ),
    );
  }
}
