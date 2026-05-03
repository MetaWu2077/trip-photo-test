import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_photo_test/main.dart';

void main() {
  testWidgets('App launches and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TripPhotoApp());
    expect(find.text('旅途相册'), findsOneWidget);
  });

  testWidgets('Home screen shows album cards', (WidgetTester tester) async {
    await tester.pumpWidget(const TripPhotoApp());
    // Wait for the initial frame
    await tester.pump();
    // Albums grid should be present
    expect(find.byType(GridView), findsOneWidget);
  });
}
