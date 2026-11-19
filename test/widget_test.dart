import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chevaliers/main.dart';

void main() {
  testWidgets('App starts on an empty home page without header', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MyHomePage), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });
}
