// Basic widget test for FrameSketch Player
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framesketch_player/app.dart';

void main() {
  testWidgets('App launches without errors', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: FrameSketchPlayerApp()));
    await tester.pump();
    // Allow the initial splash/startup animation to settle before assertions.
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('FrameSketch'), findsOneWidget);
    expect(find.text('Projects'), findsWidgets);
  });
}
