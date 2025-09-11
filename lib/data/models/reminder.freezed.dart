// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reminder.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Reminder _$ReminderFromJson(Map<String, dynamic> json) {
  return _Reminder.fromJson(json);
}

/// @nodoc
mixin _$Reminder {
  String get id => throw _privateConstructorUsedError;
  String get petId => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  DateTime get scheduledAt => throw _privateConstructorUsedError;
  String? get repeatRule => throw _privateConstructorUsedError;
  bool get done => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Reminder to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Reminder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReminderCopyWith<Reminder> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReminderCopyWith<$Res> {
  factory $ReminderCopyWith(Reminder value, $Res Function(Reminder) then) =
      _$ReminderCopyWithImpl<$Res, Reminder>;
  @useResult
  $Res call({
    String id,
    String petId,
    String type,
    String title,
    String? note,
    DateTime scheduledAt,
    String? repeatRule,
    bool done,
    DateTime createdAt,
  });
}

/// @nodoc
class _$ReminderCopyWithImpl<$Res, $Val extends Reminder>
    implements $ReminderCopyWith<$Res> {
  _$ReminderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Reminder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? petId = null,
    Object? type = null,
    Object? title = null,
    Object? note = freezed,
    Object? scheduledAt = null,
    Object? repeatRule = freezed,
    Object? done = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            petId: null == petId
                ? _value.petId
                : petId // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            scheduledAt: null == scheduledAt
                ? _value.scheduledAt
                : scheduledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            repeatRule: freezed == repeatRule
                ? _value.repeatRule
                : repeatRule // ignore: cast_nullable_to_non_nullable
                      as String?,
            done: null == done
                ? _value.done
                : done // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReminderImplCopyWith<$Res>
    implements $ReminderCopyWith<$Res> {
  factory _$$ReminderImplCopyWith(
    _$ReminderImpl value,
    $Res Function(_$ReminderImpl) then,
  ) = __$$ReminderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String petId,
    String type,
    String title,
    String? note,
    DateTime scheduledAt,
    String? repeatRule,
    bool done,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$ReminderImplCopyWithImpl<$Res>
    extends _$ReminderCopyWithImpl<$Res, _$ReminderImpl>
    implements _$$ReminderImplCopyWith<$Res> {
  __$$ReminderImplCopyWithImpl(
    _$ReminderImpl _value,
    $Res Function(_$ReminderImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Reminder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? petId = null,
    Object? type = null,
    Object? title = null,
    Object? note = freezed,
    Object? scheduledAt = null,
    Object? repeatRule = freezed,
    Object? done = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$ReminderImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        petId: null == petId
            ? _value.petId
            : petId // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        scheduledAt: null == scheduledAt
            ? _value.scheduledAt
            : scheduledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        repeatRule: freezed == repeatRule
            ? _value.repeatRule
            : repeatRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        done: null == done
            ? _value.done
            : done // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReminderImpl implements _Reminder {
  const _$ReminderImpl({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    this.note,
    required this.scheduledAt,
    this.repeatRule,
    this.done = false,
    required this.createdAt,
  });

  factory _$ReminderImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReminderImplFromJson(json);

  @override
  final String id;
  @override
  final String petId;
  @override
  final String type;
  @override
  final String title;
  @override
  final String? note;
  @override
  final DateTime scheduledAt;
  @override
  final String? repeatRule;
  @override
  @JsonKey()
  final bool done;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Reminder(id: $id, petId: $petId, type: $type, title: $title, note: $note, scheduledAt: $scheduledAt, repeatRule: $repeatRule, done: $done, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReminderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.petId, petId) || other.petId == petId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.scheduledAt, scheduledAt) ||
                other.scheduledAt == scheduledAt) &&
            (identical(other.repeatRule, repeatRule) ||
                other.repeatRule == repeatRule) &&
            (identical(other.done, done) || other.done == done) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    petId,
    type,
    title,
    note,
    scheduledAt,
    repeatRule,
    done,
    createdAt,
  );

  /// Create a copy of Reminder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReminderImplCopyWith<_$ReminderImpl> get copyWith =>
      __$$ReminderImplCopyWithImpl<_$ReminderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReminderImplToJson(this);
  }
}

abstract class _Reminder implements Reminder {
  const factory _Reminder({
    required final String id,
    required final String petId,
    required final String type,
    required final String title,
    final String? note,
    required final DateTime scheduledAt,
    final String? repeatRule,
    final bool done,
    required final DateTime createdAt,
  }) = _$ReminderImpl;

  factory _Reminder.fromJson(Map<String, dynamic> json) =
      _$ReminderImpl.fromJson;

  @override
  String get id;
  @override
  String get petId;
  @override
  String get type;
  @override
  String get title;
  @override
  String? get note;
  @override
  DateTime get scheduledAt;
  @override
  String? get repeatRule;
  @override
  bool get done;
  @override
  DateTime get createdAt;

  /// Create a copy of Reminder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReminderImplCopyWith<_$ReminderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
