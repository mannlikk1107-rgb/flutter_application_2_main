// 路徑: lib/pages/teacher/assignment_management.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';

class AssignmentManagementPage extends StatefulWidget {
  const AssignmentManagementPage({super.key});
  @override
  State<AssignmentManagementPage> createState() => _AssignmentManagementPageState();
}

class _AssignmentManagementPageState extends State<AssignmentManagementPage> {
  List<Course> _courses = [];
  List<Assignment> _assignments = [];
  String? _selectedCourseId;
  bool _isLoading = true;
  bool _isAssignmentsLoading = false;

  @override
  void initState() { super.initState(); _loadCourses(); }

  Future<void> _loadCourses() async {
    final user = await LocalStorage.getUserInfo();
    final mId  = user['mId'];
    if (mId == null || mId.isEmpty) return;
    final data = await ApiService.getTeacherCourses(mId);
    if (mounted) {
      setState(() {
        _courses = data.map((j) => Course.fromJson(j)).toList();
        _isLoading = false;
        if (_courses.isNotEmpty) { _selectedCourseId = _courses.first.id; _loadAssignments(_selectedCourseId!); }
      });
    }
  }

  Future<void> _loadAssignments(String cId) async {
    setState(() => _isAssignmentsLoading = true);
    final data = await ApiService.getAssignments(cId);
    if (mounted) setState(() {
      _assignments = data.map((j) => Assignment.fromJson(j)).toList();
      _isAssignmentsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(title: Text(lang.t('manage_assignments'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: _courses.isEmpty
                    ? Center(child: Text(lang.t('no_courses_found')))
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedCourseId,
                        decoration: InputDecoration(labelText: lang.t('select_course'), border: const OutlineInputBorder()),
                        items: _courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title))).toList(),
                        onChanged: (val) {
                          if (val != null) { setState(() => _selectedCourseId = val); _loadAssignments(val); }
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isAssignmentsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _assignments.isEmpty
                        ? Center(child: Text(lang.t('no_assignments')))
                        : ListView.builder(
                            itemCount: _assignments.length,
                            itemBuilder: (ctx, i) {
                              final task = _assignments[i];
                              return Card(
                                child: ListTile(
                                  title: Text(task.title),
                                  subtitle: Text('${lang.t('due')}: ${task.dueDate.toString().split(' ')[0]}'),
                                  onTap: () => _showSubmissions(task, lang),
                                ),
                              );
                            },
                          ),
              ),
            ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () { if (_selectedCourseId != null) _createAssignmentDialog(lang); },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _createAssignmentDialog(LanguageProvider lang) {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(lang.t('new_assignment')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: lang.t('title'))),
            TextField(controller: descCtrl,  decoration: InputDecoration(labelText: lang.t('description'))),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: dueDate,
                    firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (date != null) setDialogState(() => dueDate = date);
              },
              child: Text('${lang.t('due')}: ${dueDate.toString().split(' ')[0]}'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                Navigator.pop(context);
                await ApiService.createAssignment(
                    cId: _selectedCourseId!, title: titleCtrl.text, description: descCtrl.text, dueDate: dueDate);
                _loadAssignments(_selectedCourseId!);
              },
              child: Text(lang.t('create')),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmissions(Assignment task, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubmissionListSheet(taskId: task.id, taskTitle: task.title),
    );
  }
}

class _SubmissionListSheet extends StatefulWidget {
  final String taskId, taskTitle;
  const _SubmissionListSheet({required this.taskId, required this.taskTitle});
  @override
  State<_SubmissionListSheet> createState() => _SubmissionListSheetState();
}

class _SubmissionListSheetState extends State<_SubmissionListSheet> {
  List<AssignmentSubmission> _subs = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadSubmissions(); }

  void _loadSubmissions() async {
    final data = await ApiService.getSubmissions(widget.taskId);
    if (mounted) setState(() {
      _subs = data.map((j) => AssignmentSubmission.fromJson(j)).toList();
      _isLoading = false;
    });
  }

  Future<void> _downloadAndOpenFile(AssignmentSubmission sub) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('downloading'))));
      final directory = await getTemporaryDirectory();
      final filePath  = '${directory.path}/${sub.fileName}';
      final response  = await http.get(Uri.parse(sub.fileUrl));
      if (response.statusCode == 200) {
        await File(filePath).writeAsBytes(response.bodyBytes);
        await OpenFilex.open(filePath);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('error_opening_file'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text('${lang.t('submissions')}: ${widget.taskTitle}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Divider(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _subs.isEmpty
                  ? Center(child: Text(lang.t('no_submissions')))
                  : ListView.builder(
                      itemCount: _subs.length,
                      itemBuilder: (ctx, i) {
                        final sub = _subs[i];
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(sub.studentName),
                          subtitle: Text('${lang.t('submitted_on')}: ${sub.submitDate.toString().split(' ')[0]}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadAndOpenFile(sub),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
