import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';

void main() {
  test('fromJson savunmaci parse', () {
    final c = Camera.fromJson(
        {'id': 'c1', 'ad': 'Ana Giriş', 'stream_url': 'https://x/s.m3u8'});
    expect(c.ad, 'Ana Giriş');
    expect(c.streamUrl, 'https://x/s.m3u8');
    expect(Camera.fromJson(const {}).ad, '');
  });
}
