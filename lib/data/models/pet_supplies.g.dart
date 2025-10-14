// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet_supplies.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PetSuppliesImpl _$$PetSuppliesImplFromJson(Map<String, dynamic> json) =>
    _$PetSuppliesImpl(
      id: json['id'] as String,
      petId: json['petId'] as String,
      dryFood: json['dryFood'] as String?,
      wetFood: json['wetFood'] as String?,
      supplement: json['supplement'] as String?,
      snack: json['snack'] as String?,
      litter: json['litter'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$PetSuppliesImplToJson(_$PetSuppliesImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'petId': instance.petId,
      'dryFood': instance.dryFood,
      'wetFood': instance.wetFood,
      'supplement': instance.supplement,
      'snack': instance.snack,
      'litter': instance.litter,
      'recordedAt': instance.recordedAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
