
class Course {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String teacherId;
  final String teacherName;
  final String? coverImage;
  final int studentCount;
  final int totalLesson;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.teacherId,
    required this.teacherName,
    this.coverImage,
    required this.studentCount,
    required this.totalLesson,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['cId']?.toString() ?? '',
      title: json['cName'] ?? 'Untitled Course',
      description: json['description'] ?? '',
      price: double.tryParse(json['unitPrice']?.toString() ?? '0') ?? 0,
      category: json['category'] ?? 'General',
      teacherId: json['mId']?.toString() ?? '',
      teacherName: json['fName'] ?? 'Unknown Teacher',
      coverImage: json['coverImage'],
      studentCount: int.tryParse(json['studentCount']?.toString() ?? '0') ?? 0,
      totalLesson: int.tryParse(json['totalLesson']?.toString() ?? '0') ?? 0,
    );
  }
}

class Assignment {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isSubmitted;
  final String? grade;
  final String? feedback;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.isSubmitted,
    this.grade,
    this.feedback,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['aId']?.toString() ?? '',
      title: json['title'] ?? 'Untitled Assignment',
      description: json['description'] ?? '',
      dueDate: DateTime.tryParse(json['dueDate'] ?? '') ?? DateTime.now(),
      isSubmitted: json['isSubmitted'] == 1 || json['isSubmitted'] == true,
      grade: json['grade']?.toString(),
      feedback: json['feedback']?.toString(),
    );
  }
}

class AssignmentSubmission {
  final String subId;
  final String studentName;
  final String fileUrl;
  final String fileName;
  final DateTime submitDate;
  final String? grade;
  final String? feedback;

  AssignmentSubmission({
    required this.subId,
    required this.studentName,
    required this.fileUrl,
    required this.fileName,
    required this.submitDate,
    this.grade,
    this.feedback,
  });

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmission(
      subId: json['subId']?.toString() ?? '',
      studentName: json['studentName'] ?? 
                   "${json['fName'] ?? ''} ${json['nName'] ?? ''}".trim(),
      fileUrl: json['filePath'] ?? '',
      fileName: json['fileName'] ?? 'File',
      submitDate: DateTime.tryParse(json['submitDate'] ?? '') ?? DateTime.now(),
      grade: json['grade']?.toString(),
      feedback: json['feedback']?.toString(),
    );
  }
}

class CourseMessage {
  final String msgId;
  final String cId;
  final String mId;
  final String content;
  final DateTime createDate;
  final String teacherName;

  CourseMessage({
    required this.msgId,
    required this.cId,
    required this.mId,
    required this.content,
    required this.createDate,
    required this.teacherName,
  });

  factory CourseMessage.fromJson(Map<String, dynamic> json) {
    return CourseMessage(
      msgId: json['msgId']?.toString() ?? '',
      cId: json['cId']?.toString() ?? '',
      mId: json['mId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createDate: DateTime.tryParse(json['createDate'] ?? '') ?? DateTime.now(),
      teacherName: json['fName'] ?? json['teacherName'] ?? 'Unknown Teacher',
    );
  }
}