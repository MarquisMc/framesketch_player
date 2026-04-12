// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frame_marker.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FrameMarker _$FrameMarkerFromJson(Map<String, dynamic> json) {
  return _FrameMarker.fromJson(json);
}

/// @nodoc
mixin _$FrameMarker {
  String get id => throw _privateConstructorUsedError;
  int get timeMs => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  Color get color => throw _privateConstructorUsedError;

  /// Serializes this FrameMarker to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FrameMarker
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FrameMarkerCopyWith<FrameMarker> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FrameMarkerCopyWith<$Res> {
  factory $FrameMarkerCopyWith(
    FrameMarker value,
    $Res Function(FrameMarker) then,
  ) = _$FrameMarkerCopyWithImpl<$Res, FrameMarker>;
  @useResult
  $Res call({
    String id,
    int timeMs,
    String label,
    String note,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson) Color color,
  });
}

/// @nodoc
class _$FrameMarkerCopyWithImpl<$Res, $Val extends FrameMarker>
    implements $FrameMarkerCopyWith<$Res> {
  _$FrameMarkerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FrameMarker
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? timeMs = null,
    Object? label = null,
    Object? note = null,
    Object? color = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            timeMs: null == timeMs
                ? _value.timeMs
                : timeMs // ignore: cast_nullable_to_non_nullable
                      as int,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            note: null == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as Color,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FrameMarkerImplCopyWith<$Res>
    implements $FrameMarkerCopyWith<$Res> {
  factory _$$FrameMarkerImplCopyWith(
    _$FrameMarkerImpl value,
    $Res Function(_$FrameMarkerImpl) then,
  ) = __$$FrameMarkerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    int timeMs,
    String label,
    String note,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson) Color color,
  });
}

/// @nodoc
class __$$FrameMarkerImplCopyWithImpl<$Res>
    extends _$FrameMarkerCopyWithImpl<$Res, _$FrameMarkerImpl>
    implements _$$FrameMarkerImplCopyWith<$Res> {
  __$$FrameMarkerImplCopyWithImpl(
    _$FrameMarkerImpl _value,
    $Res Function(_$FrameMarkerImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FrameMarker
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? timeMs = null,
    Object? label = null,
    Object? note = null,
    Object? color = null,
  }) {
    return _then(
      _$FrameMarkerImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        timeMs: null == timeMs
            ? _value.timeMs
            : timeMs // ignore: cast_nullable_to_non_nullable
                  as int,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        note: null == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as Color,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FrameMarkerImpl implements _FrameMarker {
  const _$FrameMarkerImpl({
    required this.id,
    required this.timeMs,
    required this.label,
    this.note = '',
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
    required this.color,
  });

  factory _$FrameMarkerImpl.fromJson(Map<String, dynamic> json) =>
      _$$FrameMarkerImplFromJson(json);

  @override
  final String id;
  @override
  final int timeMs;
  @override
  final String label;
  @override
  @JsonKey()
  final String note;
  @override
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  final Color color;

  @override
  String toString() {
    return 'FrameMarker(id: $id, timeMs: $timeMs, label: $label, note: $note, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FrameMarkerImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.timeMs, timeMs) || other.timeMs == timeMs) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, timeMs, label, note, color);

  /// Create a copy of FrameMarker
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FrameMarkerImplCopyWith<_$FrameMarkerImpl> get copyWith =>
      __$$FrameMarkerImplCopyWithImpl<_$FrameMarkerImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FrameMarkerImplToJson(this);
  }
}

abstract class _FrameMarker implements FrameMarker {
  const factory _FrameMarker({
    required final String id,
    required final int timeMs,
    required final String label,
    final String note,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
    required final Color color,
  }) = _$FrameMarkerImpl;

  factory _FrameMarker.fromJson(Map<String, dynamic> json) =
      _$FrameMarkerImpl.fromJson;

  @override
  String get id;
  @override
  int get timeMs;
  @override
  String get label;
  @override
  String get note;
  @override
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  Color get color;

  /// Create a copy of FrameMarker
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FrameMarkerImplCopyWith<_$FrameMarkerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
