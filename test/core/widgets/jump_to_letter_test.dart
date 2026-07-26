import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/widgets/jump_to_letter.dart';

void main() {
  group('buildLetterIndex', () {
    test('maps each letter to the first title that starts with it', () {
      final index = buildLetterIndex(['Alpha', 'Beta', 'Bravo', 'Delta']);
      expect(index['A'], 0);
      expect(index['B'], 1, reason: 'first B wins, not the last');
      expect(index['D'], 3);
      expect(index.containsKey('C'), isFalse);
    });

    test('is case- and whitespace-insensitive', () {
      final index = buildLetterIndex(['  zeta', 'Zulu']);
      expect(index['Z'], 0);
    });

    test('non-letter and empty titles bucket under #', () {
      final index = buildLetterIndex(['4K Sports', '', 'مسلسلات', 'Alpha']);
      expect(index[kOtherLetter], 0);
      expect(index['A'], 3);
    });

    test('works on an unsorted list — it indexes what is displayed', () {
      final index = buildLetterIndex(['Sky', 'BBC', 'Sport1', 'AlJazeera']);
      expect(index['S'], 0);
      expect(index['B'], 1);
      expect(index['A'], 3);
    });
  });
}
