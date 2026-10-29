import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

void main() {
  group('ReversiaMoveAnnotation', () {
    test('isEmpty is true when neither tag nor note are set', () {
      expect(const ReversiaMoveAnnotation().isEmpty, isTrue);
    });

    test('isEmpty is true for a note that is only whitespace', () {
      expect(const ReversiaMoveAnnotation(note: '   ').isEmpty, isTrue);
    });

    test('isEmpty is false when a tag is set', () {
      expect(
        const ReversiaMoveAnnotation(tag: ReversiaMoveTag.good).isEmpty,
        isFalse,
      );
    });

    test('isEmpty is false when a non-blank note is set', () {
      expect(const ReversiaMoveAnnotation(note: 'メモ').isEmpty, isFalse);
    });
  });
}
