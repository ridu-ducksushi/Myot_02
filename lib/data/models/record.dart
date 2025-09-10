import 'package:freezed_annotation/freezed_annotation.dart';

part 'record.freezed.dart';
part 'record.g.dart';

@freezed
class Record with _$Record {
  const factory Record({
    required String id,
    required String petId,
    required String type, // meal|snack|litter|med|vaccine|visit|weight|other
    required String title,
    String? content,
    Map<String, dynamic>? value,
    required DateTime at,
    List<String>? files,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Record;

  factory Record.fromJson(Map<String, dynamic> json) => _$RecordFromJson(json);
}
