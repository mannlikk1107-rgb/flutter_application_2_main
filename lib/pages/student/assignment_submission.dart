// 路徑: lib/pages/student/assignment_submission.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';

class AssignmentSubmissionPage extends StatefulWidget {
  const AssignmentSubmissionPage({super.key});
  @override
  State<AssignmentSubmissionPage> createState() => _AssignmentSubmissionPageState();
}

class _AssignmentSubmissionPageState extends State<AssignmentSubmissionPage> {
  List<Assignment> _assignments = [];
  bool _isLoading = true;
  String? _currentMId;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final user = await LocalStorage.getUserInfo();
    _currentMId = user['mId'];
    if (_currentMId == null) { setState(() => _isLoading = false); return; }

    final cData    = await ApiService.getStudentCourses(_currentMId!);
    final myCourses = cData.map((j) => Course.fromJson(j)).toList();

    List<Assignment> allTasks = [];
    for (var c in myCourses) {
      final tData = await ApiService.getAssignments(c.id, mId: _currentMId);
      allTasks.addAll(tData.map((j) => Assignment.fromJson(j)));
    }
    allTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (mounted) setState(() { _assignments = allTasks; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(title: Text(lang.t('my_tasks'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.task_alt, size: 80, color: Colors.green[200]),
                    const SizedBox(height: 16),
                    Text(lang.t('no_pending_tasks'), style: const TextStyle(color: Colors.grey)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assignments.length,
                  itemBuilder: (ctx, i) => _buildTaskCard(_assignments[i], lang),
                ),
    );
  }

  Widget _buildTaskCard(Assignment task, LanguageProvider lang) {
    final isOverdue = DateTime.now().isAfter(task.dueDate) && !task.isSubmitted;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            if (task.isSubmitted)
              _statusBadge(lang.t('submitted'), Colors.green)
            else if (isOverdue)
              _statusBadge(lang.t('overdue'), Colors.red),
          ]),
          const SizedBox(height: 8),
          Text(task.description, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '${lang.t('due')}: ${task.dueDate.toString().split(' ')[0]}',
              style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ]),
          if (task.grade != null) ...[
            const SizedBox(height: 8),
            Text('${lang.t('grade')}: ${task.grade}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(task.isSubmitted ? lang.t('reupload_file') : lang.t('upload_solution')),
              style: ElevatedButton.styleFrom(
                backgroundColor: task.isSubmitted ? Colors.white : const Color(0xFF6366F1),
                foregroundColor: task.isSubmitted ? const Color(0xFF6366F1) : Colors.white,
                side: task.isSubmitted ? const BorderSide(color: Color(0xFF6366F1)) : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _uploadFile(task, lang),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Future<void> _uploadFile(Assignment task, LanguageProvider lang) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      final success = await ApiService.submitAssignment(task.id, _currentMId!, File(result.files.single.path!));
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? lang.t('submitted_successfully') : lang.t('upload_failed')),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
        if (success) _loadData();
      }
    }
  }
}
