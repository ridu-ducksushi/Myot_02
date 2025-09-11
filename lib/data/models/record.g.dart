// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecordImpl _$$RecordImplFromJson(Map<String, dynamic> json) => _$RecordImpl(
  id: json['id'] as String,
  petId: json['petId'] as String,
  type: json['type'] as String,
  title: json['title'] as String,
  content: json['content'] as String?,
  value: json['value'] as Map<String, dynamic>?,
  at: DateTime.parse(json['at'] as String),
  files: (json['files'] as List<dynamic>?)?.map((e) => e as String).toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$RecordImplToJson(_$RecordImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'petId': instance.petId,
      'type': instance.type,
      'title': instance.title,
      'content': instance.content,
      'value': instance.value,
      'at': instance.at.toIso8601String(),
      'files': instance.files,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
