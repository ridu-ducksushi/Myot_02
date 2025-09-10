import 'package:freezed_annotation/freezed_annotation.dart';

part 'lab.freezed.dart';
part 'lab.g.dart';

@freezed
class Lab with _$Lab {
  const factory Lab({
    required String id,
    required String petId,
    required String panel, // CBC|Biochemistry
    required Map<String, dynamic> items,
    required DateTime measuredAt,
    required DateTime createdAt,
  }) = _Lab;

  factory Lab.fromJson(Map<String, dynamic> json) => _$LabFromJson(json);
}
