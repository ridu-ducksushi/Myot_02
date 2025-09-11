// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lab.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LabImpl _$$LabImplFromJson(Map<String, dynamic> json) => _$LabImpl(
  id: json['id'] as String,
  petId: json['petId'] as String,
  panel: json['panel'] as String,
  items: json['items'] as Map<String, dynamic>,
  measuredAt: DateTime.parse(json['measuredAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$LabImplToJson(_$LabImpl instance) => <String, dynamic>{
  'id': instance.id,
  'petId': instance.petId,
  'panel': instance.panel,
  'items': instance.items,
  'measuredAt': instance.measuredAt.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
};
