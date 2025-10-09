// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Pet _$PetFromJson(Map<String, dynamic> json) {
  return _Pet.fromJson(json);
}

/// @nodoc
mixin _$Pet {
  String get id => throw _privateConstructorUsedError;
  String get ownerId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get species => throw _privateConstructorUsedError;
  String? get breed => throw _privateConstructorUsedError;
  String? get sex => throw _privateConstructorUsedError;
  bool? get neutered => throw _privateConstructorUsedError;
  DateTime? get birthDate => throw _privateConstructorUsedError;
  String? get bloodType => throw _privateConstructorUsedError;
  double? get weightKg => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get defaultIcon => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  String? get suppliesFood => throw _privateConstructorUsedError;
  String? get suppliesSupplement => throw _privateConstructorUsedError;
  String? get suppliesSnack => throw _privateConstructorUsedError;
  String? get suppliesLitter => throw _privateConstructorUsedError;
  DateTime? get suppliesLastUpdated => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Pet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Pet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PetCopyWith<Pet> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PetCopyWith<$Res> {
  factory $PetCopyWith(Pet value, $Res Function(Pet) then) =
      _$PetCopyWithImpl<$Res, Pet>;
  @useResult
  $Res call({
    String id,
    String ownerId,
    String name,
    String species,
    String? breed,
    String? sex,
    bool? neutered,
    DateTime? birthDate,
    String? bloodType,
    double? weightKg,
    String? avatarUrl,
    String? defaultIcon,
    String? note,
    String? suppliesFood,
    String? suppliesSupplement,
    String? suppliesSnack,
    String? suppliesLitter,
    DateTime? suppliesLastUpdated,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$PetCopyWithImpl<$Res, $Val extends Pet> implements $PetCopyWith<$Res> {
  _$PetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Pet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? name = null,
    Object? species = null,
    Object? breed = freezed,
    Object? sex = freezed,
    Object? neutered = freezed,
    Object? birthDate = freezed,
    Object? bloodType = freezed,
    Object? weightKg = freezed,
    Object? avatarUrl = freezed,
    Object? defaultIcon = freezed,
    Object? note = freezed,
    Object? suppliesFood = freezed,
    Object? suppliesSupplement = freezed,
    Object? suppliesSnack = freezed,
    Object? suppliesLitter = freezed,
    Object? suppliesLastUpdated = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerId: null == ownerId
                ? _value.ownerId
                : ownerId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            species: null == species
                ? _value.species
                : species // ignore: cast_nullable_to_non_nullable
                      as String,
            breed: freezed == breed
                ? _value.breed
                : breed // ignore: cast_nullable_to_non_nullable
                      as String?,
            sex: freezed == sex
                ? _value.sex
                : sex // ignore: cast_nullable_to_non_nullable
                      as String?,
            neutered: freezed == neutered
                ? _value.neutered
                : neutered // ignore: cast_nullable_to_non_nullable
                      as bool?,
            birthDate: freezed == birthDate
                ? _value.birthDate
                : birthDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            bloodType: freezed == bloodType
                ? _value.bloodType
                : bloodType // ignore: cast_nullable_to_non_nullable
                      as String?,
            weightKg: freezed == weightKg
                ? _value.weightKg
                : weightKg // ignore: cast_nullable_to_non_nullable
                      as double?,
            avatarUrl: freezed == avatarUrl
                ? _value.avatarUrl
                : avatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            defaultIcon: freezed == defaultIcon
                ? _value.defaultIcon
                : defaultIcon // ignore: cast_nullable_to_non_nullable
                      as String?,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            suppliesFood: freezed == suppliesFood
                ? _value.suppliesFood
                : suppliesFood // ignore: cast_nullable_to_non_nullable
                      as String?,
            suppliesSupplement: freezed == suppliesSupplement
                ? _value.suppliesSupplement
                : suppliesSupplement // ignore: cast_nullable_to_non_nullable
                      as String?,
            suppliesSnack: freezed == suppliesSnack
                ? _value.suppliesSnack
                : suppliesSnack // ignore: cast_nullable_to_non_nullable
                      as String?,
            suppliesLitter: freezed == suppliesLitter
                ? _value.suppliesLitter
                : suppliesLitter // ignore: cast_nullable_to_non_nullable
                      as String?,
            suppliesLastUpdated: freezed == suppliesLastUpdated
                ? _value.suppliesLastUpdated
                : suppliesLastUpdated // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PetImplCopyWith<$Res> implements $PetCopyWith<$Res> {
  factory _$$PetImplCopyWith(_$PetImpl value, $Res Function(_$PetImpl) then) =
      __$$PetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String ownerId,
    String name,
    String species,
    String? breed,
    String? sex,
    bool? neutered,
    DateTime? birthDate,
    String? bloodType,
    double? weightKg,
    String? avatarUrl,
    String? defaultIcon,
    String? note,
    String? suppliesFood,
    String? suppliesSupplement,
    String? suppliesSnack,
    String? suppliesLitter,
    DateTime? suppliesLastUpdated,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$PetImplCopyWithImpl<$Res> extends _$PetCopyWithImpl<$Res, _$PetImpl>
    implements _$$PetImplCopyWith<$Res> {
  __$$PetImplCopyWithImpl(_$PetImpl _value, $Res Function(_$PetImpl) _then)
    : super(_value, _then);

  /// Create a copy of Pet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? name = null,
    Object? species = null,
    Object? breed = freezed,
    Object? sex = freezed,
    Object? neutered = freezed,
    Object? birthDate = freezed,
    Object? bloodType = freezed,
    Object? weightKg = freezed,
    Object? avatarUrl = freezed,
    Object? defaultIcon = freezed,
    Object? note = freezed,
    Object? suppliesFood = freezed,
    Object? suppliesSupplement = freezed,
    Object? suppliesSnack = freezed,
    Object? suppliesLitter = freezed,
    Object? suppliesLastUpdated = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$PetImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerId: null == ownerId
            ? _value.ownerId
            : ownerId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        species: null == species
            ? _value.species
            : species // ignore: cast_nullable_to_non_nullable
                  as String,
        breed: freezed == breed
            ? _value.breed
            : breed // ignore: cast_nullable_to_non_nullable
                  as String?,
        sex: freezed == sex
            ? _value.sex
            : sex // ignore: cast_nullable_to_non_nullable
                  as String?,
        neutered: freezed == neutered
            ? _value.neutered
            : neutered // ignore: cast_nullable_to_non_nullable
                  as bool?,
        birthDate: freezed == birthDate
            ? _value.birthDate
            : birthDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        bloodType: freezed == bloodType
            ? _value.bloodType
            : bloodType // ignore: cast_nullable_to_non_nullable
                  as String?,
        weightKg: freezed == weightKg
            ? _value.weightKg
            : weightKg // ignore: cast_nullable_to_non_nullable
                  as double?,
        avatarUrl: freezed == avatarUrl
            ? _value.avatarUrl
            : avatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        defaultIcon: freezed == defaultIcon
            ? _value.defaultIcon
            : defaultIcon // ignore: cast_nullable_to_non_nullable
                  as String?,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        suppliesFood: freezed == suppliesFood
            ? _value.suppliesFood
            : suppliesFood // ignore: cast_nullable_to_non_nullable
                  as String?,
        suppliesSupplement: freezed == suppliesSupplement
            ? _value.suppliesSupplement
            : suppliesSupplement // ignore: cast_nullable_to_non_nullable
                  as String?,
        suppliesSnack: freezed == suppliesSnack
            ? _value.suppliesSnack
            : suppliesSnack // ignore: cast_nullable_to_non_nullable
                  as String?,
        suppliesLitter: freezed == suppliesLitter
            ? _value.suppliesLitter
            : suppliesLitter // ignore: cast_nullable_to_non_nullable
                  as String?,
        suppliesLastUpdated: freezed == suppliesLastUpdated
            ? _value.suppliesLastUpdated
            : suppliesLastUpdated // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PetImpl implements _Pet {
  const _$PetImpl({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    this.breed,
    this.sex,
    this.neutered,
    this.birthDate,
    this.bloodType,
    this.weightKg,
    this.avatarUrl,
    this.defaultIcon,
    this.note,
    this.suppliesFood,
    this.suppliesSupplement,
    this.suppliesSnack,
    this.suppliesLitter,
    this.suppliesLastUpdated,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _$PetImpl.fromJson(Map<String, dynamic> json) =>
      _$$PetImplFromJson(json);

  @override
  final String id;
  @override
  final String ownerId;
  @override
  final String name;
  @override
  final String species;
  @override
  final String? breed;
  @override
  final String? sex;
  @override
  final bool? neutered;
  @override
  final DateTime? birthDate;
  @override
  final String? bloodType;
  @override
  final double? weightKg;
  @override
  final String? avatarUrl;
  @override
  final String? defaultIcon;
  @override
  final String? note;
  @override
  final String? suppliesFood;
  @override
  final String? suppliesSupplement;
  @override
  final String? suppliesSnack;
  @override
  final String? suppliesLitter;
  @override
  final DateTime? suppliesLastUpdated;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Pet(id: $id, ownerId: $ownerId, name: $name, species: $species, breed: $breed, sex: $sex, neutered: $neutered, birthDate: $birthDate, bloodType: $bloodType, weightKg: $weightKg, avatarUrl: $avatarUrl, defaultIcon: $defaultIcon, note: $note, suppliesFood: $suppliesFood, suppliesSupplement: $suppliesSupplement, suppliesSnack: $suppliesSnack, suppliesLitter: $suppliesLitter, suppliesLastUpdated: $suppliesLastUpdated, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PetImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.species, species) || other.species == species) &&
            (identical(other.breed, breed) || other.breed == breed) &&
            (identical(other.sex, sex) || other.sex == sex) &&
            (identical(other.neutered, neutered) ||
                other.neutered == neutered) &&
            (identical(other.birthDate, birthDate) ||
                other.birthDate == birthDate) &&
            (identical(other.bloodType, bloodType) ||
                other.bloodType == bloodType) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.defaultIcon, defaultIcon) ||
                other.defaultIcon == defaultIcon) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.suppliesFood, suppliesFood) ||
                other.suppliesFood == suppliesFood) &&
            (identical(other.suppliesSupplement, suppliesSupplement) ||
                other.suppliesSupplement == suppliesSupplement) &&
            (identical(other.suppliesSnack, suppliesSnack) ||
                other.suppliesSnack == suppliesSnack) &&
            (identical(other.suppliesLitter, suppliesLitter) ||
                other.suppliesLitter == suppliesLitter) &&
            (identical(other.suppliesLastUpdated, suppliesLastUpdated) ||
                other.suppliesLastUpdated == suppliesLastUpdated) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    ownerId,
    name,
    species,
    breed,
    sex,
    neutered,
    birthDate,
    bloodType,
    weightKg,
    avatarUrl,
    defaultIcon,
    note,
    suppliesFood,
    suppliesSupplement,
    suppliesSnack,
    suppliesLitter,
    suppliesLastUpdated,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of Pet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PetImplCopyWith<_$PetImpl> get copyWith =>
      __$$PetImplCopyWithImpl<_$PetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PetImplToJson(this);
  }
}

abstract class _Pet implements Pet {
  const factory _Pet({
    required final String id,
    required final String ownerId,
    required final String name,
    required final String species,
    final String? breed,
    final String? sex,
    final bool? neutered,
    final DateTime? birthDate,
    final String? bloodType,
    final double? weightKg,
    final String? avatarUrl,
    final String? defaultIcon,
    final String? note,
    final String? suppliesFood,
    final String? suppliesSupplement,
    final String? suppliesSnack,
    final String? suppliesLitter,
    final DateTime? suppliesLastUpdated,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$PetImpl;

  factory _Pet.fromJson(Map<String, dynamic> json) = _$PetImpl.fromJson;

  @override
  String get id;
  @override
  String get ownerId;
  @override
  String get name;
  @override
  String get species;
  @override
  String? get breed;
  @override
  String? get sex;
  @override
  bool? get neutered;
  @override
  DateTime? get birthDate;
  @override
  String? get bloodType;
  @override
  double? get weightKg;
  @override
  String? get avatarUrl;
  @override
  String? get defaultIcon;
  @override
  String? get note;
  @override
  String? get suppliesFood;
  @override
  String? get suppliesSupplement;
  @override
  String? get suppliesSnack;
  @override
  String? get suppliesLitter;
  @override
  DateTime? get suppliesLastUpdated;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Pet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PetImplCopyWith<_$PetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
