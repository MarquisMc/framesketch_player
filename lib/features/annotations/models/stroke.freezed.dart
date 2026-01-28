// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stroke.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

StrokePoint _$StrokePointFromJson(Map<String, dynamic> json) {
  return _StrokePoint.fromJson(json);
}

/// @nodoc
mixin _$StrokePoint {
  double get x => throw _privateConstructorUsedError;
  double get y => throw _privateConstructorUsedError;
  int get timestampMs => throw _privateConstructorUsedError;

  /// Serializes this StrokePoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StrokePoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StrokePointCopyWith<StrokePoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StrokePointCopyWith<$Res> {
  factory $StrokePointCopyWith(
    StrokePoint value,
    $Res Function(StrokePoint) then,
  ) = _$StrokePointCopyWithImpl<$Res, StrokePoint>;
  @useResult
  $Res call({double x, double y, int timestampMs});
}

/// @nodoc
class _$StrokePointCopyWithImpl<$Res, $Val extends StrokePoint>
    implements $StrokePointCopyWith<$Res> {
  _$StrokePointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StrokePoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? x = null, Object? y = null, Object? timestampMs = null}) {
    return _then(
      _value.copyWith(
            x: null == x
                ? _value.x
                : x // ignore: cast_nullable_to_non_nullable
                      as double,
            y: null == y
                ? _value.y
                : y // ignore: cast_nullable_to_non_nullable
                      as double,
            timestampMs: null == timestampMs
                ? _value.timestampMs
                : timestampMs // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StrokePointImplCopyWith<$Res>
    implements $StrokePointCopyWith<$Res> {
  factory _$$StrokePointImplCopyWith(
    _$StrokePointImpl value,
    $Res Function(_$StrokePointImpl) then,
  ) = __$$StrokePointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double x, double y, int timestampMs});
}

/// @nodoc
class __$$StrokePointImplCopyWithImpl<$Res>
    extends _$StrokePointCopyWithImpl<$Res, _$StrokePointImpl>
    implements _$$StrokePointImplCopyWith<$Res> {
  __$$StrokePointImplCopyWithImpl(
    _$StrokePointImpl _value,
    $Res Function(_$StrokePointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StrokePoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? x = null, Object? y = null, Object? timestampMs = null}) {
    return _then(
      _$StrokePointImpl(
        x: null == x
            ? _value.x
            : x // ignore: cast_nullable_to_non_nullable
                  as double,
        y: null == y
            ? _value.y
            : y // ignore: cast_nullable_to_non_nullable
                  as double,
        timestampMs: null == timestampMs
            ? _value.timestampMs
            : timestampMs // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StrokePointImpl implements _StrokePoint {
  const _$StrokePointImpl({
    required this.x,
    required this.y,
    this.timestampMs = 0,
  });

  factory _$StrokePointImpl.fromJson(Map<String, dynamic> json) =>
      _$$StrokePointImplFromJson(json);

  @override
  final double x;
  @override
  final double y;
  @override
  @JsonKey()
  final int timestampMs;

  @override
  String toString() {
    return 'StrokePoint(x: $x, y: $y, timestampMs: $timestampMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StrokePointImpl &&
            (identical(other.x, x) || other.x == x) &&
            (identical(other.y, y) || other.y == y) &&
            (identical(other.timestampMs, timestampMs) ||
                other.timestampMs == timestampMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, x, y, timestampMs);

  /// Create a copy of StrokePoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StrokePointImplCopyWith<_$StrokePointImpl> get copyWith =>
      __$$StrokePointImplCopyWithImpl<_$StrokePointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StrokePointImplToJson(this);
  }
}

abstract class _StrokePoint implements StrokePoint {
  const factory _StrokePoint({
    required final double x,
    required final double y,
    final int timestampMs,
  }) = _$StrokePointImpl;

  factory _StrokePoint.fromJson(Map<String, dynamic> json) =
      _$StrokePointImpl.fromJson;

  @override
  double get x;
  @override
  double get y;
  @override
  int get timestampMs;

  /// Create a copy of StrokePoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StrokePointImplCopyWith<_$StrokePointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Stroke _$StrokeFromJson(Map<String, dynamic> json) {
  return _Stroke.fromJson(json);
}

/// @nodoc
mixin _$Stroke {
  String get id => throw _privateConstructorUsedError;
  DrawingTool get tool =>
      throw _privateConstructorUsedError; // ignore: invalid_annotation_target
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  Color get color => throw _privateConstructorUsedError;
  double get strokeWidth => throw _privateConstructorUsedError;
  List<StrokePoint> get points => throw _privateConstructorUsedError;
  int get startTimeMs => throw _privateConstructorUsedError;
  int get endTimeMs => throw _privateConstructorUsedError;
  String? get text => throw _privateConstructorUsedError;
  double get fontSize => throw _privateConstructorUsedError;
  double get scale => throw _privateConstructorUsedError;

  /// Serializes this Stroke to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Stroke
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StrokeCopyWith<Stroke> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StrokeCopyWith<$Res> {
  factory $StrokeCopyWith(Stroke value, $Res Function(Stroke) then) =
      _$StrokeCopyWithImpl<$Res, Stroke>;
  @useResult
  $Res call({
    String id,
    DrawingTool tool,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson) Color color,
    double strokeWidth,
    List<StrokePoint> points,
    int startTimeMs,
    int endTimeMs,
    String? text,
    double fontSize,
    double scale,
  });
}

/// @nodoc
class _$StrokeCopyWithImpl<$Res, $Val extends Stroke>
    implements $StrokeCopyWith<$Res> {
  _$StrokeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Stroke
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tool = null,
    Object? color = null,
    Object? strokeWidth = null,
    Object? points = null,
    Object? startTimeMs = null,
    Object? endTimeMs = null,
    Object? text = freezed,
    Object? fontSize = null,
    Object? scale = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            tool: null == tool
                ? _value.tool
                : tool // ignore: cast_nullable_to_non_nullable
                      as DrawingTool,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as Color,
            strokeWidth: null == strokeWidth
                ? _value.strokeWidth
                : strokeWidth // ignore: cast_nullable_to_non_nullable
                      as double,
            points: null == points
                ? _value.points
                : points // ignore: cast_nullable_to_non_nullable
                      as List<StrokePoint>,
            startTimeMs: null == startTimeMs
                ? _value.startTimeMs
                : startTimeMs // ignore: cast_nullable_to_non_nullable
                      as int,
            endTimeMs: null == endTimeMs
                ? _value.endTimeMs
                : endTimeMs // ignore: cast_nullable_to_non_nullable
                      as int,
            text: freezed == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String?,
            fontSize: null == fontSize
                ? _value.fontSize
                : fontSize // ignore: cast_nullable_to_non_nullable
                      as double,
            scale: null == scale
                ? _value.scale
                : scale // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StrokeImplCopyWith<$Res> implements $StrokeCopyWith<$Res> {
  factory _$$StrokeImplCopyWith(
    _$StrokeImpl value,
    $Res Function(_$StrokeImpl) then,
  ) = __$$StrokeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    DrawingTool tool,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson) Color color,
    double strokeWidth,
    List<StrokePoint> points,
    int startTimeMs,
    int endTimeMs,
    String? text,
    double fontSize,
    double scale,
  });
}

/// @nodoc
class __$$StrokeImplCopyWithImpl<$Res>
    extends _$StrokeCopyWithImpl<$Res, _$StrokeImpl>
    implements _$$StrokeImplCopyWith<$Res> {
  __$$StrokeImplCopyWithImpl(
    _$StrokeImpl _value,
    $Res Function(_$StrokeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Stroke
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tool = null,
    Object? color = null,
    Object? strokeWidth = null,
    Object? points = null,
    Object? startTimeMs = null,
    Object? endTimeMs = null,
    Object? text = freezed,
    Object? fontSize = null,
    Object? scale = null,
  }) {
    return _then(
      _$StrokeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        tool: null == tool
            ? _value.tool
            : tool // ignore: cast_nullable_to_non_nullable
                  as DrawingTool,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as Color,
        strokeWidth: null == strokeWidth
            ? _value.strokeWidth
            : strokeWidth // ignore: cast_nullable_to_non_nullable
                  as double,
        points: null == points
            ? _value._points
            : points // ignore: cast_nullable_to_non_nullable
                  as List<StrokePoint>,
        startTimeMs: null == startTimeMs
            ? _value.startTimeMs
            : startTimeMs // ignore: cast_nullable_to_non_nullable
                  as int,
        endTimeMs: null == endTimeMs
            ? _value.endTimeMs
            : endTimeMs // ignore: cast_nullable_to_non_nullable
                  as int,
        text: freezed == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String?,
        fontSize: null == fontSize
            ? _value.fontSize
            : fontSize // ignore: cast_nullable_to_non_nullable
                  as double,
        scale: null == scale
            ? _value.scale
            : scale // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StrokeImpl implements _Stroke {
  const _$StrokeImpl({
    required this.id,
    required this.tool,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
    required this.color,
    required this.strokeWidth,
    required final List<StrokePoint> points,
    this.startTimeMs = 0,
    this.endTimeMs = 0,
    this.text,
    this.fontSize = 16.0,
    this.scale = 1.0,
  }) : _points = points;

  factory _$StrokeImpl.fromJson(Map<String, dynamic> json) =>
      _$$StrokeImplFromJson(json);

  @override
  final String id;
  @override
  final DrawingTool tool;
  // ignore: invalid_annotation_target
  @override
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  final Color color;
  @override
  final double strokeWidth;
  final List<StrokePoint> _points;
  @override
  List<StrokePoint> get points {
    if (_points is EqualUnmodifiableListView) return _points;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_points);
  }

  @override
  @JsonKey()
  final int startTimeMs;
  @override
  @JsonKey()
  final int endTimeMs;
  @override
  final String? text;
  @override
  @JsonKey()
  final double fontSize;
  @override
  @JsonKey()
  final double scale;

  @override
  String toString() {
    return 'Stroke(id: $id, tool: $tool, color: $color, strokeWidth: $strokeWidth, points: $points, startTimeMs: $startTimeMs, endTimeMs: $endTimeMs, text: $text, fontSize: $fontSize, scale: $scale)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StrokeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tool, tool) || other.tool == tool) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.strokeWidth, strokeWidth) ||
                other.strokeWidth == strokeWidth) &&
            const DeepCollectionEquality().equals(other._points, _points) &&
            (identical(other.startTimeMs, startTimeMs) ||
                other.startTimeMs == startTimeMs) &&
            (identical(other.endTimeMs, endTimeMs) ||
                other.endTimeMs == endTimeMs) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.scale, scale) || other.scale == scale));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tool,
    color,
    strokeWidth,
    const DeepCollectionEquality().hash(_points),
    startTimeMs,
    endTimeMs,
    text,
    fontSize,
    scale,
  );

  /// Create a copy of Stroke
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StrokeImplCopyWith<_$StrokeImpl> get copyWith =>
      __$$StrokeImplCopyWithImpl<_$StrokeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StrokeImplToJson(this);
  }
}

abstract class _Stroke implements Stroke {
  const factory _Stroke({
    required final String id,
    required final DrawingTool tool,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
    required final Color color,
    required final double strokeWidth,
    required final List<StrokePoint> points,
    final int startTimeMs,
    final int endTimeMs,
    final String? text,
    final double fontSize,
    final double scale,
  }) = _$StrokeImpl;

  factory _Stroke.fromJson(Map<String, dynamic> json) = _$StrokeImpl.fromJson;

  @override
  String get id;
  @override
  DrawingTool get tool; // ignore: invalid_annotation_target
  @override
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  Color get color;
  @override
  double get strokeWidth;
  @override
  List<StrokePoint> get points;
  @override
  int get startTimeMs;
  @override
  int get endTimeMs;
  @override
  String? get text;
  @override
  double get fontSize;
  @override
  double get scale;

  /// Create a copy of Stroke
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StrokeImplCopyWith<_$StrokeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
