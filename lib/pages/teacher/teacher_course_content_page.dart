// 路徑: lib/pages/teacher/teacher_course_content_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/course_model.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/file_service.dart';
import '../../services/local_storage.dart';
import '../common/video_player_page.dart';

class TeacherCourseContentPage extends StatefulWidget {
  final Course course;
  const TeacherCourseContentPage({super.key, required this.course});
  @override
  State<TeacherCourseContentPage> createState() => _TeacherCourseContentPageState();
}

class _TeacherCourseContentPageState extends State<TeacherCourseContentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FileService _fileService = FileService();

  List _lessons = [];
  List<Map<String, dynamic>> _materials = [];
  List<Assignment> _assignments = [];
  List<CourseMessage> _messages = [];
  bool _isLoading = true;

  void _showLoading() =>
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  void _hideLoading() { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _loadData();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = await LocalStorage.getUserInfo();
    try {
      final lData = await ApiService.getCourseContent(widget.course.id, user['mId'] ?? '');
      final fData = await _fileService.getFiles(courseId: widget.course.id);
      final aData = await ApiService.getAssignments(widget.course.id);
      final mData = await ApiService.getCourseMessages(widget.course.id);
      if (mounted) {
        setState(() {
          _lessons = lData['lessons'] ?? [];
          if (fData['success'] == true) _materials = List<Map<String, dynamic>>.from(fData['files'] ?? []);
          _assignments = aData.map((j) => Assignment.fromJson(j)).toList();
          _messages = mData;
          _isLoading = false;
        });
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  void _confirmDelete({required String title, required String content, required Future<bool> Function() onDelete}) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx); _showLoading();
              bool success = await onDelete();
              _hideLoading();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.t('deleted_successfully')), backgroundColor: Colors.green));
                _loadData();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.t('failed_to_delete')), backgroundColor: Colors.red));
              }
            },
            child: Text(lang.t('delete')),
          ),
        ],
      ),
    );
  }

  void _createAssignmentDialog() {
    final lang      = Provider.of<LanguageProvider>(context, listen: false);
    final titleCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    File? selectedFile;
    bool isDialogUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(lang.t('new_assignment')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: lang.t('title'))),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: Icon(selectedFile == null ? Icons.attach_file : Icons.check_circle,
                  color: selectedFile == null ? Colors.blue : Colors.green),
              label: Text(selectedFile == null ? lang.t('select_file') : lang.t('file_selected')),
              onPressed: isDialogUploading ? null : () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.any);
                if (result != null && result.files.single.path != null) {
                  setDialogState(() => selectedFile = File(result.files.single.path!));
                }
              },
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: dueDate,
                    firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (date != null) setDialogState(() => dueDate = date);
              },
              child: Text('${lang.t('due')}: ${dueDate.toString().split(' ')[0]}'),
            ),
            if (isDialogUploading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          ]),
          actions: [
            TextButton(onPressed: isDialogUploading ? null : () => Navigator.pop(context), child: Text(lang.t('cancel'))),
            ElevatedButton(
              onPressed: (isDialogUploading || titleCtrl.text.isEmpty || selectedFile == null) ? null : () async {
                setDialogState(() => isDialogUploading = true);
                bool success = await ApiService.createAssignmentWithFile(
                    cId: widget.course.id, title: titleCtrl.text, dueDate: dueDate, file: selectedFile!);
                setDialogState(() => isDialogUploading = false);
                Navigator.pop(context);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lang.t('assignment_created_ok')), backgroundColor: Colors.green));
                  _loadData();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lang.t('failed_to_delete')), backgroundColor: Colors.red));
                }
              },
              child: isDialogUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(lang.t('create')),
            ),
          ],
        ),
      ),
    );
  }

  void _addLessonDialog() {
    final lang     = Provider.of<LanguageProvider>(context, listen: false);
    final nameCtrl = TextEditingController();
    File? selectedVideo;
    bool isDialogUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(lang.t('add_new_lesson')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: lang.t('lesson_name'))),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: Icon(selectedVideo == null ? Icons.video_library : Icons.check_circle,
                  color: selectedVideo == null ? Colors.blue : Colors.green),
              label: Text(selectedVideo == null ? lang.t('select_video') : '${lang.isEnglish ? 'Selected' : '已選擇'} (${path.basename(selectedVideo!.path)})'),
              onPressed: isDialogUploading ? null : () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.video);
                if (result != null && result.files.single.path != null) {
                  setDialogState(() => selectedVideo = File(result.files.single.path!));
                }
              },
            ),
            if (isDialogUploading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          ]),
          actions: [
            TextButton(onPressed: isDialogUploading ? null : () => Navigator.pop(context), child: Text(lang.t('cancel'))),
            ElevatedButton(
              onPressed: (isDialogUploading || selectedVideo == null || nameCtrl.text.isEmpty) ? null : () async {
                setDialogState(() => isDialogUploading = true);
                final user = await LocalStorage.getUserInfo();
                final res  = await _fileService.uploadFile(selectedVideo!, path.basename(selectedVideo!.path),
                    userId: user['mId'] ?? 'unknown', courseIds: [widget.course.id]);
                if (mounted) {
                  if (res['success'] == true) {
                    final addResult = await ApiService.addLesson(
                        cId: widget.course.id, lName: nameCtrl.text, videoUrl: res['file_url'], duration: '0');
                    if (addResult['success'] == true) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(lang.t('uploaded_successfully')), backgroundColor: Colors.green));
                      _loadData();
                    } else {
                      setDialogState(() => isDialogUploading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${lang.t('save_error')}: ${addResult['message']}'), backgroundColor: Colors.red));
                    }
                  } else {
                    setDialogState(() => isDialogUploading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${lang.t('upload_error')}: ${res['error']}'), backgroundColor: Colors.red));
                  }
                }
              },
              child: isDialogUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(lang.t('upload')),
            ),
          ],
        ),
      ),
    );
  }

  Future _uploadMaterial() async {
    final lang   = Provider.of<LanguageProvider>(context, listen: false);
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    _showLoading();
    final user = await LocalStorage.getUserInfo();
    final res  = await _fileService.uploadFile(File(result.files.single.path!), result.files.single.name,
        userId: user['mId'] ?? 'unknown', courseIds: [widget.course.id]);
    _hideLoading();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true ? lang.t('uploaded_successfully') : 'Failed: ${res['error']}'),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red));
      if (res['success'] == true) _loadData();
    }
  }

  void _addMessageDialog() async {
    final lang        = Provider.of<LanguageProvider>(context, listen: false);
    final contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('new_message')),
        content: TextField(controller: contentCtrl, maxLines: 4,
            decoration: InputDecoration(hintText: lang.isEnglish ? 'Type announcement...' : '輸入公告內容...', border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (contentCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx); _showLoading();
              final user    = await LocalStorage.getUserInfo();
              bool success  = await ApiService.addCourseMessage(widget.course.id, user['mId'] ?? '', contentCtrl.text.trim());
              _hideLoading();
              if (success && mounted) {
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.t('message_posted')), backgroundColor: Colors.green));
              }
            },
            child: Text(lang.t('post')),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenFile(String fileUrl, String fileName) async {
    final lang      = Provider.of<LanguageProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('${lang.t('downloading')} $fileName...')));
    try {
      final result = await _fileService.downloadToPrivateDirectory(fileUrl.toString(), fileName);
      messenger.hideCurrentSnackBar();
      if (result['success'] == true && result['path'] != null) {
        final openResult = await OpenFilex.open(result['path']);
        if (openResult.type != ResultType.done && mounted) {
          messenger.showSnackBar(SnackBar(content: Text('${lang.t('error_opening_file')}: ${openResult.message}'), backgroundColor: Colors.red));
        }
      } else if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('${lang.t('upload_error')}: ${result['error']}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('${lang.isEnglish ? 'Error' : '錯誤'}: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: lang.isEnglish ? 'Lessons'   : '課堂'),
            Tab(text: lang.isEnglish ? 'Materials' : '材料'),
            Tab(text: lang.isEnglish ? 'Tasks'     : '作業'),
            Tab(text: lang.isEnglish ? 'Messages'  : '留言'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabController,
              children: [_buildLessonList(lang), _buildMaterialList(lang), _buildTasksList(lang), _buildMessageList(lang)]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0)      _addLessonDialog();
          else if (_tabController.index == 1) _uploadMaterial();
          else if (_tabController.index == 2) _createAssignmentDialog();
          else if (_tabController.index == 3) _addMessageDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLessonList(LanguageProvider lang) {
    if (_lessons.isEmpty) return Center(child: Text(lang.t('no_video_lessons')));
    return ListView.builder(
      itemCount: _lessons.length,
      itemBuilder: (ctx, i) {
        final lesson   = _lessons[i];
        final videoUrl = lesson['video'];
        final title    = lesson['lName'];
        return ListTile(
          leading: const Icon(Icons.play_circle, color: Colors.blue, size: 40),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('0 min'),
          onTap: () {
            if (videoUrl == null || videoUrl.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(lang.t('invalid_video_url')), backgroundColor: Colors.red));
              return;
            }
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (BuildContext context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(title: Text(lang.t('video_playback_options'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                    ListTile(
                      leading: const Icon(Icons.ondemand_video, color: Colors.indigo),
                      title: Text(lang.t('play_in_app')),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: videoUrl, title: title)));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_for_offline, color: Colors.green),
                      title: Text(lang.t('download_open')),
                      onTap: () {
                        Navigator.pop(context);
                        String safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                        String fileName  = safeTitle.toLowerCase().endsWith('.mp4') ? safeTitle : '$safeTitle.mp4';
                        _downloadAndOpenFile(videoUrl, fileName);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: Text(lang.t('delete_lesson'), style: const TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDelete(
                          title: lang.t('delete_lesson'),
                          content: "${lang.t('delete')} '$title'?",
                          onDelete: () => ApiService.deleteLesson(lesson['lId'].toString()),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMaterialList(LanguageProvider lang) {
    if (_materials.isEmpty) return Center(child: Text(lang.t('no_materials')));
    return ListView.builder(
      itemCount: _materials.length,
      itemBuilder: (ctx, i) {
        final file     = _materials[i];
        final fileUrl  = file['file_url'];
        final fileName = file['original_name'] ?? 'File';
        return ListTile(
          leading: const Icon(Icons.description, color: Colors.orange, size: 40),
          title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(file['formatted_size'] ?? ''),
          trailing: const Icon(Icons.more_vert),
          onTap: () {
            if (fileUrl == null || fileUrl.isEmpty) return;
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (BuildContext context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(title: Text(lang.t('file_options'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                    ListTile(
                      leading: const Icon(Icons.download_rounded, color: Colors.blue),
                      title: Text(lang.t('download_open')),
                      onTap: () { Navigator.pop(context); _downloadAndOpenFile(fileUrl, fileName); },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: Text(lang.t('delete_material'), style: const TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDelete(
                          title: lang.t('delete_material'),
                          content: "${lang.t('delete')} '$fileName'?",
                          onDelete: () => ApiService.deleteFile(file['id'].toString()),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTasksList(LanguageProvider lang) {
    if (_assignments.isEmpty) return Center(child: Text(lang.t('no_assignments_yet')));
    return ListView.builder(
      itemCount: _assignments.length,
      itemBuilder: (ctx, i) {
        final task               = _assignments[i];
        final bool hasDescFile   = task.description.startsWith('http://') || task.description.startsWith('https://');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.assignment, color: Colors.teal, size: 36),
            title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${lang.t('due')}: ${task.dueDate.toString().split(' ')[0]}'),
              if (hasDescFile)
                TextButton.icon(
                  icon: const Icon(Icons.insert_drive_file, size: 18),
                  label: Text(lang.t('view_task_file')),
                  onPressed: () {
                    String fileName = 'Task_File';
                    try { fileName = Uri.parse(task.description).pathSegments.last; } catch (_) { fileName = 'Task_${task.id}.pdf'; }
                    _downloadAndOpenFile(task.description, fileName);
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                )
              else if (task.description.isNotEmpty)
                Text(task.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(
                  title: lang.t('delete_task'),
                  content: "${lang.t('delete')} '${task.title}'?",
                  onDelete: () => ApiService.deleteAssignment(task.id),
                ),
              ),
              const Icon(Icons.chevron_right),
            ]),
            onTap: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => _SubmissionListSheet(taskId: task.id, taskTitle: task.title, parentLoadingCallback: _loadData),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageList(LanguageProvider lang) {
    if (_messages.isEmpty) return Center(child: Text(lang.t('no_messages')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg             = _messages[i];
        final hongKongTime    = msg.createDate.add(const Duration(hours: 8));
        final formattedDate   = DateFormat('yyyy-MM-dd HH:mm').format(hongKongTime);
        return Card(
          elevation: 2, margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  CircleAvatar(radius: 16, backgroundColor: Colors.indigo.shade100,
                      child: const Icon(Icons.person, size: 18, color: Colors.indigo)),
                  const SizedBox(width: 8),
                  Text(msg.teacherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                Row(children: [
                  Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    padding: const EdgeInsets.only(left: 8), constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(
                      title: lang.t('delete_message_label'),
                      content: lang.t('delete_message_confirm'),
                      onDelete: () => ApiService.deleteMessage(msg.msgId),
                    ),
                  ),
                ]),
              ]),
              const Divider(),
              Text(msg.content, style: const TextStyle(fontSize: 15, height: 1.5)),
            ]),
          ),
        );
      },
    );
  }
}

// ── Submission Sheet ──
class _SubmissionListSheet extends StatefulWidget {
  final String taskId, taskTitle;
  final VoidCallback parentLoadingCallback;
  const _SubmissionListSheet({required this.taskId, required this.taskTitle, required this.parentLoadingCallback});
  @override
  State<_SubmissionListSheet> createState() => _SubmissionListSheetState();
}

class _SubmissionListSheetState extends State<_SubmissionListSheet> {
  List<AssignmentSubmission> _subs = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadSubmissions(); }

  void _loadSubmissions() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getSubmissions(widget.taskId);
    if (mounted) setState(() {
      _subs = data.map((j) => AssignmentSubmission.fromJson(j)).toList();
      _isLoading = false;
    });
  }

  Future<void> _downloadAndOpenFile(AssignmentSubmission sub) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.t('downloading')} ${sub.fileName}...')));
      final directory = await getTemporaryDirectory();
      final filePath  = '${directory.path}/${sub.fileName}';
      final safeUrl   = sub.fileUrl.trim().replaceAll(' ', '%20');
      final response  = await http.get(Uri.parse(safeUrl));
      if (response.statusCode == 200) { await File(filePath).writeAsBytes(response.bodyBytes); await OpenFilex.open(filePath); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('error_opening_file'))));
    }
  }

  void _showGradeDialog(AssignmentSubmission sub) {
    final lang         = Provider.of<LanguageProvider>(context, listen: false);
    final gradeCtrl    = TextEditingController(text: sub.grade ?? '');
    final feedbackCtrl = TextEditingController(text: sub.feedback ?? '');
    bool isSaving      = false;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${lang.t('grade')}: ${sub.studentName}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: gradeCtrl, decoration: InputDecoration(labelText: lang.t('grade_placeholder')), keyboardType: TextInputType.text),
            TextField(controller: feedbackCtrl, decoration: InputDecoration(labelText: lang.t('feedback_placeholder')), maxLines: 3),
          ]),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: Text(lang.t('cancel'))),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                bool success = await ApiService.updateAssignmentGrade(subId: sub.subId, grade: gradeCtrl.text, feedback: feedbackCtrl.text);
                if (mounted) {
                  setDialogState(() => isSaving = false);
                  Navigator.pop(ctx);
                  if (success) {
                    _loadSubmissions(); widget.parentLoadingCallback();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(lang.t('grade_saved_ok')), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(lang.t('grade_save_failed')), backgroundColor: Colors.red));
                  }
                }
              },
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(lang.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text('${lang.t('submissions')}: ${widget.taskTitle}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Divider(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _subs.isEmpty
                  ? Center(child: Text(lang.t('no_submissions')))
                  : ListView.builder(
                      itemCount: _subs.length,
                      itemBuilder: (ctx, i) {
                        final sub      = _subs[i];
                        final isGraded = sub.grade != null && sub.grade!.isNotEmpty;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                                backgroundColor: isGraded ? Colors.green : Colors.grey[300],
                                child: Icon(isGraded ? Icons.check : Icons.person, color: Colors.white)),
                            title: Text(sub.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(isGraded
                                ? '${lang.t('grade')}: ${sub.grade} (${sub.feedback ?? 'N/A'})'
                                : '${lang.t('submitted_on')}: ${sub.submitDate.toString().split(' ')[0]}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.download_rounded, color: Colors.blue), onPressed: () => _downloadAndOpenFile(sub)),
                              IconButton(icon: const Icon(Icons.rate_review_outlined, color: Colors.orange), onPressed: () => _showGradeDialog(sub)),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
