import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/player/video_controller.dart';

void main() {
  test('withStartFragment adds a #t= start in seconds', () {
    expect(
      withStartFragment('http://h/movie/1.mkv', const Duration(seconds: 2304)),
      'http://h/movie/1.mkv#t=2304.000',
    );
    expect(
      withStartFragment(
        'http://h/1.mkv',
        const Duration(minutes: 1, milliseconds: 250),
      ),
      'http://h/1.mkv#t=60.250',
    );
  });

  test('withStartFragment keeps an existing fragment', () {
    expect(
      withStartFragment('http://h/1.mkv#x=1', const Duration(seconds: 5)),
      'http://h/1.mkv#x=1&t=5.000',
    );
  });
}
