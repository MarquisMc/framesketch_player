// Basic widget test for FrameSketch Player
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framesketch_player/app.dart';

void main() {
  testWidgets('App launches without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      const ProviderScope(
        child: FrameSketchPlayerApp(),
      ),
    );

    // Verify app title is present
    expect(find.text('FrameSketch Player'), findsOneWidget);
  });
}
