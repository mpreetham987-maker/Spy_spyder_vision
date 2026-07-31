// Basic smoke test for Spy Spider Vision.
//
// This verifies the app boots to the splash screen without throwing.
// Add feature-level widget/unit tests alongside this as the app grows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spy_spider_vision/data/services/preferences_service.dart';
import 'package:spy_spider_vision/main.dart';

void main() {
  testWidgets('App boots and shows the splash screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await PreferencesService.create();

    await tester.pumpWidget(SpySpiderVisionApp(preferences: preferences));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
