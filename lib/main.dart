import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';

void main(List<String> args) {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit for video playback
  MediaKit.ensureInitialized();

  // Extract video file path from command-line arguments
  String? initialVideoPath;
  if (args.isNotEmpty) {
    // The first argument should be the video file path
    initialVideoPath = args.first;
  }

  runApp(
    ProviderScope(
      child: FrameSketchPlayerApp(initialVideoPath: initialVideoPath),
    ),
  );
}
