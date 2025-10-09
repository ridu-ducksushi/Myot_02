// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet_supplies.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PetSuppliesImpl _$$PetSuppliesImplFromJson(Map<String, dynamic> json) =>
    _$PetSuppliesImpl(
      id: json['id'] as String,
      petId: json['petId'] as String,
      food: json['food'] as String?,
      supplement: json['supplement'] as String?,
      snack: json['snack'] as String?,
      litter: json['litter'] as String?,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$PetSuppliesImplToJson(_$PetSuppliesImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'petId': instance.petId,
      'food': instance.food,
      'supplement': instance.supplement,
      'snack': instance.snack,
      'litter': instance.litter,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
