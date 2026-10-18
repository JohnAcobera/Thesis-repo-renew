import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/services/learning_mode_service.dart';

void main() {
  group('Flashcard.fromJson', () {
    test('reads question, answer, and explanation', () {
      final card = Flashcard.fromJson({
        'question': 'What is osmosis?',
        'answer': 'Movement of water across a membrane.',
        'explanation': 'Water moves toward the higher solute concentration.',
        'hint':
            'Think of water moving through a selectively permeable barrier.',
      });

      expect(card.question, 'What is osmosis?');
      expect(card.answer, 'Movement of water across a membrane.');
      expect(card.explanation, contains('higher solute concentration'));
      expect(card.hint, contains('selectively permeable'));
    });

    test('rejects incomplete content', () {
      expect(
        () => Flashcard.fromJson({
          'question': 'What is osmosis?',
          'answer': '',
          'explanation': 'A hint.',
        }),
        throwsFormatException,
      );
    });
  });

  group('MatchingPair.fromJson', () {
    test('reads both sides of a matching pair', () {
      final pair = MatchingPair.fromJson({
        'left': 'Mitochondrion',
        'right': 'Produces cellular energy',
        'explanation': 'It produces most of the cell ATP.',
      });

      expect(pair.left, 'Mitochondrion');
      expect(pair.right, 'Produces cellular energy');
    });
  });

  test('learning inventory item includes attempt score and type', () {
    final item = LearningInventoryItem.fromJson({
      'id': 'activity-id',
      'item_type': 'matching',
      'title': 'Cell structures',
      'source_file': 'biology.txt',
      'content': [
        {
          'left': 'Nucleus',
          'right': 'Stores genetic information',
          'explanation': 'The nucleus holds the DNA.',
        },
      ],
      'created_at': '2026-10-18T00:00:00Z',
      'attempts': [
        {'score': 8, 'total_items': 10, 'created_at': '2026-10-18T01:00:00Z'},
      ],
    });

    expect(item.type, LearningActivityType.matching);
    expect(item.matchingPairs.single.left, 'Nucleus');
    expect(item.itemCount, 1);
    expect(item.attemptCount, 1);
    expect(item.bestScore, 80);
  });
}
