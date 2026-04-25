import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();
  
  String _cName = '';
  String _totalLesson = '';
  String _cateId = 'Cate0001'; 
  String _langId = 'Lg0001';
  double _price = 0;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);
    
    final user = await LocalStorage.getUserInfo();
    final mId = user['mId'] ?? '';

    final success = await ApiService.createCourse({
      'cName': _cName, 
      'unitPrice': _price.toString(), 
      'totalLesson': _totalLesson,
      'cateId': _cateId, 
      'langId': _langId,
      'mId': mId, 
    });
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course Created!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create course'), backgroundColor: Colors.red));
      }
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
     final lang = Provider.of<LanguageProvider>(context);
     return Scaffold(
       appBar: AppBar(title: Text(lang.t('create_course'))),
       body: SingleChildScrollView(
         padding: const EdgeInsets.all(24),
         child: Form(
           key: _formKey,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _buildSectionTitle("Basic Info"),
               _buildTextField(
                 label: lang.t('course_name'),
                 icon: Icons.edit_outlined,
                 onSaved: (v) => _cName = v!,
               ),
               
               const SizedBox(height: 16),
               Row(
                 children: [
                   Expanded(
                     child: _buildTextField(
                       label: lang.t('unit_price'),
                       icon: Icons.attach_money,
                       isNumber: true,
                       onSaved: (v) => _price = double.tryParse(v!) ?? 0,
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: _buildTextField(
                       label: lang.t('total_lesson'),
                       icon: Icons.format_list_numbered,
                       isNumber: true,
                       onSaved: (v) => _totalLesson = v!,
                     ),
                   ),
                 ],
               ),
               
               const SizedBox(height: 32),
               _buildSectionTitle("Classification"),
               
               _buildDropdown(
                 label: 'Category',
                 value: _cateId,
                 icon: Icons.category_outlined,
                 items: const [
                   DropdownMenuItem(value: 'Cate0001', child: Text('Economics')),
                   DropdownMenuItem(value: 'Cate0002', child: Text('Science')),
                 ],
                 // 這裡我們直接更新變數，因為 initialValue 只會讀取一次
                 // 對於創建頁面來說，這樣是沒問題的
                 onChanged: (v) => _cateId = v!,
               ),
               
               const SizedBox(height: 16),
               _buildDropdown(
                 label: 'Language',
                 value: _langId,
                 icon: Icons.language,
                 items: const [
                   DropdownMenuItem(value: 'Lg0001', child: Text('English')),
                   DropdownMenuItem(value: 'Lg0002', child: Text('Traditional Chinese')),
                 ],
                 onChanged: (v) => _langId = v!,
               ),
               
               const SizedBox(height: 48),
               SizedBox(
                 width: double.infinity,
                 height: 56,
                 child: ElevatedButton(
                   onPressed: _isSubmitting ? null : _submit,
                   child: _isSubmitting 
                     ? const CircularProgressIndicator(color: Colors.white) 
                     : Text(lang.t('submit')),
                 ),
               )
             ],
           ),
         ),
       ),
     );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required Function(String?) onSaved,
    bool isNumber = false,
  }) {
    return TextFormField(
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      onSaved: onSaved,
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    // Fix: value is deprecated in newer Flutter versions for FormField
    // Use initialValue instead
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
    );
  }
}
