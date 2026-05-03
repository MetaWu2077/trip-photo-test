import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_photo_test/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Suppress MissingPluginException from permission_handler during tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => <int, int>{},
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
  });

  testWidgets('App launches and shows AppBar title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('旅拍照片上传'), findsWidgets);
  });
}

