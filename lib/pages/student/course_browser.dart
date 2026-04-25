// 路徑: lib/pages/student/course_browser.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../services/api_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../common/course_detail_page.dart';

class CourseBrowserPage extends StatefulWidget {
  const CourseBrowserPage({super.key});
  @override
  State<CourseBrowserPage> createState() => _CourseBrowserPageState();
}

class _CourseBrowserPageState extends State<CourseBrowserPage> {
  String _searchQuery = '';
  List<Course> _allCourses = [];
  Set<String> _enrolledCourseIds = {};
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetchData(); }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final coursesData       = await ApiService.getAllCourses();
    final studentCoursesData = await ApiService.getStudentCourses(userProvider.mId);
    setState(() {
      _allCourses        = coursesData.map((data) => Course.fromJson(data)).toList();
      _enrolledCourseIds = studentCoursesData.map((data) => data['cId'].toString()).toSet();
      _isLoading         = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(lang.t('browse_courses')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: lang.t('search_courses'),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(lang),
    );
  }

  Widget _buildBody(LanguageProvider lang) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final filteredCourses = _searchQuery.isEmpty
        ? _allCourses
        : _allCourses.where((c) =>
            c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filteredCourses.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? lang.t('no_courses') : lang.t('no_matching_courses'),
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredCourses.length,
        itemBuilder: (context, index) {
          final course     = filteredCourses[index];
          final isEnrolled = _enrolledCourseIds.contains(course.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailPage(course: course))),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.school, color: Colors.indigo, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(course.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${lang.t('by_teacher')} ${course.teacherName}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ])),
                    if (isEnrolled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(lang.t('enrolled'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    else
                      Text('${course.price.toStringAsFixed(0)} ACoin',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ]),
                  const SizedBox(height: 12),
                  Text(course.description, style: TextStyle(color: Colors.grey[600], fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.people, size: 14, color: Colors.grey[500]), const SizedBox(width: 4),
                    Text('${course.studentCount} ${lang.t('students')}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(width: 16),
                    Icon(Icons.list_alt, size: 14, color: Colors.grey[500]), const SizedBox(width: 4),
                    Text('${course.totalLesson} ${lang.t('lessons')}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
