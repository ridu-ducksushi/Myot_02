// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lab.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Lab _$LabFromJson(Map<String, dynamic> json) {
  return _Lab.fromJson(json);
}

/// @nodoc
mixin _$Lab {
  String get id => throw _privateConstructorUsedError;
  String get petId => throw _privateConstructorUsedError;
  String get panel => throw _privateConstructorUsedError; // CBC|Biochemistry
  Map<String, dynamic> get items => throw _privateConstructorUsedError;
  DateTime get measuredAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Lab to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Lab
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LabCopyWith<Lab> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LabCopyWith<$Res> {
  factory $LabCopyWith(Lab value, $Res Function(Lab) then) =
      _$LabCopyWithImpl<$Res, Lab>;
  @useResult
  $Res call({
    String id,
    String petId,
    String panel,
    Map<String, dynamic> items,
    DateTime measuredAt,
    DateTime createdAt,
  });
}

/// @nodoc
class _$LabCopyWithImpl<$Res, $Val extends Lab> implements $LabCopyWith<$Res> {
  _$LabCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Lab
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? petId = null,
    Object? panel = null,
    Object? items = null,
    Object? measuredAt = null,
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
            panel: null == panel
                ? _value.panel
                : panel // ignore: cast_nullable_to_non_nullable
                      as String,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            measuredAt: null == measuredAt
                ? _value.measuredAt
                : measuredAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
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
abstract class _$$LabImplCopyWith<$Res> implements $LabCopyWith<$Res> {
  factory _$$LabImplCopyWith(_$LabImpl value, $Res Function(_$LabImpl) then) =
      __$$LabImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String petId,
    String panel,
    Map<String, dynamic> items,
    DateTime measuredAt,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$LabImplCopyWithImpl<$Res> extends _$LabCopyWithImpl<$Res, _$LabImpl>
    implements _$$LabImplCopyWith<$Res> {
  __$$LabImplCopyWithImpl(_$LabImpl _value, $Res Function(_$LabImpl) _then)
    : super(_value, _then);

  /// Create a copy of Lab
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? petId = null,
    Object? panel = null,
    Object? items = null,
    Object? measuredAt = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$LabImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        petId: null == petId
            ? _value.petId
            : petId // ignore: cast_nullable_to_non_nullable
                  as String,
        panel: null == panel
            ? _value.panel
            : panel // ignore: cast_nullable_to_non_nullable
                  as String,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        measuredAt: null == measuredAt
            ? _value.measuredAt
            : measuredAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
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
class _$LabImpl implements _Lab {
  const _$LabImpl({
    required this.id,
    required this.petId,
    required this.panel,
    required final Map<String, dynamic> items,
    required this.measuredAt,
    required this.createdAt,
  }) : _items = items;

  factory _$LabImpl.fromJson(Map<String, dynamic> json) =>
      _$$LabImplFromJson(json);

  @override
  final String id;
  @override
  final String petId;
  @override
  final String panel;
  // CBC|Biochemistry
  final Map<String, dynamic> _items;
  // CBC|Biochemistry
  @override
  Map<String, dynamic> get items {
    if (_items is EqualUnmodifiableMapView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_items);
  }

  @override
  final DateTime measuredAt;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Lab(id: $id, petId: $petId, panel: $panel, items: $items, measuredAt: $measuredAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LabImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.petId, petId) || other.petId == petId) &&
            (identical(other.panel, panel) || other.panel == panel) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.measuredAt, measuredAt) ||
                other.measuredAt == measuredAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    petId,
    panel,
    const DeepCollectionEquality().hash(_items),
    measuredAt,
    createdAt,
  );

  /// Create a copy of Lab
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LabImplCopyWith<_$LabImpl> get copyWith =>
      __$$LabImplCopyWithImpl<_$LabImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LabImplToJson(this);
  }
}

abstract class _Lab implements Lab {
  const factory _Lab({
    required final String id,
    required final String petId,
    required final String panel,
    required final Map<String, dynamic> items,
    required final DateTime measuredAt,
    required final DateTime createdAt,
  }) = _$LabImpl;

  factory _Lab.fromJson(Map<String, dynamic> json) = _$LabImpl.fromJson;

  @override
  String get id;
  @override
  String get petId;
  @override
  String get panel; // CBC|Biochemistry
  @override
  Map<String, dynamic> get items;
  @override
  DateTime get measuredAt;
  @override
  DateTime get createdAt;

  /// Create a copy of Lab
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LabImplCopyWith<_$LabImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
