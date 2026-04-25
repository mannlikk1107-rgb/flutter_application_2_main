class Member {
  final String mId;
  final String fName;
  final String nName;
  final String mType;
  final String email;
  final String address;
  final int tel;
  
  // 這是從 ACoinTransaction 計算出來的餘額
  final double points; 

  // UI 輔助欄位
  final String? avatar;
  final String? bio;
  final List<String>? skills;

  Member({
    required this.mId,
    required this.fName,
    required this.nName,
    required this.mType,
    required this.email,
    required this.address,
    required this.tel,
    this.points = 0.0, 
    this.avatar,
    this.bio,
    this.skills,
  });

  String get id => mId;
  String get name => '$fName $nName';
  String get role => mType;

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      mId: json['mId']?.toString() ?? '',
      fName: json['fName'] ?? '',
      nName: json['nName'] ?? '',
      mType: json['mType'] ?? 'STUDENT',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      tel: int.tryParse(json['tel']?.toString() ?? '0') ?? 0,
      // 嘗試讀取 API 回傳的 'balance' 或 'points'，如果沒有則預設 0
      points: double.tryParse(json['balance']?.toString() ?? json['points']?.toString() ?? '0') ?? 0.0,
      bio: 'Welcome to EduLive+',
      skills: ['Learning'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'mId': mId,
      'fName': fName,
      'nName': nName,
      'mType': mType,
      'email': email,
      'address': address,
      'tel': tel,
      'points': points,
    };
  }
}

// 保留子類別以相容 UI
class TeacherProfile extends Member {
  final double totalEarnings;
  final int totalStudents;
  final double rating;
  final int experience;
  final String specialization;

  TeacherProfile({
    required super.mId, required super.fName, required super.nName,
    required super.email, required super.mType, required super.address,
    required super.tel, super.points, super.bio, super.avatar, super.skills,
    this.totalEarnings = 0.0, this.totalStudents = 0,
    this.rating = 5.0, this.experience = 1, this.specialization = 'General',
  });
}

class StudentProfile extends Member {
  final int completedCourses;

  StudentProfile({
    required super.mId, required super.fName, required super.nName,
    required super.email, required super.mType, required super.address,
    required super.tel, super.points, super.bio, super.avatar, super.skills,
    this.completedCourses = 0,
  });
}
