import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../providers/annotation_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/utils/coordinate_transformer.dart';
import 'annotation_hit_testing.dart';
import 'annotation_painter.dart';
import 'annotation_text_metrics.dart';
import 'inline_annotation_text_editor.dart';

/// Annotation overlay widget for drawing on video
class AnnotationOverlay extends ConsumerStatefulWidget {
  const AnnotationOverlay({super.key});

  @override
  ConsumerState<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends ConsumerState<AnnotationOverlay> {
  Offset? _currentCursorPosition;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  Size? _lastViewportSize;
  late final TextEditingController _inlineTextController;
  late final FocusNode _inlineTextFocusNode;
  String? _editingStrokeId;
  int? _activePointer;

  @override
  void initState() {
    super.initState();
    _inlineTextController = TextEditingController();
    _inlineTextFocusNode = FocusNode();
    _inlineTextFocusNode.addListener(_handleInlineTextFocusChange);
  }

  @override
  void dispose() {
    _inlineTextFocusNode.removeListener(_handleInlineTextFocusChange);
    _inlineTextController.dispose();
    _inlineTextFocusNode.dispose();
    super.dispose();
  }

  Size? _resolveVideoSize() {
    final playerState = ref.read(playerProvider);
    final rect = playerState.videoController?.rect.value;
    if (rect != null && rect.width > 1 && rect.height > 1) {
      return Size(rect.width, rect.height);
    }

    final metadata = playerState.metadata;
    if (metadata == null || metadata.width <= 0 || metadata.height <= 0) {
      return null;
    }

    return Size(metadata.width.toDouble(), metadata.height.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final annotationState = ref.watch(annotationProvider);
    final visibleStrokes = ref.watch(visibleAnnotationStrokesProvider);
    final videoRect = ref.watch(
      playerProvider.select((state) => state.videoController?.rect.value),
    );
    final fallbackMetadata = ref.watch(
      playerProvider.select((state) => state.metadata),
    );
    final videoSize =
        (videoRect != null && videoRect.width > 1 && videoRect.height > 1)
        ? Size(videoRect.width, videoRect.height)
        : (fallbackMetadata == null
              ? null
              : Size(
                  fallbackMetadata.width.toDouble(),
                  fallbackMetadata.height.toDouble(),
                ));

    ref.listen<AnnotationState>(annotationProvider, (previous, next) {
      _syncInlineTextEditor(next);
    });
    _syncInlineTextEditor(annotationState);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        _lastViewportSize = viewportSize;
        final editingStroke = annotationState.pendingTextStrokeId == null
            ? null
            : annotationState.allStrokes
                  .where((s) => s.id == annotationState.pendingTextStrokeId)
                  .firstOrNull;

        return MouseRegion(
          onHover: (event) {
            if (annotationState.currentTool == DrawingTool.eraser) {
              setState(() {
                _currentCursorPosition = event.localPosition;
              });
            }
          },
          onExit: (_) {
            setState(() {
              _currentCursorPosition = null;
            });
          },
          cursor: _cursorForAnnotationState(annotationState),
          child: Stack(
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) =>
                    _handlePointerDown(event, viewportSize),
                onPointerMove: (event) =>
                    _handlePointerMove(event, viewportSize),
                onPointerUp: (event) => _handlePointerUp(event),
                onPointerCancel: (event) => _handlePointerCancel(event),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: AnnotationPainter(
                    strokes: visibleStrokes,
                    currentStroke: annotationState.currentStroke,
                    viewportSize: viewportSize,
                    videoSize: videoSize,
                    textDirection: Directionality.of(context),
                    currentTool: annotationState.currentTool,
                    eraserPosition: _currentCursorPosition,
                    eraserRadius:
                        annotationState.currentStrokeWidth / 3.0 * 0.02,
                    selectedStrokeId: annotationState.selectedStrokeId,
                    selectedStrokeIds: annotationState.selectedStrokeIds,
                    selectionBoxStartPoint:
                        annotationState.selectionBoxStartPoint,
                    selectionBoxEndPoint: annotationState.selectionBoxEndPoint,
                    isBoxSelecting: annotationState.isBoxSelecting,
                    editingTextStrokeId: annotationState.pendingTextStrokeId,
                  ),
                ),
              ),
              if (editingStroke != null) ...[
                _buildInlineTextEditor(editingStroke, viewportSize),
              ],
            ],
          ),
        );
      },
    );
  }

  CoordinateTransformer _createTransformer(Size viewportSize) {
    final videoSize = _resolveVideoSize();
    return CoordinateTransformer(viewportSize, videoSize: videoSize);
  }

  void _syncInlineTextEditor(AnnotationState state) {
    final pendingId = state.pendingTextStrokeId;
    if (pendingId == null) {
      _editingStrokeId = null;
      return;
    }

    final editingStroke = state.allStrokes
        .where((s) => s.id == pendingId)
        .firstOrNull;
    if (editingStroke == null) {
      _editingStrokeId = null;
      return;
    }

    if (_editingStrokeId != pendingId) {
      _editingStrokeId = pendingId;
      _inlineTextController.text = editingStroke.text ?? '';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _editingStrokeId != pendingId) return;
        _inlineTextFocusNode.requestFocus();
        _inlineTextController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _inlineTextController.text.length,
        );
        final size = _lastViewportSize;
        final latestStroke = ref
            .read(annotationProvider)
            .allStrokes
            .where((s) => s.id == pendingId)
            .firstOrNull;
        if (size != null && latestStroke != null) {
          _autoGrowEditingTextBox(
            latestStroke,
            size,
            _inlineTextController.text,
          );
        }
      });
      return;
    }

    final latestText = editingStroke.text ?? '';
    if (_inlineTextController.text != latestText) {
      _inlineTextController.text = latestText;
      _inlineTextController.selection = TextSelection.collapsed(
        offset: latestText.length,
      );
    }
  }

  void _handleInlineTextFocusChange() {
    if (_inlineTextFocusNode.hasFocus) return;
    if (_editingStrokeId == null) return;
    final size = _lastViewportSize;
    final stroke = ref
        .read(annotationProvider)
        .allStrokes
        .where((s) => s.id == _editingStrokeId)
        .firstOrNull;
    if (size != null && stroke != null) {
      _autoGrowEditingTextBox(stroke, size, _inlineTextController.text);
    }
    ref.read(annotationProvider.notifier).finalizePendingTextStroke();
  }

  Widget _buildInlineTextEditor(Stroke stroke, Size viewportSize) {
    final transformer = _createTransformer(viewportSize);
    return InlineAnnotationTextEditor(
      stroke: stroke,
      viewportSize: viewportSize,
      transformer: transformer,
      controller: _inlineTextController,
      focusNode: _inlineTextFocusNode,
      onChanged: (value) {
        final notifier = ref.read(annotationProvider.notifier);
        notifier.updatePendingTextStrokeText(value);
        final latestStroke = ref
            .read(annotationProvider)
            .allStrokes
            .where((s) => s.id == stroke.id)
            .firstOrNull;
        if (latestStroke != null) {
          _autoGrowEditingTextBox(latestStroke, viewportSize, value);
        }
      },
    );
  }

  void _autoGrowEditingTextBox(Stroke stroke, Size viewportSize, String text) {
    final transformer = _createTransformer(viewportSize);
    final anchor = transformer.toViewport(stroke.points.first);
    final defaults = annotationTextBoxDefaults(stroke, transformer, anchor);
    final bottomRight = stroke.points.length >= 2
        ? transformer.toViewport(stroke.points.last)
        : defaults.fallbackBottomRight;
    final currentRect = Rect.fromPoints(anchor, bottomRight);

    final minWidth = defaults.minWidth;
    final minHeight = defaults.minHeight;
    final currentWidth = max(currentRect.width, minWidth);
    final currentHeight = max(currentRect.height, minHeight);

    final left = currentRect.left.clamp(0.0, viewportSize.width);
    final top = currentRect.top.clamp(0.0, viewportSize.height);
    final availableWidth = max(80.0, viewportSize.width - left);
    final availableHeight = max(32.0, viewportSize.height - top);

    const horizontalPadding = 12.0;
    const verticalPadding = 8.0;
    // Include hint text sizing so empty boxes still show "Type text...".
    final measuredText = text.isEmpty ? 'Type text...' : text;
    final baseSpan = TextSpan(
      text: measuredText,
      style: textStyleForStroke(stroke, fontSize: defaults.scaledFontSize),
    );
    final targetWidth = currentWidth.clamp(minWidth, availableWidth).toDouble();

    final wrappedPainter = TextPainter(
      text: baseSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: max(1.0, targetWidth - horizontalPadding));
    double targetHeight = max(
      currentHeight,
      wrappedPainter.height + verticalPadding,
    ).clamp(minHeight, availableHeight).toDouble();

    if ((targetHeight - currentHeight).abs() < 0.5) {
      return;
    }

    final clampedLeft = left
        .clamp(0.0, max(0.0, viewportSize.width - targetWidth))
        .toDouble();
    final clampedTop = top
        .clamp(0.0, max(0.0, viewportSize.height - targetHeight))
        .toDouble();
    final normalizedTopLeft = transformer.toNormalized(
      Offset(clampedLeft, clampedTop),
    );
    final normalizedBottomRight = transformer.toNormalized(
      Offset(clampedLeft + targetWidth, clampedTop + targetHeight),
    );

    ref
        .read(annotationProvider.notifier)
        .updatePendingTextStrokeBounds(
          left: normalizedTopLeft.x,
          top: normalizedTopLeft.y,
          right: normalizedBottomRight.x,
          bottom: normalizedBottomRight.y,
        );
  }

  void _handlePointerDown(PointerDownEvent event, Size viewportSize) {
    if (_activePointer != null) return;
    if (!_isPrimaryDrawingPointer(event)) return;

    _activePointer = event.pointer;
    _handleStrokeStart(event.localPosition, viewportSize);
  }

  void _handlePointerMove(PointerMoveEvent event, Size viewportSize) {
    if (_activePointer != event.pointer) return;
    _handleStrokeUpdate(event.localPosition, viewportSize);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _handleStrokeEnd();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _handleStrokeCancel();
  }

  bool _isPrimaryDrawingPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      return event.buttons & kPrimaryMouseButton != 0;
    }

    return true;
  }

  MouseCursor _cursorForAnnotationState(AnnotationState annotationState) {
    if (annotationState.isScaling) {
      return SystemMouseCursors.move;
    }

    return switch (annotationState.currentTool) {
      DrawingTool.text => SystemMouseCursors.text,
      DrawingTool.select => MouseCursor.defer,
      DrawingTool.pen => SystemMouseCursors.precise,
      DrawingTool.eraser ||
      DrawingTool.rectangle ||
      DrawingTool.filledSquare ||
      DrawingTool.circle ||
      DrawingTool.filledCircle ||
      DrawingTool.line ||
      DrawingTool.arrow => SystemMouseCursors.precise,
    };
  }

  void _handleStrokeStart(Offset position, Size viewportSize) {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.pendingTextStrokeId != null) {
      _inlineTextFocusNode.unfocus();
      notifier.finalizePendingTextStroke();
      return;
    }

    final now = DateTime.now();

    // Check for double-tap to edit text annotations
    if (_lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300 &&
        (position - _lastTapPosition!).distance < 20) {
      _lastTapTime = null;
      _lastTapPosition = null;
      if (_handleDoubleTap(position, viewportSize)) {
        return;
      }
    } else {
      _lastTapTime = now;
      _lastTapPosition = position;
    }

    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(position);

    // Check if user clicked on a corner handle of a selected stroke
    if (annotationState.currentTool == DrawingTool.select &&
        annotationState.selectedStrokeId != null &&
        annotationState.selectedStrokeIds.length <= 1) {
      final selectedStroke = ref
          .read(visibleAnnotationStrokesProvider)
          .where((s) => s.id == annotationState.selectedStrokeId)
          .firstOrNull;

      if (selectedStroke != null) {
        final corner = resizeHandleAtPoint(
          selectedStroke,
          position,
          transformer,
        );
        if (corner != null) {
          notifier.startScaling(corner, normalizedPoint);
          return;
        }
      }
    }

    notifier.startStroke(normalizedPoint);
  }

  bool _handleDoubleTap(Offset position, Size viewportSize) {
    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(position);
    final notifier = ref.read(annotationProvider.notifier);

    // Search for a text stroke at this position (reverse order = topmost first)
    final visibleStrokes = ref.read(visibleAnnotationStrokesProvider);
    for (int i = visibleStrokes.length - 1; i >= 0; i--) {
      final stroke = visibleStrokes[i];
      if (stroke.tool == DrawingTool.text &&
          stroke.text != null &&
          stroke.text!.isNotEmpty) {
        final bounds = textBoundsNormalized(stroke, transformer);
        if (bounds == null) {
          continue;
        }
        const threshold = 0.02;

        if (normalizedPoint.x >= bounds.left - threshold &&
            normalizedPoint.x <= bounds.right + threshold &&
            normalizedPoint.y >= bounds.top - threshold &&
            normalizedPoint.y <= bounds.bottom + threshold) {
          notifier.editTextStroke(stroke.id);
          return true;
        }
      }
    }

    return false;
  }

  void _handleStrokeUpdate(Offset position, Size viewportSize) {
    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(position);

    // Update cursor position for eraser visual feedback
    setState(() {
      _currentCursorPosition = position;
    });

    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    // If scaling, update the scale
    if (annotationState.isScaling) {
      notifier.updateScaling(normalizedPoint);
      return;
    }

    notifier.addPointToStroke(normalizedPoint);
  }

  void _handleStrokeEnd() {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.isScaling) {
      notifier.finishScaling();
      return;
    }

    notifier.finishStroke();
  }

  void _handleStrokeCancel() {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.isScaling) {
      notifier.finishScaling();
      return;
    }

    if (annotationState.currentStroke != null) {
      notifier.finishStroke();
      return;
    }

    notifier.cancelStroke();
  }
}
