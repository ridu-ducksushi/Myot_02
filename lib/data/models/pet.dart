import 'package:freezed_annotation/freezed_annotation.dart';

part 'pet.freezed.dart';
part 'pet.g.dart';

@freezed
class Pet with _$Pet {
  const factory Pet({
    required String id,
    required String ownerId,
    required String name,
    required String species,
    String? breed,
    String? sex,
    bool? neutered,
    DateTime? birthDate,
    String? bloodType,
    double? weightKg,
    String? avatarUrl,
    String? defaultIcon,
    String? note,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Pet;

  factory Pet.fromJson(Map<String, dynamic> json) => _$PetFromJson(json);
}
