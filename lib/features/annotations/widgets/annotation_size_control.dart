import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

const double _compactControlSpacing = 8.0;
const double _compactSliderWidth = 100.0;
const double _compactSliderTrackHeight = 2.0;
const double _compactSliderThumbRadius = 6.0;
const double _compactSliderOverlayRadius = 12.0;
const double _compactValueFontSize = 11.0;
const double _panelTextLabelFontSizeMin = 12.0;
const double _panelTextLabelFontSizeMax = 22.0;
const double _panelLabelFontSize = 14.0;
const double _panelSectionSpacing = 10.0;
const double _textSliderThumbRadius = 10.0;
const double _textSliderOverlayRadius = 18.0;
const double _panelValueFontSize = 14.0;
const double _panelThumbRadiusMin = 7.0;
const double _panelThumbRadiusMax = 13.0;
const double _panelOverlayRadiusMin = 14.0;
const double _panelOverlayRadiusMax = 20.0;

class AnnotationSizeControl extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final bool isTextSize;
  final bool compact;
  final ValueChanged<double> onChanged;

  const AnnotationSizeControl({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.isTextSize,
    required this.onChanged,
    this.compact = false,
  });

  String get _formattedValue =>
      isTextSize ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  double get _normalizedValue {
    final safeRange = (max - min) <= 0 ? 1.0 : (max - min);
    return ((value - min) / safeRange).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    if (compact) {
      return Tooltip(
        message: '$label: $_formattedValue',
        waitDuration: const Duration(milliseconds: 500),
        child: Row(
          children: [
            _AnnotationSizePreview(
              normalizedValue: _normalizedValue,
              isTextSize: isTextSize,
            ),
            const SizedBox(width: _compactControlSpacing),
            SizedBox(
              width: _compactSliderWidth,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: _compactSliderTrackHeight,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: _compactSliderThumbRadius,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: _compactSliderOverlayRadius,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
            Text(
              _formattedValue,
              style: TextStyle(
                fontSize: _compactValueFontSize,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTextSize ? palette.textPrimary : palette.textSecondary,
            fontSize: isTextSize
                ? (_panelTextLabelFontSizeMin +
                      ((_panelTextLabelFontSizeMax -
                              _panelTextLabelFontSizeMin) *
                          _normalizedValue))
                : _panelLabelFontSize,
            fontWeight: isTextSize ? FontWeight.w600 : FontWeight.bold,
            height: isTextSize ? 1.0 : null,
          ),
        ),
        const SizedBox(height: _panelSectionSpacing),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: isTextSize
                        ? _textSliderThumbRadius
                        : _panelThumbRadius,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: isTextSize
                        ? _textSliderOverlayRadius
                        : _panelOverlayRadius,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: _formattedValue,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: _compactControlSpacing),
            Text(
              _formattedValue,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: _panelValueFontSize,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double get _panelThumbRadius {
    return _panelThumbRadiusMin +
        ((_panelThumbRadiusMax - _panelThumbRadiusMin) * _normalizedValue);
  }

  double get _panelOverlayRadius {
    return _panelOverlayRadiusMin +
        ((_panelOverlayRadiusMax - _panelOverlayRadiusMin) * _normalizedValue);
  }
}

class _AnnotationSizePreview extends StatelessWidget {
  final double normalizedValue;
  final bool isTextSize;

  const _AnnotationSizePreview({
    required this.normalizedValue,
    required this.isTextSize,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: 28.0,
      height: 24.0,
      decoration: BoxDecoration(
        color: palette.panelElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: isTextSize
          ? Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: lerpDouble(10, 18, normalizedValue) ?? 10,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            )
          : Center(
              child: Container(
                width: lerpDouble(5, 14, normalizedValue) ?? 5,
                height: lerpDouble(5, 14, normalizedValue) ?? 5,
                decoration: BoxDecoration(
                  color: palette.accentBright,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: palette.accentBright.withValues(alpha: 0.28),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
