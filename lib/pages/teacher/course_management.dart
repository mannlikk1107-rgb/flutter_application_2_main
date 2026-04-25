import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';
import 'teacher_course_content_page.dart';

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({super.key});

  @override
  State<CourseManagementPage> createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  List<Course> _myCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherCourses();
  }

  Future<void> _loadTeacherCourses() async {
    setState(() => _isLoading = true);
    final user = await LocalStorage.getUserInfo();
    final mId = user['mId'];
    
    if (mId != null && mId.isNotEmpty) {
      final data = await ApiService.getTeacherCourses(mId);
      if (mounted) {
        setState(() {
          _myCourses = data.map((json) => Course.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } else {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCourse(Course course) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('confirm_delete')),
        content: Text(lang.isEnglish
            ? "Are you sure you want to delete '${course.title}'? This cannot be undone."
            : "確定要刪除「${course.title}」嗎？此操作無法復原。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(lang.t('delete'))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      bool success = await ApiService.deleteCourse(course.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? lang.t('course_deleted') : lang.t('course_delete_failed')),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
        await _loadTeacherCourses();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(lang.t('nav_courses')),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myCourses.isEmpty
              ? _buildEmptyState(lang)
              : RefreshIndicator(
                  onRefresh: _loadTeacherCourses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myCourses.length,
                    itemBuilder: (context, index) {
                      final course = _myCourses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(context,
                              MaterialPageRoute(builder: (_) => TeacherCourseContentPage(course: course))
                            ).then((_) => _loadTeacherCourses());
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                            child: _buildCourseCardContent(course, lang),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildCourseCardContent(Course course, LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                image: course.coverImage != null
                    ? DecorationImage(image: NetworkImage(course.coverImage!), fit: BoxFit.cover)
                    : null,
              ),
              child: course.coverImage == null ? const Icon(Icons.school, color: Colors.blue) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${lang.t('price_label')}: HK\$ ${course.price.toStringAsFixed(0)}",
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                if (value == 'delete') _deleteCourse(course);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Row(children: [
                  const Icon(Icons.edit, size: 20), const SizedBox(width: 8),
                  Text(lang.t('edit_info')),
                ])),
                PopupMenuItem(value: 'delete', child: Row(children: [
                  const Icon(Icons.delete, color: Colors.red, size: 20), const SizedBox(width: 8),
                  Text(lang.t('delete_course'), style: const TextStyle(color: Colors.red)),
                ])),
              ],
            ),
          ],
        ),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn(lang.t('students'), course.studentCount.toString(), Icons.people, Colors.green),
            _buildStatColumn(lang.t('lessons'), course.totalLesson.toString(), Icons.list_alt, Colors.orange),
            _buildStatColumn(lang.t('revenue'),
                "HK\$${(course.price * course.studentCount).toStringAsFixed(0)}", Icons.monetization_on, Colors.blue),
          ],
        ),
      ],
    );
  }
  
  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(lang.t('no_courses_yet'), style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text(lang.t('create_course_hint'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
