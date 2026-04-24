import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../providers/annotation_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/utils/coordinate_transformer.dart';

TextStyle _textStyleForStroke(Stroke stroke, {double? fontSize, Color? color}) {
  return TextStyle(
    color: color ?? stroke.color,
    fontSize: fontSize ?? stroke.fontSize,
    height: 1.2,
  );
}

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

  Size _estimateTextSize(Stroke stroke) {
    final effectiveFontSize = stroke.fontSize;
    final textSpan = TextSpan(
      text: stroke.text ?? '',
      style: _textStyleForStroke(stroke, fontSize: effectiveFontSize),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout();
    return Size(textPainter.width, textPainter.height);
  }

  Rect _textBoundsNormalized(Stroke stroke, Size viewportSize) {
    final anchor = stroke.points.first;
    if (stroke.points.length >= 2) {
      final p2 = stroke.points.last;
      final left = anchor.x < p2.x ? anchor.x : p2.x;
      final right = anchor.x > p2.x ? anchor.x : p2.x;
      final top = anchor.y < p2.y ? anchor.y : p2.y;
      final bottom = anchor.y > p2.y ? anchor.y : p2.y;
      return Rect.fromLTRB(left, top, right, bottom);
    }

    final estimatedSize = _estimateTextSize(stroke);
    final width = estimatedSize.width / viewportSize.width;
    final height = estimatedSize.height / viewportSize.height;
    return Rect.fromLTRB(
      anchor.x,
      anchor.y,
      anchor.x + width,
      anchor.y + height,
    );
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
          cursor: annotationState.currentTool == DrawingTool.eraser
              ? SystemMouseCursors.precise
              : annotationState.currentTool == DrawingTool.text
              ? SystemMouseCursors.text
              : MouseCursor.defer,
          child: Stack(
            children: [
              GestureDetector(
                onPanStart: (details) => _handlePanStart(details, viewportSize),
                onPanUpdate: (details) =>
                    _handlePanUpdate(details, viewportSize),
                onPanEnd: (_) => _handlePanEnd(),
                onPanCancel: () => _handlePanCancel(),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: AnnotationPainter(
                    strokes: visibleStrokes,
                    currentStroke: annotationState.currentStroke,
                    viewportSize: viewportSize,
                    videoSize: videoSize,
                    currentTool: annotationState.currentTool,
                    eraserPosition: _currentCursorPosition,
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
    final anchor = transformer.toViewport(stroke.points.first);
    final bottomRight = stroke.points.length >= 2
        ? transformer.toViewport(stroke.points.last)
        : Offset(anchor.dx + 120, anchor.dy + max(stroke.fontSize + 12, 36));
    final rect = Rect.fromPoints(anchor, bottomRight);
    final minWidth = max(120.0, stroke.fontSize * 4.0);
    final minHeight = max(36.0, stroke.fontSize * 1.8);
    final width = max(rect.width, minWidth).clamp(80.0, viewportSize.width);
    final height = max(rect.height, minHeight).clamp(32.0, viewportSize.height);
    final maxLeft = max(0.0, viewportSize.width - width);
    final maxTop = max(0.0, viewportSize.height - height);
    final left = rect.left.clamp(0.0, maxLeft);
    final top = rect.top.clamp(0.0, maxTop);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            border: Border.all(
              color: stroke.color.withValues(alpha: 0.85),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
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
            onSubmitted: (_) => _inlineTextFocusNode.unfocus(),
            onTapOutside: (_) => _inlineTextFocusNode.unfocus(),
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textAlignVertical: TextAlignVertical.top,
            minLines: 1,
            maxLines: null,
            style: _textStyleForStroke(stroke),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              hintText: 'Type text...',
              hintStyle: _textStyleForStroke(
                stroke,
                color: stroke.color.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _autoGrowEditingTextBox(Stroke stroke, Size viewportSize, String text) {
    final transformer = _createTransformer(viewportSize);
    final anchor = transformer.toViewport(stroke.points.first);
    final bottomRight = stroke.points.length >= 2
        ? transformer.toViewport(stroke.points.last)
        : Offset(anchor.dx + 120, anchor.dy + max(stroke.fontSize + 12, 36));
    final currentRect = Rect.fromPoints(anchor, bottomRight);

    final minWidth = max(120.0, stroke.fontSize * 4.0);
    final minHeight = max(36.0, stroke.fontSize * 1.8);
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
      style: _textStyleForStroke(stroke),
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

  void _handlePanStart(DragStartDetails details, Size viewportSize) {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.pendingTextStrokeId != null) {
      _inlineTextFocusNode.unfocus();
      notifier.finalizePendingTextStroke();
      return;
    }

    final now = DateTime.now();
    final position = details.localPosition;

    // Check for double-tap to edit text annotations
    if (_lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300 &&
        (position - _lastTapPosition!).distance < 20) {
      _handleDoubleTap(position, viewportSize);
      _lastTapTime = null;
      _lastTapPosition = null;
      return;
    }

    _lastTapTime = now;
    _lastTapPosition = position;

    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(details.localPosition);

    // Check if user clicked on a corner handle of a selected stroke
    if (annotationState.currentTool == DrawingTool.select &&
        annotationState.selectedStrokeId != null &&
        annotationState.selectedStrokeIds.length <= 1) {
      final selectedStroke = ref
          .read(visibleAnnotationStrokesProvider)
          .where((s) => s.id == annotationState.selectedStrokeId)
          .firstOrNull;

      if (selectedStroke != null) {
        final corner = _getCornerAtPoint(
          selectedStroke,
          position,
          viewportSize,
        );
        if (corner != null) {
          notifier.startScaling(corner, normalizedPoint);
          return;
        }
      }
    }

    notifier.startStroke(normalizedPoint);
  }

  void _handleDoubleTap(Offset position, Size viewportSize) {
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
        final bounds = _textBoundsNormalized(stroke, viewportSize);
        const threshold = 0.02;

        if (normalizedPoint.x >= bounds.left - threshold &&
            normalizedPoint.x <= bounds.right + threshold &&
            normalizedPoint.y >= bounds.top - threshold &&
            normalizedPoint.y <= bounds.bottom + threshold) {
          notifier.editTextStroke(stroke.id);
          return;
        }
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, Size viewportSize) {
    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(details.localPosition);

    // Update cursor position for eraser visual feedback
    setState(() {
      _currentCursorPosition = details.localPosition;
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

  void _handlePanEnd() {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.isScaling) {
      notifier.finishScaling();
      return;
    }

    notifier.finishStroke();
  }

  void _handlePanCancel() {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.isScaling) {
      notifier.finishScaling();
      return;
    }

    notifier.cancelStroke();
  }

  Rect? _selectionRectForStroke(
    Stroke stroke,
    CoordinateTransformer transformer, {
    double padding = 8,
  }) {
    if (stroke.points.isEmpty) return null;

    if (stroke.tool == DrawingTool.text &&
        stroke.text != null &&
        stroke.text!.isNotEmpty) {
      if (stroke.points.length >= 2) {
        return Rect.fromPoints(
          transformer.toViewport(stroke.points.first),
          transformer.toViewport(stroke.points.last),
        );
      }

      final position = transformer.toViewport(stroke.points.first);
      final textSpan = TextSpan(
        text: stroke.text!,
        style: _textStyleForStroke(stroke),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout();
      return Rect.fromLTWH(
        position.dx,
        position.dy,
        textPainter.width,
        textPainter.height,
      );
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in stroke.points) {
      final viewportPoint = transformer.toViewport(point);
      if (viewportPoint.dx < minX) minX = viewportPoint.dx;
      if (viewportPoint.dy < minY) minY = viewportPoint.dy;
      if (viewportPoint.dx > maxX) maxX = viewportPoint.dx;
      if (viewportPoint.dy > maxY) maxY = viewportPoint.dy;
    }

    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  /// Get which resize handle (if any) is at the given point.
  String? _getCornerAtPoint(Stroke stroke, Offset point, Size viewportSize) {
    if (stroke.points.isEmpty) return null;

    final transformer = _createTransformer(viewportSize);
    const handleSize = 12.0;
    const edgeWidth = 28.0;
    const edgeThickness = 16.0;
    final boundingBox = _selectionRectForStroke(
      stroke,
      transformer,
      padding: stroke.tool == DrawingTool.text ? 0 : 8,
    );

    if (boundingBox == null) return null;

    if ((point - Offset(boundingBox.left, boundingBox.top)).distance <
        handleSize) {
      return 'topLeft';
    }
    if ((point - Offset(boundingBox.right, boundingBox.top)).distance <
        handleSize) {
      return 'topRight';
    }
    if ((point - Offset(boundingBox.left, boundingBox.bottom)).distance <
        handleSize) {
      return 'bottomLeft';
    }
    if ((point - Offset(boundingBox.right, boundingBox.bottom)).distance <
        handleSize) {
      return 'bottomRight';
    }

    if (stroke.tool != DrawingTool.text) {
      final topHandle = Rect.fromCenter(
        center: Offset(boundingBox.center.dx, boundingBox.top),
        width: edgeWidth,
        height: edgeThickness,
      );
      if (topHandle.contains(point)) {
        return 'top';
      }

      final bottomHandle = Rect.fromCenter(
        center: Offset(boundingBox.center.dx, boundingBox.bottom),
        width: edgeWidth,
        height: edgeThickness,
      );
      if (bottomHandle.contains(point)) {
        return 'bottom';
      }

      final leftHandle = Rect.fromCenter(
        center: Offset(boundingBox.left, boundingBox.center.dy),
        width: edgeThickness,
        height: edgeWidth,
      );
      if (leftHandle.contains(point)) {
        return 'left';
      }

      final rightHandle = Rect.fromCenter(
        center: Offset(boundingBox.right, boundingBox.center.dy),
        width: edgeThickness,
        height: edgeWidth,
      );
      if (rightHandle.contains(point)) {
        return 'right';
      }
    }

    return null;
  }
}

/// Custom painter for rendering annotations
class AnnotationPainter extends CustomPainter {
  static const Color _selectionAccentColor = Color(0xFF4FC3F7);
  static final Paint _selectionHandleFillPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  static final Paint _selectionHandleBorderPaint = Paint()
    ..color = _selectionAccentColor
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  static final Paint _selectionHandleShadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.28)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final Size viewportSize;
  final Size? videoSize;
  final DrawingTool currentTool;
  final Offset? eraserPosition;
  final String? selectedStrokeId;
  final List<String> selectedStrokeIds;
  final StrokePoint? selectionBoxStartPoint;
  final StrokePoint? selectionBoxEndPoint;
  final bool isBoxSelecting;
  final String? editingTextStrokeId;

  AnnotationPainter({
    required this.strokes,
    required this.currentStroke,
    required this.viewportSize,
    this.videoSize,
    required this.currentTool,
    this.eraserPosition,
    this.selectedStrokeId,
    this.selectedStrokeIds = const [],
    this.selectionBoxStartPoint,
    this.selectionBoxEndPoint,
    this.isBoxSelecting = false,
    this.editingTextStrokeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final transformer = CoordinateTransformer(
      viewportSize,
      videoSize: videoSize,
    );

    // Draw completed strokes
    final selectedSet = selectedStrokeIds.toSet();
    for (final stroke in strokes) {
      final isEditingTextStroke =
          editingTextStrokeId != null &&
          stroke.id == editingTextStrokeId &&
          stroke.tool == DrawingTool.text;
      if (isEditingTextStroke) {
        continue;
      }

      _drawStroke(canvas, stroke, transformer);

      // Draw selection highlight if this stroke is selected
      if (selectedSet.contains(stroke.id) ||
          (selectedSet.isEmpty &&
              selectedStrokeId != null &&
              stroke.id == selectedStrokeId)) {
        _drawSelectionHighlight(canvas, stroke, transformer);
      }
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, transformer);
    }

    // Draw eraser cursor
    if (currentTool == DrawingTool.eraser && eraserPosition != null) {
      _drawEraserCursor(canvas, eraserPosition!);
    }

    // Draw marquee selection rectangle
    if (isBoxSelecting &&
        selectionBoxStartPoint != null &&
        selectionBoxEndPoint != null) {
      _drawSelectionBox(canvas, transformer);
    }
  }

  void _drawSelectionBox(Canvas canvas, CoordinateTransformer transformer) {
    final start = transformer.toViewport(selectionBoxStartPoint!);
    final end = transformer.toViewport(selectionBoxEndPoint!);
    final rect = Rect.fromPoints(start, end);

    final fillPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);
  }

  void _drawStroke(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.isEmpty) return;

    // Text strokes have a single point but should be rendered as text, not a dot
    if (stroke.tool == DrawingTool.text) {
      _drawText(canvas, stroke, transformer);
      return;
    }

    // Handle single point
    if (stroke.points.length < 2) {
      final point = transformer.toViewport(stroke.points.first);
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point, stroke.strokeWidth / 2, paint);
      return;
    }

    // Dispatch to appropriate drawing method based on tool type
    switch (stroke.tool) {
      case DrawingTool.pen:
        _drawPenStroke(canvas, stroke, transformer);
        break;
      case DrawingTool.rectangle:
        _drawRectangle(canvas, stroke, transformer);
        break;
      case DrawingTool.filledSquare:
        _drawFilledSquare(canvas, stroke, transformer);
        break;
      case DrawingTool.circle:
        _drawCircle(canvas, stroke, transformer);
        break;
      case DrawingTool.filledCircle:
        _drawFilledCircle(canvas, stroke, transformer);
        break;
      case DrawingTool.line:
        _drawLine(canvas, stroke, transformer);
        break;
      case DrawingTool.arrow:
        _drawArrow(canvas, stroke, transformer);
        break;
      case DrawingTool.text:
        // Handled above before the points.length check
        break;
      case DrawingTool.eraser:
      case DrawingTool.select:
        // Eraser and select strokes shouldn't be drawn
        break;
    }
  }

  void _drawPenStroke(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final offsets = transformer.strokeToOffsets(stroke);

    path.moveTo(offsets.first.dx, offsets.first.dy);

    for (int i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawRectangle(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final rect = Rect.fromPoints(start, end);

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, paint);
  }

  void _drawCircle(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final radiusX = (end.dx - start.dx).abs() / 2;
    final radiusY = (end.dy - start.dy).abs() / 2;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw ellipse
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  void _drawFilledSquare(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);
    final rect = Rect.fromPoints(start, end);
    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }

  void _drawFilledCircle(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final radiusX = (end.dx - start.dx).abs() / 2;
    final radiusY = (end.dy - start.dy).abs() / 2;

    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  void _drawLine(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  void _drawArrow(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw line
    canvas.drawLine(start, end, paint);

    // Calculate arrowhead
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = atan2(dy, dx);

    final arrowSize = stroke.strokeWidth * 3;
    const arrowAngle = pi / 6; // 30 degrees

    // Arrowhead points
    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - arrowAngle),
      end.dy - arrowSize * sin(angle - arrowAngle),
    );

    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + arrowAngle),
      end.dy - arrowSize * sin(angle + arrowAngle),
    );

    // Draw arrowhead
    final arrowPath = Path()
      ..moveTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy);

    canvas.drawPath(arrowPath, paint);
  }

  void _drawText(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.isEmpty || stroke.text == null || stroke.text!.isEmpty) {
      return;
    }

    final position = transformer.toViewport(stroke.points.first);

    final textSpan = TextSpan(
      text: stroke.text!,
      style: _textStyleForStroke(stroke),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    if (stroke.points.length >= 2) {
      final textRect = Rect.fromPoints(
        transformer.toViewport(stroke.points.first),
        transformer.toViewport(stroke.points.last),
      );
      final maxWidth = textRect.width <= 1 ? 1.0 : textRect.width;
      textPainter.layout(maxWidth: maxWidth);

      canvas.save();
      canvas.clipRect(textRect);
      textPainter.paint(canvas, textRect.topLeft);
      canvas.restore();
      return;
    }

    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawSelectionHighlight(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.isEmpty) return;

    Rect? selectionRect;

    if (stroke.tool == DrawingTool.text) {
      if (stroke.points.isNotEmpty &&
          stroke.text != null &&
          stroke.text!.isNotEmpty) {
        final position = transformer.toViewport(stroke.points.first);

        final textSpan = TextSpan(
          text: stroke.text!,
          style: _textStyleForStroke(stroke),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: null,
        );
        if (stroke.points.length < 2) {
          textPainter.layout();
        }
        selectionRect = stroke.points.length >= 2
            ? Rect.fromPoints(
                transformer.toViewport(stroke.points.first),
                transformer.toViewport(stroke.points.last),
              )
            : Rect.fromLTWH(
                position.dx - 4,
                position.dy - 4,
                textPainter.width + 8,
                textPainter.height + 8,
              );
      }
    } else {
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;

      for (final point in stroke.points) {
        final viewportPoint = transformer.toViewport(point);
        if (viewportPoint.dx < minX) minX = viewportPoint.dx;
        if (viewportPoint.dy < minY) minY = viewportPoint.dy;
        if (viewportPoint.dx > maxX) maxX = viewportPoint.dx;
        if (viewportPoint.dy > maxY) maxY = viewportPoint.dy;
      }

      selectionRect = Rect.fromLTRB(minX - 8, minY - 8, maxX + 8, maxY + 8);
    }

    if (selectionRect == null) return;

    // Subtle fill
    canvas.drawRect(
      selectionRect,
      Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.07)
        ..style = PaintingStyle.fill,
    );

    // Border with soft glow
    final glowPaint = Paint()
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.22)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(selectionRect, glowPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(selectionRect, borderPaint);

    // Handles
    _drawCornerHandle(
      canvas,
      Offset(selectionRect.left, selectionRect.top),
      _selectionHandleFillPaint,
      _selectionHandleBorderPaint,
      _selectionHandleShadowPaint,
    );
    _drawCornerHandle(
      canvas,
      Offset(selectionRect.right, selectionRect.top),
      _selectionHandleFillPaint,
      _selectionHandleBorderPaint,
      _selectionHandleShadowPaint,
    );
    _drawCornerHandle(
      canvas,
      Offset(selectionRect.left, selectionRect.bottom),
      _selectionHandleFillPaint,
      _selectionHandleBorderPaint,
      _selectionHandleShadowPaint,
    );
    _drawCornerHandle(
      canvas,
      Offset(selectionRect.right, selectionRect.bottom),
      _selectionHandleFillPaint,
      _selectionHandleBorderPaint,
      _selectionHandleShadowPaint,
    );

    if (stroke.tool != DrawingTool.text) {
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.center.dx, selectionRect.top),
          width: 20,
          height: 7,
        ),
        _selectionHandleFillPaint,
        _selectionHandleBorderPaint,
        _selectionHandleShadowPaint,
      );
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.center.dx, selectionRect.bottom),
          width: 20,
          height: 7,
        ),
        _selectionHandleFillPaint,
        _selectionHandleBorderPaint,
        _selectionHandleShadowPaint,
      );
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.left, selectionRect.center.dy),
          width: 7,
          height: 20,
        ),
        _selectionHandleFillPaint,
        _selectionHandleBorderPaint,
        _selectionHandleShadowPaint,
      );
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.right, selectionRect.center.dy),
          width: 7,
          height: 20,
        ),
        _selectionHandleFillPaint,
        _selectionHandleBorderPaint,
        _selectionHandleShadowPaint,
      );
    }
  }

  void _drawCornerHandle(
    Canvas canvas,
    Offset center,
    Paint fillPaint,
    Paint borderPaint,
    Paint shadowPaint,
  ) {
    const halfSize = 5.0;
    const radius = Radius.circular(3);
    final rect = Rect.fromCenter(
      center: center,
      width: halfSize * 2,
      height: halfSize * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(rrect, shadowPaint);
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawEdgeHandle(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint borderPaint,
    Paint shadowPaint,
  ) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, shadowPaint);
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawEraserCursor(Canvas canvas, Offset position) {
    // Draw eraser circle outline
    final eraserPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Eraser radius in pixels (proportional to viewport)
    final eraserRadiusPx = viewportSize.width * 0.02;

    canvas.drawCircle(position, eraserRadiusPx, eraserPaint);

    // Draw crosshair
    final crosshairPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(position.dx - eraserRadiusPx, position.dy),
      Offset(position.dx + eraserRadiusPx, position.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(position.dx, position.dy - eraserRadiusPx),
      Offset(position.dx, position.dy + eraserRadiusPx),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.videoSize != videoSize ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.selectedStrokeId != selectedStrokeId ||
        oldDelegate.selectedStrokeIds != selectedStrokeIds ||
        oldDelegate.selectionBoxStartPoint != selectionBoxStartPoint ||
        oldDelegate.selectionBoxEndPoint != selectionBoxEndPoint ||
        oldDelegate.isBoxSelecting != isBoxSelecting ||
        oldDelegate.editingTextStrokeId != editingTextStrokeId;
  }
}
