import 'package:freezed_annotation/freezed_annotation.dart';

part 'pet_supplies.freezed.dart';
part 'pet_supplies.g.dart';

@freezed
class PetSupplies with _$PetSupplies {
  const factory PetSupplies({
    required String id,
    required String petId,
    String? food,
    String? supplement,
    String? snack,
    String? litter,
    required DateTime lastUpdated,
    required DateTime createdAt,
  }) = _PetSupplies;

  factory PetSupplies.fromJson(Map<String, dynamic> json) =>
      _$PetSuppliesFromJson(json);
}

