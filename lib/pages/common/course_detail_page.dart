import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart'; 
import 'package:file_picker/file_picker.dart'; 
import 'package:intl/intl.dart';

import '../../models/course_model.dart';
import '../../services/api_service.dart';
import '../../services/file_service.dart';
import '../../providers/user_provider.dart';
import '../student/top_up_page.dart';
import 'video_player_page.dart'; 

class CourseDetailPage extends StatefulWidget {
  final Course course;
  const CourseDetailPage({super.key, required this.course});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FileService _fileService = FileService();
  
  bool _isEnrolling = false;
  bool _isEnrolled = false;
  bool _isLoadingData = true;
  
  List _lessons = [];
  List<Map<String, dynamic>> _materials = [];
  List<Assignment> _assignments = [];
  List<CourseMessage> _messages = [];

  void _showLoading() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  }

  void _hideLoading() {
    if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCourseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future _loadCourseData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String? mId = userProvider.mId.isNotEmpty ? userProvider.mId : null;
    
    setState(() => _isLoadingData = true);
    
    try {
      final lessonData = await ApiService.getCourseContent(widget.course.id, mId ?? '');
      final fileResult = await _fileService.getFiles(courseId: widget.course.id);
      final msgs = await ApiService.getCourseMessages(widget.course.id);
      
      if (mounted) {
        setState(() {
          if (lessonData['success'] == true) {
            _isEnrolled = lessonData['isEnrolled'] == true;
            _lessons = lessonData['lessons'] ?? [];
            if (_isEnrolled) {
              _fetchAssignments(mId!);
            }
          }
          if (fileResult['success'] == true) {
            _materials = List<Map<String, dynamic>>.from(fileResult['files'] ?? []);
          }
          _messages = msgs;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchAssignments(String mId) async {
     final tData = await ApiService.getAssignments(widget.course.id, mId: mId);
     if (mounted) {
       setState(() {
         _assignments = tData.map((j) => Assignment.fromJson(j)).toList();
       });
     }
  }

  Future _handleEnroll() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.mId.isEmpty) return;
    
    setState(() => _isEnrolling = true);
    if (userProvider.balance < widget.course.price) {
      if(!mounted) return;
      _showInsufficientFundsDialog(userProvider.balance);
      setState(() => _isEnrolling = false);
      return;
    }
    
    final result = await ApiService.enrollCourse(
      memberId: userProvider.mId, courseId: widget.course.id, price: widget.course.price
    );
    
    if (mounted) {
      if (result['success'] == true) {
        await userProvider.refreshBalance();
        _showDialog("Success", "You are now enrolled in this course!");
        _loadCourseData();
      } else {
        _showDialog("Failed", result['message'] ?? "Unknown error occurred.", isError: true);
      }
      setState(() => _isEnrolling = false);
    }
  }

  Future<void> _downloadAndOpenFile(String fileUrl, String fileName) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Downloading $fileName...'), duration: const Duration(seconds: 2)));

    try {
      final Uri uri = Uri.parse(fileUrl);
      final String safeUrl = uri.toString();
      
      debugPrint('📥 Downloading from: $safeUrl');
      debugPrint('📄 File name: $fileName');

      final result = await _fileService.downloadToPrivateDirectory(safeUrl, fileName);
      messenger.hideCurrentSnackBar();

      if (result['success'] == true) {
        final String? downloadedPath = result['path'];
        if (downloadedPath != null) {
          debugPrint('✅ Downloaded to: $downloadedPath');
          final openResult = await OpenFilex.open(downloadedPath);

          if (openResult.type == ResultType.done) {
            debugPrint('✅ File opened successfully.');
          } else {
            debugPrint('❌ Failed to open: ${openResult.message}');
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text("Failed to open file: ${openResult.message}"),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        } else {
          debugPrint('❌ File path is null');
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text("Download successful but no file path returned."), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        debugPrint('❌ Download failed: ${result['error']}');
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text("Download failed: ${result['error']}"), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      messenger.hideCurrentSnackBar();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("An error occurred: $e"), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  void _showInsufficientFundsDialog(double balance) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Insufficient Funds"),
        content: Text("You need ${widget.course.price.toStringAsFixed(0)} ACoin but you only have ${balance.toStringAsFixed(0)}."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpPage()));
          }, child: const Text("Top Up"))
        ],
      ),
    );
  }

  void _showDialog(String title, String content, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? Colors.red : Colors.green),
          const SizedBox(width: 10),
          Text(title)
        ]),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.course.coverImage != null && widget.course.coverImage!.isNotEmpty
                  ? Image.network(widget.course.coverImage!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildPlaceholderImage())
                  : _buildPlaceholderImage(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(label: Text(widget.course.category), backgroundColor: Colors.indigo.withOpacity(0.1)),
                      Text("${widget.course.price.toStringAsFixed(0)} ACoin", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(widget.course.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("By ${widget.course.teacherName}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 15),
                  Text(widget.course.description, style: const TextStyle(color: Colors.grey, height: 1.5)),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.indigo,
                tabs: const [Tab(text: "Lessons"), Tab(text: "Materials"), Tab(text: "Tasks"), Tab(text: "Messages")],
              ),
            ),
            pinned: true,
          ),
        ],
        body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : TabBarView(
          controller: _tabController,
          children: [
            _buildLessonsList(),
            _buildMaterialsList(),
            _buildTasksList(),
            _buildMessageList(),
          ],
        ),
      ),
      bottomSheet: !_isEnrolled ? _buildEnrollButton() : null,
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(color: Colors.indigo.shade50, child: const Icon(Icons.school_rounded, size: 80, color: Colors.indigo));
  }

  Widget _buildEnrollButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _isEnrolling ? null : _handleEnroll,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
          child: _isEnrolling ? const CircularProgressIndicator(color: Colors.white) : Text("Enroll Now • ${widget.course.price.toStringAsFixed(0)} ACoin", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildLessonsList() {
    if (!_isEnrolled) return _buildLockedContent("Please enroll to watch lessons.");
    if (_lessons.isEmpty) return _buildEmptyContent("No video lessons have been added yet.");
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lessons.length,
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        final videoUrl = lesson['video'];
        final title = lesson['lName'] ?? "Lesson ${index + 1}";
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.blue, size: 30),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("0 min"),
            onTap: () {
              if (videoUrl == null || videoUrl.isEmpty) {
                _showDialog("Notice", "No video is available for this lesson.");
                return;
              }
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const ListTile(title: Text('Video Playback Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          ListTile(
                            leading: const Icon(Icons.ondemand_video, color: Colors.indigo),
                            title: const Text('Play in App (Recommended)'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: videoUrl, title: title)));
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.download_for_offline, color: Colors.green),
                            title: const Text('Download & Open (System Player)'),
                            subtitle: const Text('Download video and choose an app to open it'),
                            onTap: () {
                              Navigator.pop(context);
                              String safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                              String fileName = safeTitle.toLowerCase().endsWith('.mp4') ? safeTitle : '$safeTitle.mp4';
                              _downloadAndOpenFile(videoUrl, fileName);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMaterialsList() {
    if (!_isEnrolled) return _buildLockedContent("Please enroll to access course materials.");
    if (_materials.isEmpty) return _buildEmptyContent("No materials have been uploaded for this course.");
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _materials.length,
      itemBuilder: (context, index) {
        final file = _materials[index];
        final fileUrl = file['file_url']; 
        final fileName = file['original_name'] ?? "File";
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.description, color: Colors.orange, size: 28),
            ),
            title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_fileService.formatFileSize(file['file_size'])),
            trailing: const Icon(Icons.more_vert, color: Colors.grey),
            onTap: () {
              if (fileUrl == null || fileUrl.isEmpty) {
                 _showDialog("Error", "Invalid file URL.", isError: true);
                 return;
              }
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const ListTile(title: Text('File Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                          ListTile(
                            leading: const Icon(Icons.download_rounded, color: Colors.blue),
                            title: const Text('Download & Open'),
                            subtitle: const Text('Download file and choose an app to open it'),
                            onTap: () {
                              Navigator.pop(context);
                              _downloadAndOpenFile(fileUrl, fileName);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTasksList() {
    if (!_isEnrolled) return _buildLockedContent("Please enroll to view tasks.");
    if (_assignments.isEmpty) return _buildEmptyContent("No pending tasks! Good job.");

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (ctx, i) {
        final task = _assignments[i];
        final isOverdue = DateTime.now().isAfter(task.dueDate) && !task.isSubmitted;
        
        // 檢查 description 是否為一個 URL
        final bool hasDescriptionFile = (task.description.startsWith('http://') || task.description.startsWith('https://'));

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (task.isSubmitted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                        child: const Text("Submitted", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    else if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                        child: const Text("Overdue", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                  ],
                ),
                const SizedBox(height: 8),
                
                // ✅ 從 URL 中擷取真實檔名
                if (hasDescriptionFile)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.description, color: Color(0xFF6366F1)),
                      label: const Text("View Task File", style: TextStyle(color: Color(0xFF6366F1))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.withOpacity(0.05),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        // 從 URL 中擷取真實的檔名 (包含副檔名)
                        String fileName = "Task_File";
                        try {
                          fileName = Uri.parse(task.description).pathSegments.last;
                        } catch (e) {
                          fileName = "Task_${task.id}.pdf";
                        }
                        _downloadAndOpenFile(task.description, fileName);
                      },
                    ),
                  )
                else if (task.description.isNotEmpty)
                  Text(task.description, style: TextStyle(color: Colors.grey[600])),
                  
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "Due: ${task.dueDate.toString().split(' ')[0]}",
                      style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[700], fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
                if (task.grade != null) ...[
                  const SizedBox(height: 8),
                  Text("Grade: ${task.grade}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(task.isSubmitted ? "Re-upload File" : "Upload Solution"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: task.isSubmitted ? Colors.white : const Color(0xFF6366F1),
                      foregroundColor: task.isSubmitted ? const Color(0xFF6366F1) : Colors.white,
                      side: task.isSubmitted ? const BorderSide(color: Color(0xFF6366F1)) : null,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _uploadAssignmentSolution(task),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    if (!_isEnrolled) return _buildLockedContent("Please enroll to view messages.");
    if (_messages.isEmpty) return _buildEmptyContent("No announcements yet.");
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final hongKongTime = msg.createDate.add(const Duration(hours: 8));
        final formatter = DateFormat('yyyy-MM-dd HH:mm');
        final formattedDate = formatter.format(hongKongTime);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 16, backgroundColor: Colors.indigo.shade100, child: const Icon(Icons.person, size: 18, color: Colors.indigo)),
                        const SizedBox(width: 8),
                        Text(msg.teacherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                const Divider(),
                Text(msg.content, style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadAssignmentSolution(Assignment task) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      _showLoading(); 
      File file = File(result.files.single.path!);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      bool success = await ApiService.submitAssignment(task.id, userProvider.mId, file);
      _hideLoading(); 
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted successfully!"), backgroundColor: Colors.green));
          _fetchAssignments(userProvider.mId); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed."), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildLockedContent(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildEmptyContent(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 2))],
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}