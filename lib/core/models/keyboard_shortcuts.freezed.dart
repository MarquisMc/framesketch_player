// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'keyboard_shortcuts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

KeyboardShortcut _$KeyboardShortcutFromJson(Map<String, dynamic> json) {
  return _KeyboardShortcut.fromJson(json);
}

/// @nodoc
mixin _$KeyboardShortcut {
  @LogicalKeyboardKeyConverter()
  LogicalKeyboardKey get key => throw _privateConstructorUsedError;
  bool get ctrlPressed => throw _privateConstructorUsedError;
  bool get shiftPressed => throw _privateConstructorUsedError;
  bool get altPressed => throw _privateConstructorUsedError;

  /// Serializes this KeyboardShortcut to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of KeyboardShortcut
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $KeyboardShortcutCopyWith<KeyboardShortcut> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeyboardShortcutCopyWith<$Res> {
  factory $KeyboardShortcutCopyWith(
    KeyboardShortcut value,
    $Res Function(KeyboardShortcut) then,
  ) = _$KeyboardShortcutCopyWithImpl<$Res, KeyboardShortcut>;
  @useResult
  $Res call({
    @LogicalKeyboardKeyConverter() LogicalKeyboardKey key,
    bool ctrlPressed,
    bool shiftPressed,
    bool altPressed,
  });
}

/// @nodoc
class _$KeyboardShortcutCopyWithImpl<$Res, $Val extends KeyboardShortcut>
    implements $KeyboardShortcutCopyWith<$Res> {
  _$KeyboardShortcutCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of KeyboardShortcut
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? ctrlPressed = null,
    Object? shiftPressed = null,
    Object? altPressed = null,
  }) {
    return _then(
      _value.copyWith(
            key: null == key
                ? _value.key
                : key // ignore: cast_nullable_to_non_nullable
                      as LogicalKeyboardKey,
            ctrlPressed: null == ctrlPressed
                ? _value.ctrlPressed
                : ctrlPressed // ignore: cast_nullable_to_non_nullable
                      as bool,
            shiftPressed: null == shiftPressed
                ? _value.shiftPressed
                : shiftPressed // ignore: cast_nullable_to_non_nullable
                      as bool,
            altPressed: null == altPressed
                ? _value.altPressed
                : altPressed // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$KeyboardShortcutImplCopyWith<$Res>
    implements $KeyboardShortcutCopyWith<$Res> {
  factory _$$KeyboardShortcutImplCopyWith(
    _$KeyboardShortcutImpl value,
    $Res Function(_$KeyboardShortcutImpl) then,
  ) = __$$KeyboardShortcutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @LogicalKeyboardKeyConverter() LogicalKeyboardKey key,
    bool ctrlPressed,
    bool shiftPressed,
    bool altPressed,
  });
}

/// @nodoc
class __$$KeyboardShortcutImplCopyWithImpl<$Res>
    extends _$KeyboardShortcutCopyWithImpl<$Res, _$KeyboardShortcutImpl>
    implements _$$KeyboardShortcutImplCopyWith<$Res> {
  __$$KeyboardShortcutImplCopyWithImpl(
    _$KeyboardShortcutImpl _value,
    $Res Function(_$KeyboardShortcutImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of KeyboardShortcut
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? ctrlPressed = null,
    Object? shiftPressed = null,
    Object? altPressed = null,
  }) {
    return _then(
      _$KeyboardShortcutImpl(
        key: null == key
            ? _value.key
            : key // ignore: cast_nullable_to_non_nullable
                  as LogicalKeyboardKey,
        ctrlPressed: null == ctrlPressed
            ? _value.ctrlPressed
            : ctrlPressed // ignore: cast_nullable_to_non_nullable
                  as bool,
        shiftPressed: null == shiftPressed
            ? _value.shiftPressed
            : shiftPressed // ignore: cast_nullable_to_non_nullable
                  as bool,
        altPressed: null == altPressed
            ? _value.altPressed
            : altPressed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$KeyboardShortcutImpl implements _KeyboardShortcut {
  const _$KeyboardShortcutImpl({
    @LogicalKeyboardKeyConverter() required this.key,
    this.ctrlPressed = false,
    this.shiftPressed = false,
    this.altPressed = false,
  });

  factory _$KeyboardShortcutImpl.fromJson(Map<String, dynamic> json) =>
      _$$KeyboardShortcutImplFromJson(json);

  @override
  @LogicalKeyboardKeyConverter()
  final LogicalKeyboardKey key;
  @override
  @JsonKey()
  final bool ctrlPressed;
  @override
  @JsonKey()
  final bool shiftPressed;
  @override
  @JsonKey()
  final bool altPressed;

  @override
  String toString() {
    return 'KeyboardShortcut(key: $key, ctrlPressed: $ctrlPressed, shiftPressed: $shiftPressed, altPressed: $altPressed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KeyboardShortcutImpl &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.ctrlPressed, ctrlPressed) ||
                other.ctrlPressed == ctrlPressed) &&
            (identical(other.shiftPressed, shiftPressed) ||
                other.shiftPressed == shiftPressed) &&
            (identical(other.altPressed, altPressed) ||
                other.altPressed == altPressed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, key, ctrlPressed, shiftPressed, altPressed);

  /// Create a copy of KeyboardShortcut
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$KeyboardShortcutImplCopyWith<_$KeyboardShortcutImpl> get copyWith =>
      __$$KeyboardShortcutImplCopyWithImpl<_$KeyboardShortcutImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$KeyboardShortcutImplToJson(this);
  }
}

abstract class _KeyboardShortcut implements KeyboardShortcut {
  const factory _KeyboardShortcut({
    @LogicalKeyboardKeyConverter() required final LogicalKeyboardKey key,
    final bool ctrlPressed,
    final bool shiftPressed,
    final bool altPressed,
  }) = _$KeyboardShortcutImpl;

  factory _KeyboardShortcut.fromJson(Map<String, dynamic> json) =
      _$KeyboardShortcutImpl.fromJson;

  @override
  @LogicalKeyboardKeyConverter()
  LogicalKeyboardKey get key;
  @override
  bool get ctrlPressed;
  @override
  bool get shiftPressed;
  @override
  bool get altPressed;

  /// Create a copy of KeyboardShortcut
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$KeyboardShortcutImplCopyWith<_$KeyboardShortcutImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MouseShortcut _$MouseShortcutFromJson(Map<String, dynamic> json) {
  return _MouseShortcut.fromJson(json);
}

/// @nodoc
mixin _$MouseShortcut {
  MouseShortcutButton get button => throw _privateConstructorUsedError;

  /// Serializes this MouseShortcut to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MouseShortcut
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MouseShortcutCopyWith<MouseShortcut> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MouseShortcutCopyWith<$Res> {
  factory $MouseShortcutCopyWith(
    MouseShortcut value,
    $Res Function(MouseShortcut) then,
  ) = _$MouseShortcutCopyWithImpl<$Res, MouseShortcut>;
  @useResult
  $Res call({MouseShortcutButton button});
}

/// @nodoc
class _$MouseShortcutCopyWithImpl<$Res, $Val extends MouseShortcut>
    implements $MouseShortcutCopyWith<$Res> {
  _$MouseShortcutCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MouseShortcut
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? button = null}) {
    return _then(
      _value.copyWith(
            button: null == button
                ? _value.button
                : button // ignore: cast_nullable_to_non_nullable
                      as MouseShortcutButton,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MouseShortcutImplCopyWith<$Res>
    implements $MouseShortcutCopyWith<$Res> {
  factory _$$MouseShortcutImplCopyWith(
    _$MouseShortcutImpl value,
    $Res Function(_$MouseShortcutImpl) then,
  ) = __$$MouseShortcutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({MouseShortcutButton button});
}

/// @nodoc
class __$$MouseShortcutImplCopyWithImpl<$Res>
    extends _$MouseShortcutCopyWithImpl<$Res, _$MouseShortcutImpl>
    implements _$$MouseShortcutImplCopyWith<$Res> {
  __$$MouseShortcutImplCopyWithImpl(
    _$MouseShortcutImpl _value,
    $Res Function(_$MouseShortcutImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MouseShortcut
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? button = null}) {
    return _then(
      _$MouseShortcutImpl(
        button: null == button
            ? _value.button
            : button // ignore: cast_nullable_to_non_nullable
                  as MouseShortcutButton,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MouseShortcutImpl implements _MouseShortcut {
  const _$MouseShortcutImpl({this.button = MouseShortcutButton.middle});

  factory _$MouseShortcutImpl.fromJson(Map<String, dynamic> json) =>
      _$$MouseShortcutImplFromJson(json);

  @override
  @JsonKey()
  final MouseShortcutButton button;

  @override
  String toString() {
    return 'MouseShortcut(button: $button)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MouseShortcutImpl &&
            (identical(other.button, button) || other.button == button));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, button);

  /// Create a copy of MouseShortcut
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MouseShortcutImplCopyWith<_$MouseShortcutImpl> get copyWith =>
      __$$MouseShortcutImplCopyWithImpl<_$MouseShortcutImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MouseShortcutImplToJson(this);
  }
}

abstract class _MouseShortcut implements MouseShortcut {
  const factory _MouseShortcut({final MouseShortcutButton button}) =
      _$MouseShortcutImpl;

  factory _MouseShortcut.fromJson(Map<String, dynamic> json) =
      _$MouseShortcutImpl.fromJson;

  @override
  MouseShortcutButton get button;

  /// Create a copy of MouseShortcut
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MouseShortcutImplCopyWith<_$MouseShortcutImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

KeyboardShortcuts _$KeyboardShortcutsFromJson(Map<String, dynamic> json) {
  return _KeyboardShortcuts.fromJson(json);
}

/// @nodoc
mixin _$KeyboardShortcuts {
  KeyboardShortcut get nextFrame => throw _privateConstructorUsedError;
  KeyboardShortcut get previousFrame => throw _privateConstructorUsedError;
  KeyboardShortcut get playPause => throw _privateConstructorUsedError;
  KeyboardShortcut get jumpForward => throw _privateConstructorUsedError;
  KeyboardShortcut get jumpBackward => throw _privateConstructorUsedError;
  KeyboardShortcut get toggleFullscreen => throw _privateConstructorUsedError;
  MouseShortcut get panZoomedView => throw _privateConstructorUsedError;
  KeyboardShortcut get openCommandPalette => throw _privateConstructorUsedError;
  KeyboardShortcut get openFile => throw _privateConstructorUsedError;
  KeyboardShortcut get saveAnnotations => throw _privateConstructorUsedError;
  KeyboardShortcut get undo => throw _privateConstructorUsedError;
  KeyboardShortcut get redo => throw _privateConstructorUsedError;
  KeyboardShortcut get addMarker => throw _privateConstructorUsedError;
  KeyboardShortcut get nextMarker => throw _privateConstructorUsedError;
  KeyboardShortcut get previousMarker =>
      throw _privateConstructorUsedError; // Annotation tools
  KeyboardShortcut get selectSelectionTool =>
      throw _privateConstructorUsedError;
  KeyboardShortcut get selectPenTool => throw _privateConstructorUsedError;
  KeyboardShortcut get selectEraserTool => throw _privateConstructorUsedError;
  KeyboardShortcut get selectRectangleTool =>
      throw _privateConstructorUsedError;
  KeyboardShortcut get selectCircleTool => throw _privateConstructorUsedError;
  KeyboardShortcut get selectLineTool => throw _privateConstructorUsedError;
  KeyboardShortcut get selectArrowTool => throw _privateConstructorUsedError;
  KeyboardShortcut get selectTextTool => throw _privateConstructorUsedError;
  KeyboardShortcut get toggleKeyframeMode => throw _privateConstructorUsedError;
  KeyboardShortcut get createManualKeyframe =>
      throw _privateConstructorUsedError; // Loop shortcuts
  KeyboardShortcut get toggleFullLoop => throw _privateConstructorUsedError;
  KeyboardShortcut get setLoopStart => throw _privateConstructorUsedError;
  KeyboardShortcut get setLoopEnd => throw _privateConstructorUsedError;
  KeyboardShortcut get toggleSectionLoop =>
      throw _privateConstructorUsedError; // Crop shortcuts
  KeyboardShortcut get toggleCropMode =>
      throw _privateConstructorUsedError; // Group enable/disable toggles
  bool get generalShortcutsEnabled => throw _privateConstructorUsedError;
  bool get annotationToolsShortcutsEnabled =>
      throw _privateConstructorUsedError;
  bool get loopControlsShortcutsEnabled => throw _privateConstructorUsedError;
  bool get cropControlsShortcutsEnabled => throw _privateConstructorUsedError;

  /// Serializes this KeyboardShortcuts to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $KeyboardShortcutsCopyWith<KeyboardShortcuts> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeyboardShortcutsCopyWith<$Res> {
  factory $KeyboardShortcutsCopyWith(
    KeyboardShortcuts value,
    $Res Function(KeyboardShortcuts) then,
  ) = _$KeyboardShortcutsCopyWithImpl<$Res, KeyboardShortcuts>;
  @useResult
  $Res call({
    KeyboardShortcut nextFrame,
    KeyboardShortcut previousFrame,
    KeyboardShortcut playPause,
    KeyboardShortcut jumpForward,
    KeyboardShortcut jumpBackward,
    KeyboardShortcut toggleFullscreen,
    MouseShortcut panZoomedView,
    KeyboardShortcut openCommandPalette,
    KeyboardShortcut openFile,
    KeyboardShortcut saveAnnotations,
    KeyboardShortcut undo,
    KeyboardShortcut redo,
    KeyboardShortcut addMarker,
    KeyboardShortcut nextMarker,
    KeyboardShortcut previousMarker,
    KeyboardShortcut selectSelectionTool,
    KeyboardShortcut selectPenTool,
    KeyboardShortcut selectEraserTool,
    KeyboardShortcut selectRectangleTool,
    KeyboardShortcut selectCircleTool,
    KeyboardShortcut selectLineTool,
    KeyboardShortcut selectArrowTool,
    KeyboardShortcut selectTextTool,
    KeyboardShortcut toggleKeyframeMode,
    KeyboardShortcut createManualKeyframe,
    KeyboardShortcut toggleFullLoop,
    KeyboardShortcut setLoopStart,
    KeyboardShortcut setLoopEnd,
    KeyboardShortcut toggleSectionLoop,
    KeyboardShortcut toggleCropMode,
    bool generalShortcutsEnabled,
    bool annotationToolsShortcutsEnabled,
    bool loopControlsShortcutsEnabled,
    bool cropControlsShortcutsEnabled,
  });

  $KeyboardShortcutCopyWith<$Res> get nextFrame;
  $KeyboardShortcutCopyWith<$Res> get previousFrame;
  $KeyboardShortcutCopyWith<$Res> get playPause;
  $KeyboardShortcutCopyWith<$Res> get jumpForward;
  $KeyboardShortcutCopyWith<$Res> get jumpBackward;
  $KeyboardShortcutCopyWith<$Res> get toggleFullscreen;
  $MouseShortcutCopyWith<$Res> get panZoomedView;
  $KeyboardShortcutCopyWith<$Res> get openCommandPalette;
  $KeyboardShortcutCopyWith<$Res> get openFile;
  $KeyboardShortcutCopyWith<$Res> get saveAnnotations;
  $KeyboardShortcutCopyWith<$Res> get undo;
  $KeyboardShortcutCopyWith<$Res> get redo;
  $KeyboardShortcutCopyWith<$Res> get addMarker;
  $KeyboardShortcutCopyWith<$Res> get nextMarker;
  $KeyboardShortcutCopyWith<$Res> get previousMarker;
  $KeyboardShortcutCopyWith<$Res> get selectSelectionTool;
  $KeyboardShortcutCopyWith<$Res> get selectPenTool;
  $KeyboardShortcutCopyWith<$Res> get selectEraserTool;
  $KeyboardShortcutCopyWith<$Res> get selectRectangleTool;
  $KeyboardShortcutCopyWith<$Res> get selectCircleTool;
  $KeyboardShortcutCopyWith<$Res> get selectLineTool;
  $KeyboardShortcutCopyWith<$Res> get selectArrowTool;
  $KeyboardShortcutCopyWith<$Res> get selectTextTool;
  $KeyboardShortcutCopyWith<$Res> get toggleKeyframeMode;
  $KeyboardShortcutCopyWith<$Res> get createManualKeyframe;
  $KeyboardShortcutCopyWith<$Res> get toggleFullLoop;
  $KeyboardShortcutCopyWith<$Res> get setLoopStart;
  $KeyboardShortcutCopyWith<$Res> get setLoopEnd;
  $KeyboardShortcutCopyWith<$Res> get toggleSectionLoop;
  $KeyboardShortcutCopyWith<$Res> get toggleCropMode;
}

/// @nodoc
class _$KeyboardShortcutsCopyWithImpl<$Res, $Val extends KeyboardShortcuts>
    implements $KeyboardShortcutsCopyWith<$Res> {
  _$KeyboardShortcutsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nextFrame = null,
    Object? previousFrame = null,
    Object? playPause = null,
    Object? jumpForward = null,
    Object? jumpBackward = null,
    Object? toggleFullscreen = null,
    Object? panZoomedView = null,
    Object? openCommandPalette = null,
    Object? openFile = null,
    Object? saveAnnotations = null,
    Object? undo = null,
    Object? redo = null,
    Object? addMarker = null,
    Object? nextMarker = null,
    Object? previousMarker = null,
    Object? selectSelectionTool = null,
    Object? selectPenTool = null,
    Object? selectEraserTool = null,
    Object? selectRectangleTool = null,
    Object? selectCircleTool = null,
    Object? selectLineTool = null,
    Object? selectArrowTool = null,
    Object? selectTextTool = null,
    Object? toggleKeyframeMode = null,
    Object? createManualKeyframe = null,
    Object? toggleFullLoop = null,
    Object? setLoopStart = null,
    Object? setLoopEnd = null,
    Object? toggleSectionLoop = null,
    Object? toggleCropMode = null,
    Object? generalShortcutsEnabled = null,
    Object? annotationToolsShortcutsEnabled = null,
    Object? loopControlsShortcutsEnabled = null,
    Object? cropControlsShortcutsEnabled = null,
  }) {
    return _then(
      _value.copyWith(
            nextFrame: null == nextFrame
                ? _value.nextFrame
                : nextFrame // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            previousFrame: null == previousFrame
                ? _value.previousFrame
                : previousFrame // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            playPause: null == playPause
                ? _value.playPause
                : playPause // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            jumpForward: null == jumpForward
                ? _value.jumpForward
                : jumpForward // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            jumpBackward: null == jumpBackward
                ? _value.jumpBackward
                : jumpBackward // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            toggleFullscreen: null == toggleFullscreen
                ? _value.toggleFullscreen
                : toggleFullscreen // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            panZoomedView: null == panZoomedView
                ? _value.panZoomedView
                : panZoomedView // ignore: cast_nullable_to_non_nullable
                      as MouseShortcut,
            openCommandPalette: null == openCommandPalette
                ? _value.openCommandPalette
                : openCommandPalette // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            openFile: null == openFile
                ? _value.openFile
                : openFile // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            saveAnnotations: null == saveAnnotations
                ? _value.saveAnnotations
                : saveAnnotations // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            undo: null == undo
                ? _value.undo
                : undo // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            redo: null == redo
                ? _value.redo
                : redo // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            addMarker: null == addMarker
                ? _value.addMarker
                : addMarker // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            nextMarker: null == nextMarker
                ? _value.nextMarker
                : nextMarker // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            previousMarker: null == previousMarker
                ? _value.previousMarker
                : previousMarker // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectSelectionTool: null == selectSelectionTool
                ? _value.selectSelectionTool
                : selectSelectionTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectPenTool: null == selectPenTool
                ? _value.selectPenTool
                : selectPenTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectEraserTool: null == selectEraserTool
                ? _value.selectEraserTool
                : selectEraserTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectRectangleTool: null == selectRectangleTool
                ? _value.selectRectangleTool
                : selectRectangleTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectCircleTool: null == selectCircleTool
                ? _value.selectCircleTool
                : selectCircleTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectLineTool: null == selectLineTool
                ? _value.selectLineTool
                : selectLineTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectArrowTool: null == selectArrowTool
                ? _value.selectArrowTool
                : selectArrowTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            selectTextTool: null == selectTextTool
                ? _value.selectTextTool
                : selectTextTool // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            toggleKeyframeMode: null == toggleKeyframeMode
                ? _value.toggleKeyframeMode
                : toggleKeyframeMode // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            createManualKeyframe: null == createManualKeyframe
                ? _value.createManualKeyframe
                : createManualKeyframe // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            toggleFullLoop: null == toggleFullLoop
                ? _value.toggleFullLoop
                : toggleFullLoop // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            setLoopStart: null == setLoopStart
                ? _value.setLoopStart
                : setLoopStart // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            setLoopEnd: null == setLoopEnd
                ? _value.setLoopEnd
                : setLoopEnd // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            toggleSectionLoop: null == toggleSectionLoop
                ? _value.toggleSectionLoop
                : toggleSectionLoop // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            toggleCropMode: null == toggleCropMode
                ? _value.toggleCropMode
                : toggleCropMode // ignore: cast_nullable_to_non_nullable
                      as KeyboardShortcut,
            generalShortcutsEnabled: null == generalShortcutsEnabled
                ? _value.generalShortcutsEnabled
                : generalShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            annotationToolsShortcutsEnabled:
                null == annotationToolsShortcutsEnabled
                ? _value.annotationToolsShortcutsEnabled
                : annotationToolsShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            loopControlsShortcutsEnabled: null == loopControlsShortcutsEnabled
                ? _value.loopControlsShortcutsEnabled
                : loopControlsShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            cropControlsShortcutsEnabled: null == cropControlsShortcutsEnabled
                ? _value.cropControlsShortcutsEnabled
                : cropControlsShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get nextFrame {
    return $KeyboardShortcutCopyWith<$Res>(_value.nextFrame, (value) {
      return _then(_value.copyWith(nextFrame: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get previousFrame {
    return $KeyboardShortcutCopyWith<$Res>(_value.previousFrame, (value) {
      return _then(_value.copyWith(previousFrame: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get playPause {
    return $KeyboardShortcutCopyWith<$Res>(_value.playPause, (value) {
      return _then(_value.copyWith(playPause: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get jumpForward {
    return $KeyboardShortcutCopyWith<$Res>(_value.jumpForward, (value) {
      return _then(_value.copyWith(jumpForward: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get jumpBackward {
    return $KeyboardShortcutCopyWith<$Res>(_value.jumpBackward, (value) {
      return _then(_value.copyWith(jumpBackward: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get toggleFullscreen {
    return $KeyboardShortcutCopyWith<$Res>(_value.toggleFullscreen, (value) {
      return _then(_value.copyWith(toggleFullscreen: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MouseShortcutCopyWith<$Res> get panZoomedView {
    return $MouseShortcutCopyWith<$Res>(_value.panZoomedView, (value) {
      return _then(_value.copyWith(panZoomedView: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get openCommandPalette {
    return $KeyboardShortcutCopyWith<$Res>(_value.openCommandPalette, (value) {
      return _then(_value.copyWith(openCommandPalette: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get openFile {
    return $KeyboardShortcutCopyWith<$Res>(_value.openFile, (value) {
      return _then(_value.copyWith(openFile: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get saveAnnotations {
    return $KeyboardShortcutCopyWith<$Res>(_value.saveAnnotations, (value) {
      return _then(_value.copyWith(saveAnnotations: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get undo {
    return $KeyboardShortcutCopyWith<$Res>(_value.undo, (value) {
      return _then(_value.copyWith(undo: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get redo {
    return $KeyboardShortcutCopyWith<$Res>(_value.redo, (value) {
      return _then(_value.copyWith(redo: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get addMarker {
    return $KeyboardShortcutCopyWith<$Res>(_value.addMarker, (value) {
      return _then(_value.copyWith(addMarker: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get nextMarker {
    return $KeyboardShortcutCopyWith<$Res>(_value.nextMarker, (value) {
      return _then(_value.copyWith(nextMarker: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get previousMarker {
    return $KeyboardShortcutCopyWith<$Res>(_value.previousMarker, (value) {
      return _then(_value.copyWith(previousMarker: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectSelectionTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectSelectionTool, (value) {
      return _then(_value.copyWith(selectSelectionTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectPenTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectPenTool, (value) {
      return _then(_value.copyWith(selectPenTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectEraserTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectEraserTool, (value) {
      return _then(_value.copyWith(selectEraserTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectRectangleTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectRectangleTool, (value) {
      return _then(_value.copyWith(selectRectangleTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectCircleTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectCircleTool, (value) {
      return _then(_value.copyWith(selectCircleTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectLineTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectLineTool, (value) {
      return _then(_value.copyWith(selectLineTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectArrowTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectArrowTool, (value) {
      return _then(_value.copyWith(selectArrowTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get selectTextTool {
    return $KeyboardShortcutCopyWith<$Res>(_value.selectTextTool, (value) {
      return _then(_value.copyWith(selectTextTool: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get toggleKeyframeMode {
    return $KeyboardShortcutCopyWith<$Res>(_value.toggleKeyframeMode, (value) {
      return _then(_value.copyWith(toggleKeyframeMode: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get createManualKeyframe {
    return $KeyboardShortcutCopyWith<$Res>(_value.createManualKeyframe, (
      value,
    ) {
      return _then(_value.copyWith(createManualKeyframe: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get toggleFullLoop {
    return $KeyboardShortcutCopyWith<$Res>(_value.toggleFullLoop, (value) {
      return _then(_value.copyWith(toggleFullLoop: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get setLoopStart {
    return $KeyboardShortcutCopyWith<$Res>(_value.setLoopStart, (value) {
      return _then(_value.copyWith(setLoopStart: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get setLoopEnd {
    return $KeyboardShortcutCopyWith<$Res>(_value.setLoopEnd, (value) {
      return _then(_value.copyWith(setLoopEnd: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get toggleSectionLoop {
    return $KeyboardShortcutCopyWith<$Res>(_value.toggleSectionLoop, (value) {
      return _then(_value.copyWith(toggleSectionLoop: value) as $Val);
    });
  }

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyboardShortcutCopyWith<$Res> get toggleCropMode {
    return $KeyboardShortcutCopyWith<$Res>(_value.toggleCropMode, (value) {
      return _then(_value.copyWith(toggleCropMode: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$KeyboardShortcutsImplCopyWith<$Res>
    implements $KeyboardShortcutsCopyWith<$Res> {
  factory _$$KeyboardShortcutsImplCopyWith(
    _$KeyboardShortcutsImpl value,
    $Res Function(_$KeyboardShortcutsImpl) then,
  ) = __$$KeyboardShortcutsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    KeyboardShortcut nextFrame,
    KeyboardShortcut previousFrame,
    KeyboardShortcut playPause,
    KeyboardShortcut jumpForward,
    KeyboardShortcut jumpBackward,
    KeyboardShortcut toggleFullscreen,
    MouseShortcut panZoomedView,
    KeyboardShortcut openCommandPalette,
    KeyboardShortcut openFile,
    KeyboardShortcut saveAnnotations,
    KeyboardShortcut undo,
    KeyboardShortcut redo,
    KeyboardShortcut addMarker,
    KeyboardShortcut nextMarker,
    KeyboardShortcut previousMarker,
    KeyboardShortcut selectSelectionTool,
    KeyboardShortcut selectPenTool,
    KeyboardShortcut selectEraserTool,
    KeyboardShortcut selectRectangleTool,
    KeyboardShortcut selectCircleTool,
    KeyboardShortcut selectLineTool,
    KeyboardShortcut selectArrowTool,
    KeyboardShortcut selectTextTool,
    KeyboardShortcut toggleKeyframeMode,
    KeyboardShortcut createManualKeyframe,
    KeyboardShortcut toggleFullLoop,
    KeyboardShortcut setLoopStart,
    KeyboardShortcut setLoopEnd,
    KeyboardShortcut toggleSectionLoop,
    KeyboardShortcut toggleCropMode,
    bool generalShortcutsEnabled,
    bool annotationToolsShortcutsEnabled,
    bool loopControlsShortcutsEnabled,
    bool cropControlsShortcutsEnabled,
  });

  @override
  $KeyboardShortcutCopyWith<$Res> get nextFrame;
  @override
  $KeyboardShortcutCopyWith<$Res> get previousFrame;
  @override
  $KeyboardShortcutCopyWith<$Res> get playPause;
  @override
  $KeyboardShortcutCopyWith<$Res> get jumpForward;
  @override
  $KeyboardShortcutCopyWith<$Res> get jumpBackward;
  @override
  $KeyboardShortcutCopyWith<$Res> get toggleFullscreen;
  @override
  $MouseShortcutCopyWith<$Res> get panZoomedView;
  @override
  $KeyboardShortcutCopyWith<$Res> get openCommandPalette;
  @override
  $KeyboardShortcutCopyWith<$Res> get openFile;
  @override
  $KeyboardShortcutCopyWith<$Res> get saveAnnotations;
  @override
  $KeyboardShortcutCopyWith<$Res> get undo;
  @override
  $KeyboardShortcutCopyWith<$Res> get redo;
  @override
  $KeyboardShortcutCopyWith<$Res> get addMarker;
  @override
  $KeyboardShortcutCopyWith<$Res> get nextMarker;
  @override
  $KeyboardShortcutCopyWith<$Res> get previousMarker;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectSelectionTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectPenTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectEraserTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectRectangleTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectCircleTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectLineTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectArrowTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get selectTextTool;
  @override
  $KeyboardShortcutCopyWith<$Res> get toggleKeyframeMode;
  @override
  $KeyboardShortcutCopyWith<$Res> get createManualKeyframe;
  @override
  $KeyboardShortcutCopyWith<$Res> get toggleFullLoop;
  @override
  $KeyboardShortcutCopyWith<$Res> get setLoopStart;
  @override
  $KeyboardShortcutCopyWith<$Res> get setLoopEnd;
  @override
  $KeyboardShortcutCopyWith<$Res> get toggleSectionLoop;
  @override
  $KeyboardShortcutCopyWith<$Res> get toggleCropMode;
}

/// @nodoc
class __$$KeyboardShortcutsImplCopyWithImpl<$Res>
    extends _$KeyboardShortcutsCopyWithImpl<$Res, _$KeyboardShortcutsImpl>
    implements _$$KeyboardShortcutsImplCopyWith<$Res> {
  __$$KeyboardShortcutsImplCopyWithImpl(
    _$KeyboardShortcutsImpl _value,
    $Res Function(_$KeyboardShortcutsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nextFrame = null,
    Object? previousFrame = null,
    Object? playPause = null,
    Object? jumpForward = null,
    Object? jumpBackward = null,
    Object? toggleFullscreen = null,
    Object? panZoomedView = null,
    Object? openCommandPalette = null,
    Object? openFile = null,
    Object? saveAnnotations = null,
    Object? undo = null,
    Object? redo = null,
    Object? addMarker = null,
    Object? nextMarker = null,
    Object? previousMarker = null,
    Object? selectSelectionTool = null,
    Object? selectPenTool = null,
    Object? selectEraserTool = null,
    Object? selectRectangleTool = null,
    Object? selectCircleTool = null,
    Object? selectLineTool = null,
    Object? selectArrowTool = null,
    Object? selectTextTool = null,
    Object? toggleKeyframeMode = null,
    Object? createManualKeyframe = null,
    Object? toggleFullLoop = null,
    Object? setLoopStart = null,
    Object? setLoopEnd = null,
    Object? toggleSectionLoop = null,
    Object? toggleCropMode = null,
    Object? generalShortcutsEnabled = null,
    Object? annotationToolsShortcutsEnabled = null,
    Object? loopControlsShortcutsEnabled = null,
    Object? cropControlsShortcutsEnabled = null,
  }) {
    return _then(
      _$KeyboardShortcutsImpl(
        nextFrame: null == nextFrame
            ? _value.nextFrame
            : nextFrame // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        previousFrame: null == previousFrame
            ? _value.previousFrame
            : previousFrame // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        playPause: null == playPause
            ? _value.playPause
            : playPause // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        jumpForward: null == jumpForward
            ? _value.jumpForward
            : jumpForward // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        jumpBackward: null == jumpBackward
            ? _value.jumpBackward
            : jumpBackward // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        toggleFullscreen: null == toggleFullscreen
            ? _value.toggleFullscreen
            : toggleFullscreen // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        panZoomedView: null == panZoomedView
            ? _value.panZoomedView
            : panZoomedView // ignore: cast_nullable_to_non_nullable
                  as MouseShortcut,
        openCommandPalette: null == openCommandPalette
            ? _value.openCommandPalette
            : openCommandPalette // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        openFile: null == openFile
            ? _value.openFile
            : openFile // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        saveAnnotations: null == saveAnnotations
            ? _value.saveAnnotations
            : saveAnnotations // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        undo: null == undo
            ? _value.undo
            : undo // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        redo: null == redo
            ? _value.redo
            : redo // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        addMarker: null == addMarker
            ? _value.addMarker
            : addMarker // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        nextMarker: null == nextMarker
            ? _value.nextMarker
            : nextMarker // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        previousMarker: null == previousMarker
            ? _value.previousMarker
            : previousMarker // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectSelectionTool: null == selectSelectionTool
            ? _value.selectSelectionTool
            : selectSelectionTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectPenTool: null == selectPenTool
            ? _value.selectPenTool
            : selectPenTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectEraserTool: null == selectEraserTool
            ? _value.selectEraserTool
            : selectEraserTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectRectangleTool: null == selectRectangleTool
            ? _value.selectRectangleTool
            : selectRectangleTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectCircleTool: null == selectCircleTool
            ? _value.selectCircleTool
            : selectCircleTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectLineTool: null == selectLineTool
            ? _value.selectLineTool
            : selectLineTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectArrowTool: null == selectArrowTool
            ? _value.selectArrowTool
            : selectArrowTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        selectTextTool: null == selectTextTool
            ? _value.selectTextTool
            : selectTextTool // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        toggleKeyframeMode: null == toggleKeyframeMode
            ? _value.toggleKeyframeMode
            : toggleKeyframeMode // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        createManualKeyframe: null == createManualKeyframe
            ? _value.createManualKeyframe
            : createManualKeyframe // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        toggleFullLoop: null == toggleFullLoop
            ? _value.toggleFullLoop
            : toggleFullLoop // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        setLoopStart: null == setLoopStart
            ? _value.setLoopStart
            : setLoopStart // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        setLoopEnd: null == setLoopEnd
            ? _value.setLoopEnd
            : setLoopEnd // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        toggleSectionLoop: null == toggleSectionLoop
            ? _value.toggleSectionLoop
            : toggleSectionLoop // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        toggleCropMode: null == toggleCropMode
            ? _value.toggleCropMode
            : toggleCropMode // ignore: cast_nullable_to_non_nullable
                  as KeyboardShortcut,
        generalShortcutsEnabled: null == generalShortcutsEnabled
            ? _value.generalShortcutsEnabled
            : generalShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        annotationToolsShortcutsEnabled: null == annotationToolsShortcutsEnabled
            ? _value.annotationToolsShortcutsEnabled
            : annotationToolsShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        loopControlsShortcutsEnabled: null == loopControlsShortcutsEnabled
            ? _value.loopControlsShortcutsEnabled
            : loopControlsShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        cropControlsShortcutsEnabled: null == cropControlsShortcutsEnabled
            ? _value.cropControlsShortcutsEnabled
            : cropControlsShortcutsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$KeyboardShortcutsImpl implements _KeyboardShortcuts {
  const _$KeyboardShortcutsImpl({
    required this.nextFrame,
    required this.previousFrame,
    required this.playPause,
    required this.jumpForward,
    required this.jumpBackward,
    this.toggleFullscreen = const KeyboardShortcut(key: LogicalKeyboardKey.f11),
    this.panZoomedView = const MouseShortcut(),
    this.openCommandPalette = const KeyboardShortcut(
      key: LogicalKeyboardKey.keyP,
      ctrlPressed: true,
      shiftPressed: true,
    ),
    required this.openFile,
    required this.saveAnnotations,
    required this.undo,
    required this.redo,
    this.addMarker = const KeyboardShortcut(
      key: LogicalKeyboardKey.keyB,
      ctrlPressed: true,
    ),
    required this.nextMarker,
    required this.previousMarker,
    required this.selectSelectionTool,
    required this.selectPenTool,
    required this.selectEraserTool,
    required this.selectRectangleTool,
    required this.selectCircleTool,
    required this.selectLineTool,
    required this.selectArrowTool,
    required this.selectTextTool,
    required this.toggleKeyframeMode,
    required this.createManualKeyframe,
    required this.toggleFullLoop,
    required this.setLoopStart,
    required this.setLoopEnd,
    required this.toggleSectionLoop,
    required this.toggleCropMode,
    this.generalShortcutsEnabled = true,
    this.annotationToolsShortcutsEnabled = true,
    this.loopControlsShortcutsEnabled = true,
    this.cropControlsShortcutsEnabled = true,
  });

  factory _$KeyboardShortcutsImpl.fromJson(Map<String, dynamic> json) =>
      _$$KeyboardShortcutsImplFromJson(json);

  @override
  final KeyboardShortcut nextFrame;
  @override
  final KeyboardShortcut previousFrame;
  @override
  final KeyboardShortcut playPause;
  @override
  final KeyboardShortcut jumpForward;
  @override
  final KeyboardShortcut jumpBackward;
  @override
  @JsonKey()
  final KeyboardShortcut toggleFullscreen;
  @override
  @JsonKey()
  final MouseShortcut panZoomedView;
  @override
  @JsonKey()
  final KeyboardShortcut openCommandPalette;
  @override
  final KeyboardShortcut openFile;
  @override
  final KeyboardShortcut saveAnnotations;
  @override
  final KeyboardShortcut undo;
  @override
  final KeyboardShortcut redo;
  @override
  @JsonKey()
  final KeyboardShortcut addMarker;
  @override
  final KeyboardShortcut nextMarker;
  @override
  final KeyboardShortcut previousMarker;
  // Annotation tools
  @override
  final KeyboardShortcut selectSelectionTool;
  @override
  final KeyboardShortcut selectPenTool;
  @override
  final KeyboardShortcut selectEraserTool;
  @override
  final KeyboardShortcut selectRectangleTool;
  @override
  final KeyboardShortcut selectCircleTool;
  @override
  final KeyboardShortcut selectLineTool;
  @override
  final KeyboardShortcut selectArrowTool;
  @override
  final KeyboardShortcut selectTextTool;
  @override
  final KeyboardShortcut toggleKeyframeMode;
  @override
  final KeyboardShortcut createManualKeyframe;
  // Loop shortcuts
  @override
  final KeyboardShortcut toggleFullLoop;
  @override
  final KeyboardShortcut setLoopStart;
  @override
  final KeyboardShortcut setLoopEnd;
  @override
  final KeyboardShortcut toggleSectionLoop;
  // Crop shortcuts
  @override
  final KeyboardShortcut toggleCropMode;
  // Group enable/disable toggles
  @override
  @JsonKey()
  final bool generalShortcutsEnabled;
  @override
  @JsonKey()
  final bool annotationToolsShortcutsEnabled;
  @override
  @JsonKey()
  final bool loopControlsShortcutsEnabled;
  @override
  @JsonKey()
  final bool cropControlsShortcutsEnabled;

  @override
  String toString() {
    return 'KeyboardShortcuts(nextFrame: $nextFrame, previousFrame: $previousFrame, playPause: $playPause, jumpForward: $jumpForward, jumpBackward: $jumpBackward, toggleFullscreen: $toggleFullscreen, panZoomedView: $panZoomedView, openCommandPalette: $openCommandPalette, openFile: $openFile, saveAnnotations: $saveAnnotations, undo: $undo, redo: $redo, addMarker: $addMarker, nextMarker: $nextMarker, previousMarker: $previousMarker, selectSelectionTool: $selectSelectionTool, selectPenTool: $selectPenTool, selectEraserTool: $selectEraserTool, selectRectangleTool: $selectRectangleTool, selectCircleTool: $selectCircleTool, selectLineTool: $selectLineTool, selectArrowTool: $selectArrowTool, selectTextTool: $selectTextTool, toggleKeyframeMode: $toggleKeyframeMode, createManualKeyframe: $createManualKeyframe, toggleFullLoop: $toggleFullLoop, setLoopStart: $setLoopStart, setLoopEnd: $setLoopEnd, toggleSectionLoop: $toggleSectionLoop, toggleCropMode: $toggleCropMode, generalShortcutsEnabled: $generalShortcutsEnabled, annotationToolsShortcutsEnabled: $annotationToolsShortcutsEnabled, loopControlsShortcutsEnabled: $loopControlsShortcutsEnabled, cropControlsShortcutsEnabled: $cropControlsShortcutsEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KeyboardShortcutsImpl &&
            (identical(other.nextFrame, nextFrame) ||
                other.nextFrame == nextFrame) &&
            (identical(other.previousFrame, previousFrame) ||
                other.previousFrame == previousFrame) &&
            (identical(other.playPause, playPause) ||
                other.playPause == playPause) &&
            (identical(other.jumpForward, jumpForward) ||
                other.jumpForward == jumpForward) &&
            (identical(other.jumpBackward, jumpBackward) ||
                other.jumpBackward == jumpBackward) &&
            (identical(other.toggleFullscreen, toggleFullscreen) ||
                other.toggleFullscreen == toggleFullscreen) &&
            (identical(other.panZoomedView, panZoomedView) ||
                other.panZoomedView == panZoomedView) &&
            (identical(other.openCommandPalette, openCommandPalette) ||
                other.openCommandPalette == openCommandPalette) &&
            (identical(other.openFile, openFile) ||
                other.openFile == openFile) &&
            (identical(other.saveAnnotations, saveAnnotations) ||
                other.saveAnnotations == saveAnnotations) &&
            (identical(other.undo, undo) || other.undo == undo) &&
            (identical(other.redo, redo) || other.redo == redo) &&
            (identical(other.addMarker, addMarker) ||
                other.addMarker == addMarker) &&
            (identical(other.nextMarker, nextMarker) ||
                other.nextMarker == nextMarker) &&
            (identical(other.previousMarker, previousMarker) ||
                other.previousMarker == previousMarker) &&
            (identical(other.selectSelectionTool, selectSelectionTool) ||
                other.selectSelectionTool == selectSelectionTool) &&
            (identical(other.selectPenTool, selectPenTool) ||
                other.selectPenTool == selectPenTool) &&
            (identical(other.selectEraserTool, selectEraserTool) ||
                other.selectEraserTool == selectEraserTool) &&
            (identical(other.selectRectangleTool, selectRectangleTool) ||
                other.selectRectangleTool == selectRectangleTool) &&
            (identical(other.selectCircleTool, selectCircleTool) ||
                other.selectCircleTool == selectCircleTool) &&
            (identical(other.selectLineTool, selectLineTool) ||
                other.selectLineTool == selectLineTool) &&
            (identical(other.selectArrowTool, selectArrowTool) ||
                other.selectArrowTool == selectArrowTool) &&
            (identical(other.selectTextTool, selectTextTool) ||
                other.selectTextTool == selectTextTool) &&
            (identical(other.toggleKeyframeMode, toggleKeyframeMode) ||
                other.toggleKeyframeMode == toggleKeyframeMode) &&
            (identical(other.createManualKeyframe, createManualKeyframe) ||
                other.createManualKeyframe == createManualKeyframe) &&
            (identical(other.toggleFullLoop, toggleFullLoop) ||
                other.toggleFullLoop == toggleFullLoop) &&
            (identical(other.setLoopStart, setLoopStart) ||
                other.setLoopStart == setLoopStart) &&
            (identical(other.setLoopEnd, setLoopEnd) ||
                other.setLoopEnd == setLoopEnd) &&
            (identical(other.toggleSectionLoop, toggleSectionLoop) ||
                other.toggleSectionLoop == toggleSectionLoop) &&
            (identical(other.toggleCropMode, toggleCropMode) ||
                other.toggleCropMode == toggleCropMode) &&
            (identical(
                  other.generalShortcutsEnabled,
                  generalShortcutsEnabled,
                ) ||
                other.generalShortcutsEnabled == generalShortcutsEnabled) &&
            (identical(
                  other.annotationToolsShortcutsEnabled,
                  annotationToolsShortcutsEnabled,
                ) ||
                other.annotationToolsShortcutsEnabled ==
                    annotationToolsShortcutsEnabled) &&
            (identical(
                  other.loopControlsShortcutsEnabled,
                  loopControlsShortcutsEnabled,
                ) ||
                other.loopControlsShortcutsEnabled ==
                    loopControlsShortcutsEnabled) &&
            (identical(
                  other.cropControlsShortcutsEnabled,
                  cropControlsShortcutsEnabled,
                ) ||
                other.cropControlsShortcutsEnabled ==
                    cropControlsShortcutsEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    nextFrame,
    previousFrame,
    playPause,
    jumpForward,
    jumpBackward,
    toggleFullscreen,
    panZoomedView,
    openCommandPalette,
    openFile,
    saveAnnotations,
    undo,
    redo,
    addMarker,
    nextMarker,
    previousMarker,
    selectSelectionTool,
    selectPenTool,
    selectEraserTool,
    selectRectangleTool,
    selectCircleTool,
    selectLineTool,
    selectArrowTool,
    selectTextTool,
    toggleKeyframeMode,
    createManualKeyframe,
    toggleFullLoop,
    setLoopStart,
    setLoopEnd,
    toggleSectionLoop,
    toggleCropMode,
    generalShortcutsEnabled,
    annotationToolsShortcutsEnabled,
    loopControlsShortcutsEnabled,
    cropControlsShortcutsEnabled,
  ]);

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$KeyboardShortcutsImplCopyWith<_$KeyboardShortcutsImpl> get copyWith =>
      __$$KeyboardShortcutsImplCopyWithImpl<_$KeyboardShortcutsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$KeyboardShortcutsImplToJson(this);
  }
}

abstract class _KeyboardShortcuts implements KeyboardShortcuts {
  const factory _KeyboardShortcuts({
    required final KeyboardShortcut nextFrame,
    required final KeyboardShortcut previousFrame,
    required final KeyboardShortcut playPause,
    required final KeyboardShortcut jumpForward,
    required final KeyboardShortcut jumpBackward,
    final KeyboardShortcut toggleFullscreen,
    final MouseShortcut panZoomedView,
    final KeyboardShortcut openCommandPalette,
    required final KeyboardShortcut openFile,
    required final KeyboardShortcut saveAnnotations,
    required final KeyboardShortcut undo,
    required final KeyboardShortcut redo,
    final KeyboardShortcut addMarker,
    required final KeyboardShortcut nextMarker,
    required final KeyboardShortcut previousMarker,
    required final KeyboardShortcut selectSelectionTool,
    required final KeyboardShortcut selectPenTool,
    required final KeyboardShortcut selectEraserTool,
    required final KeyboardShortcut selectRectangleTool,
    required final KeyboardShortcut selectCircleTool,
    required final KeyboardShortcut selectLineTool,
    required final KeyboardShortcut selectArrowTool,
    required final KeyboardShortcut selectTextTool,
    required final KeyboardShortcut toggleKeyframeMode,
    required final KeyboardShortcut createManualKeyframe,
    required final KeyboardShortcut toggleFullLoop,
    required final KeyboardShortcut setLoopStart,
    required final KeyboardShortcut setLoopEnd,
    required final KeyboardShortcut toggleSectionLoop,
    required final KeyboardShortcut toggleCropMode,
    final bool generalShortcutsEnabled,
    final bool annotationToolsShortcutsEnabled,
    final bool loopControlsShortcutsEnabled,
    final bool cropControlsShortcutsEnabled,
  }) = _$KeyboardShortcutsImpl;

  factory _KeyboardShortcuts.fromJson(Map<String, dynamic> json) =
      _$KeyboardShortcutsImpl.fromJson;

  @override
  KeyboardShortcut get nextFrame;
  @override
  KeyboardShortcut get previousFrame;
  @override
  KeyboardShortcut get playPause;
  @override
  KeyboardShortcut get jumpForward;
  @override
  KeyboardShortcut get jumpBackward;
  @override
  KeyboardShortcut get toggleFullscreen;
  @override
  MouseShortcut get panZoomedView;
  @override
  KeyboardShortcut get openCommandPalette;
  @override
  KeyboardShortcut get openFile;
  @override
  KeyboardShortcut get saveAnnotations;
  @override
  KeyboardShortcut get undo;
  @override
  KeyboardShortcut get redo;
  @override
  KeyboardShortcut get addMarker;
  @override
  KeyboardShortcut get nextMarker;
  @override
  KeyboardShortcut get previousMarker; // Annotation tools
  @override
  KeyboardShortcut get selectSelectionTool;
  @override
  KeyboardShortcut get selectPenTool;
  @override
  KeyboardShortcut get selectEraserTool;
  @override
  KeyboardShortcut get selectRectangleTool;
  @override
  KeyboardShortcut get selectCircleTool;
  @override
  KeyboardShortcut get selectLineTool;
  @override
  KeyboardShortcut get selectArrowTool;
  @override
  KeyboardShortcut get selectTextTool;
  @override
  KeyboardShortcut get toggleKeyframeMode;
  @override
  KeyboardShortcut get createManualKeyframe; // Loop shortcuts
  @override
  KeyboardShortcut get toggleFullLoop;
  @override
  KeyboardShortcut get setLoopStart;
  @override
  KeyboardShortcut get setLoopEnd;
  @override
  KeyboardShortcut get toggleSectionLoop; // Crop shortcuts
  @override
  KeyboardShortcut get toggleCropMode; // Group enable/disable toggles
  @override
  bool get generalShortcutsEnabled;
  @override
  bool get annotationToolsShortcutsEnabled;
  @override
  bool get loopControlsShortcutsEnabled;
  @override
  bool get cropControlsShortcutsEnabled;

  /// Create a copy of KeyboardShortcuts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$KeyboardShortcutsImplCopyWith<_$KeyboardShortcutsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
