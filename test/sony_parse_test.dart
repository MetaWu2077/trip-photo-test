import 'package:flutter_test/flutter_test.dart';
import 'package:trip_photo_test/sony/sony_client.dart';

void main() {
  test('findAllOriginalUrls 收集嵌套 URL', () {
    final sample = {
      'result': [
        {
          'uri': 'slot:xxx',
          'content': [
            {
              'original': [
                {'url': 'http://cam/foo1.jpg'},
              ],
            },
          ],
        },
      ],
    };
    final urls = SonyCameraRemoteClient.findAllOriginalUrls(sample);
    expect(urls.length, 1);
    expect(urls.first, 'http://cam/foo1.jpg');
  });
}
