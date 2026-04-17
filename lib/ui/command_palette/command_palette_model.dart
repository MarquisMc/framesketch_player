import 'dart:async' show FutureOr;

import 'package:flutter/material.dart';

/// A single action in the command palette.
class PaletteCommand {
  final String id;
  final String label;
  final String category;
  final IconData icon;
  final String? shortcut;
  final String? subtitle;
  final bool enabled;

  /// Invoked when the user selects this command. Runs after the palette closes.
  /// Returning a non-null [PaletteStep] pushes a secondary input step
  /// (used by "Go to frame", "Set A", "Set B").
  final PaletteStep? Function()? run;

  const PaletteCommand({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    this.shortcut,
    this.subtitle,
    this.enabled = true,
    this.run,
  });
}

/// A secondary input step within the palette (e.g. prompt for a frame number).
class PaletteStep {
  final String title;
  final String hint;
  final String? helper;

  /// Caller-provided action label for the step confirmation UI.
  /// Supply a localized string at construction time.
  final String confirmLabel;

  /// Called when the user submits the input.
  /// Return null to close the palette, or an error message to keep it open.
  final FutureOr<String?> Function(String value) onSubmit;

  const PaletteStep({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.onSubmit,
    this.helper,
  });
}
