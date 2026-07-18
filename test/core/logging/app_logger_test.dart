import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_logger.dart';

void main() {
  group('scrubUrl', () {
    test('masks xtream path credentials for movie/series/live', () {
      expect(
        scrubUrl('http://host:8080/movie/bob/hunter2/1234.mp4'),
        'http://host:8080/movie/****/****/1234.mp4',
      );
      expect(
        scrubUrl('http://host/live/u/p/99.ts'),
        'http://host/live/****/****/99.ts',
      );
      expect(
        scrubUrl('http://host/series/u/p/7.mkv'),
        'http://host/series/****/****/7.mkv',
      );
    });

    test('masks username/password query params', () {
      expect(
        scrubUrl('http://host/get.php?username=bob&password=hunter2&type=m3u'),
        'http://host/get.php?username=****&password=****&type=m3u',
      );
    });

    test('leaves credential-free urls untouched', () {
      const url = 'http://192.168.2.15:8000/bench-24fps.mp4';
      expect(scrubUrl(url), url);
    });
  });
}
