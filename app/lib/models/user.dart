class User {
  final String id;
  final String username;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? department;
  final String? position;
  final String? profilePicture;
  final String? qrCodeData;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;
  final String? createdBy;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.department,
    this.position,
    this.profilePicture,
    this.qrCodeData,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.lastLogin,
    this.createdBy,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      department: json['department'] as String?,
      position: json['position'] as String?,
      profilePicture: json['profilePicture'] as String?,
      qrCodeData: json['qrCodeData'] as String?,
      isActive: _parseBool(json['isActive']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
      lastLogin: json['lastLogin'] != null 
          ? DateTime.parse(json['lastLogin'] as String) 
          : null,
      createdBy: json['createdBy'] as String?,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'department': department,
      'position': position,
      'profilePicture': profilePicture,
      'qrCodeData': qrCodeData,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username;
  }

  bool get hasEditPermissions => ['admin', 'manager'].contains(role);
  bool get canScanQR => ['admin', 'manager', 'scanner'].contains(role);
  bool get canCreateUsers => ['admin', 'manager'].contains(role);
  bool get isAdmin => role == 'admin';

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? role,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? department,
    String? position,
    String? profilePicture,
    String? qrCodeData,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
    String? createdBy,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
      position: position ?? this.position,
      profilePicture: profilePicture ?? this.profilePicture,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
