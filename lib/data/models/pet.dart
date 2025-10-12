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
    String? profileBgColor, // 프로필 배경색 (Color_1 ~ Color_7)
    String? note,
    String? suppliesFood,
    String? suppliesSupplement,
    String? suppliesSnack,
    String? suppliesLitter,
    DateTime? suppliesLastUpdated,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Pet;

  factory Pet.fromJson(Map<String, dynamic> json) => _$PetFromJson(json);
}
