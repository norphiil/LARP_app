class Role {
  final String id;
  final String name;
  final String? description;
  final List<String> permissions;
  final DateTime createdAt;

  Role({
    required this.id,
    required this.name,
    this.description,
    required this.permissions,
    required this.createdAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      permissions: _parsePermissions(json['permissions']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static List<String> _parsePermissions(dynamic permissions) {
    if (permissions is List) {
      return permissions.cast<String>();
    } else if (permissions is String) {
      return permissions.split(',');
    } else {
      return <String>[];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissions': permissions.join(','),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }
}
