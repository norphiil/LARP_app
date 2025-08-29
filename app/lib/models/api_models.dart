// Import User model
import 'user.dart';

class AuthResponse {
  final String token;
  final User user;
  final String message;

  AuthResponse({
    required this.token,
    required this.user,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      message: json['message'] as String,
    );
  }
}

class UserModification {
  final String id;
  final String userId;
  final String modifiedBy;
  final Map<String, dynamic> modifications;
  final bool synced;
  final DateTime createdAt;
  final DateTime? syncedAt;

  UserModification({
    required this.id,
    required this.userId,
    required this.modifiedBy,
    required this.modifications,
    required this.synced,
    required this.createdAt,
    this.syncedAt,
  });

  factory UserModification.fromJson(Map<String, dynamic> json) {
    return UserModification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      modifiedBy: json['modifiedBy'] as String,
      modifications: json['modifications'] as Map<String, dynamic>,
      synced: _parseBool(json['synced']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      syncedAt: json['syncedAt'] != null 
          ? DateTime.parse(json['syncedAt'] as String) 
          : null,
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
      'userId': userId,
      'modifiedBy': modifiedBy,
      'modifications': modifications,
      'synced': synced ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
    };
  }
}

class UsersListResponse {
  final List<User> users;
  final int total;
  final int page;
  final int limit;

  UsersListResponse({
    required this.users,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory UsersListResponse.fromJson(Map<String, dynamic> json) {
    return UsersListResponse(
      users: (json['users'] as List)
          .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }
}
