import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/learning_mode_service.dart';

void main() {
  test('does not expose Edge Function error details to the caller', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({'error': 'Internal provider key or endpoint diagnostic'}),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = LearningModeService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.generateFlashcards(
        itemCount: 1,
        fileName: 'biology.pdf',
        sourceText: 'Cells store genetic information.',
      ),
      throwsA(
        isA<LearningModeServiceException>().having(
          (error) => error.message,
          'message',
          'The learning activity could not be generated. Please try again.',
        ),
      ),
    );
    await client.dispose();
  });

  test('favorite keys distinguish activities by type and id', () {
    expect(inventoryFavoriteKey('quiz', 'activity-id'), 'quiz:activity-id');
    expect(
      inventoryFavoriteKey('flashcards', 'activity-id'),
      'flashcards:activity-id',
    );
  });

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

SupabaseClient _supabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) => SupabaseClient(
  'https://example.supabase.co',
  'test-anon-key',
  httpClient: MockClient(handler),
);

class _TestAuthService extends AuthService {
  _TestAuthService(SupabaseClient client) : super(client: client);

  @override
  Future<String?> getSessionToken() async => 's' * 40;
}
