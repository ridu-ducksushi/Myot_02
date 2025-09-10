// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReminderImpl _$$ReminderImplFromJson(Map<String, dynamic> json) =>
    _$ReminderImpl(
      id: json['id'] as String,
      petId: json['petId'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      repeatRule: json['repeatRule'] as String?,
      done: json['done'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ReminderImplToJson(_$ReminderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'petId': instance.petId,
      'type': instance.type,
      'title': instance.title,
      'note': instance.note,
      'scheduledAt': instance.scheduledAt.toIso8601String(),
      'repeatRule': instance.repeatRule,
      'done': instance.done,
      'createdAt': instance.createdAt.toIso8601String(),
    };
