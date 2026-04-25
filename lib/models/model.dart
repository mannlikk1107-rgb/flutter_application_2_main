class Admin {
  final String aId;
  final String username;
  final String password;
  final String createDate;
  final String? lastLogin;

  Admin({
    required this.aId,
    required this.username,
    required this.password,
    required this.createDate,
    this.lastLogin,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      aId: json['aID'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      createDate: json['createDate'] ?? '',
      lastLogin: json['lastLogin'],
    );
  }
}