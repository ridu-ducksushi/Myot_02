// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PetImpl _$$PetImplFromJson(Map<String, dynamic> json) => _$PetImpl(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String?,
      sex: json['sex'] as String?,
      neutered: json['neutered'] as bool?,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      bloodType: json['bloodType'] as String?,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      avatarUrl: json['avatarUrl'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$PetImplToJson(_$PetImpl instance) => <String, dynamic>{
      'id': instance.id,
      'ownerId': instance.ownerId,
      'name': instance.name,
      'species': instance.species,
      'breed': instance.breed,
      'sex': instance.sex,
      'neutered': instance.neutered,
      'birthDate': instance.birthDate?.toIso8601String(),
      'bloodType': instance.bloodType,
      'weightKg': instance.weightKg,
      'avatarUrl': instance.avatarUrl,
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
