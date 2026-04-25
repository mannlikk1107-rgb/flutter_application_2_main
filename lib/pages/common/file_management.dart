// 路徑: lib/pages/common/file_management.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart'; // 確保 pubspec.yaml 有加 open_filex
import '../../services/file_service.dart';
import '../../services/local_storage.dart';
import '../../models/course_model.dart';
import '../../services/api_service.dart';

class FileManagementPage extends StatefulWidget {
  const FileManagementPage({super.key});

  @override
  State<FileManagementPage> createState() => _FileManagementPageState();
}

class _FileManagementPageState extends State<FileManagementPage> {
  final FileService _fileService = FileService();
  
  List<PlatformFile> _selectedFiles = [];
  List<Map<String, dynamic>> _uploadedFiles = [];
  bool _isUploading = false;
  bool _isLoading = true;

  // New state for multi-course sharing
  List<Course> _teacherCourses = [];
  final Set<String> _selectedCourseIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _loadTeacherCourses();
    await _loadFiles();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTeacherCourses() async {
    final user = await LocalStorage.getUserInfo();
    final mId = user['mId'];
    if (mId != null && mId.isNotEmpty) {
      final data = await ApiService.getTeacherCourses(mId);
      if (mounted) {
        setState(() => _teacherCourses = data.map((json) => Course.fromJson(json)).toList());
      }
    }
  }

  Future<void> _loadFiles() async {
    final user = await LocalStorage.getUserInfo();
    final result = await _fileService.getFiles(userId: user['mId'] ?? 'unknown');
    if (mounted && result['success'] == true) {
      setState(() => _uploadedFiles = List<Map<String, dynamic>>.from(result['files'] ?? []));
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) setState(() => _selectedFiles = result.files);
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      _showSnackBar('Please select at least one file.', isError: true);
      return;
    }
    if (_selectedCourseIds.isEmpty) {
      _showSnackBar('Please select at least one course to share with.', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    final user = await LocalStorage.getUserInfo();

    for (var file in _selectedFiles) {
      if (file.path == null) continue;
      await _fileService.uploadFile(
        File(file.path!),
        file.name,
        userId: user['mId'] ?? 'unknown',
        courseIds: _selectedCourseIds.toList(),
      );
    }

    if (mounted) {
      _showSnackBar('Files uploaded and shared!', isError: false);
      setState(() {
        _isUploading = false;
        _selectedFiles.clear();
        _selectedCourseIds.clear();
      });
      _loadFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(title: const Text('File Manager')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFiles,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildUploadCard(),
                  const SizedBox(height: 30),
                  const Text("Recently Uploaded", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 16),
                  _uploadedFiles.isEmpty
                      ? _buildEmptyFilesState()
                      : Column(children: _uploadedFiles.map((file) => _buildFileCard(file)).toList()),
                ],
              ),
            ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Upload & Share Files", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildFileSelectionArea(),
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text("Share with Courses", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            _buildCourseSelectionArea(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadFiles,
                icon: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload),
                label: Text(_isUploading ? 'Uploading...' : 'Confirm Upload & Share'),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFileSelectionArea() {
    if (_selectedFiles.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${_selectedFiles.length} file(s) selected:", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              itemBuilder: (c, i) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Chip(
                  label: Text(_selectedFiles[i].name, overflow: TextOverflow.ellipsis),
                  onDeleted: () => setState(() => _selectedFiles.removeAt(i)),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: _pickFiles,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            color: Colors.indigo.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.withAlpha(25)),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.indigo.withAlpha(204)),
              const SizedBox(height: 8),
              const Text("Tap to select files", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildCourseSelectionArea() {
    if (_teacherCourses.isEmpty) {
      return const Text("No courses available to share with.", style: TextStyle(color: Colors.grey));
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: _teacherCourses.map((course) {
        final isSelected = _selectedCourseIds.contains(course.id);
        return FilterChip(
          label: Text(course.title),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCourseIds.add(course.id);
              } else {
                _selectedCourseIds.remove(course.id);
              }
            });
          },
          selectedColor: Colors.indigo.withAlpha(51),
          checkmarkColor: Colors.indigo,
        );
      }).toList(),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final fileName = file['original_name'] ?? 'Unknown File';
    final formattedSize = _fileService.formatFileSize(file['file_size'] ?? 0);
    final iconData = _getFileIcon(fileName);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (iconData['color'] as Color).withAlpha(25),
          child: Icon(iconData['icon'], color: iconData['color']),
        ),
        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("Course ID: ${file['course_id']} • $formattedSize", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.download_outlined, color: Colors.grey),
          onPressed: () async {
            final result = await _fileService.downloadToPrivateDirectory(file['file_url'], fileName);
            if (mounted) {
              if (result['success']) {
                OpenFilex.open(result['path']);
                _showSnackBar('Downloaded. Opening file...', isError: false);
              } else {
                _showSnackBar('Download failed: ${result['error']}', isError: true);
              }
            }
          },
        ),
      ),
    );
  }

  Map<String, dynamic> _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['pdf'].contains(ext)) return {'icon': Icons.picture_as_pdf, 'color': Colors.red};
    if (['doc', 'docx'].contains(ext)) return {'icon': Icons.description, 'color': Colors.blue};
    if (['jpg', 'jpeg', 'png'].contains(ext)) return {'icon': Icons.image, 'color': Colors.green};
    return {'icon': Icons.insert_drive_file, 'color': Colors.grey};
  }

  Widget _buildEmptyFilesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Icon(Icons.folder_off_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No files uploaded yet", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
