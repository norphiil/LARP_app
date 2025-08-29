// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Role _$RoleFromJson(Map<String, dynamic> json) => Role(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  permissions: (json['permissions'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$RoleToJson(Role instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'permissions': instance.permissions,
  'createdAt': instance.createdAt.toIso8601String(),
};
