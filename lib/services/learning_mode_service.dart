import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

enum LearningActivityType { flashcards, matching }

String inventoryFavoriteKey(String itemType, String itemId) =>
    '$itemType:$itemId';

class Flashcard {
  const Flashcard({
    required this.question,
    required this.answer,
    required this.explanation,
    this.hint = '',
  });

  final String question;
  final String answer;
  final String explanation;
  final String hint;

  Map<String, dynamic> toJson() => {
    'question': question,
    'answer': answer,
    'explanation': explanation,
    'hint': hint,
  };

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    final hint = json['hint'];
    if (hint != null && hint is! String) {
      throw const FormatException('A generated flashcard was invalid.');
    }
    return Flashcard(
      question: _requiredString(json, 'question'),
      answer: _requiredString(json, 'answer'),
      explanation: _requiredString(json, 'explanation'),
      hint: hint as String? ?? '',
    );
  }
}

class MatchingPair {
  const MatchingPair({
    required this.left,
    required this.right,
    required this.explanation,
  });

  final String left;
  final String right;
  final String explanation;

  Map<String, dynamic> toJson() => {
    'left': left,
    'right': right,
    'explanation': explanation,
  };

  factory MatchingPair.fromJson(Map<String, dynamic> json) => MatchingPair(
    left: _requiredString(json, 'left'),
    right: _requiredString(json, 'right'),
    explanation: _requiredString(json, 'explanation'),
  );
}

class LearningInventoryAttempt {
  const LearningInventoryAttempt({
    required this.score,
    required this.totalItems,
    required this.createdAt,
  });

  final int score;
  final int totalItems;
  final DateTime createdAt;

  double get percentage => totalItems == 0 ? 0 : score / totalItems * 100;

  factory LearningInventoryAttempt.fromJson(Map<String, dynamic> json) =>
      LearningInventoryAttempt(
        score: (json['score'] as num).toInt(),
        totalItems: (json['total_items'] as num).toInt(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class LearningInventoryItem {
  const LearningInventoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.sourceFile,
    required this.createdAt,
    required this.flashcards,
    required this.matchingPairs,
    required this.attempts,
  });

  final String id;
  final LearningActivityType type;
  final String title;
  final String sourceFile;
  final DateTime createdAt;
  final List<Flashcard> flashcards;
  final List<MatchingPair> matchingPairs;
  final List<LearningInventoryAttempt> attempts;

  int get itemCount => type == LearningActivityType.flashcards
      ? flashcards.length
      : matchingPairs.length;

  int get attemptCount => attempts.length;

  double get bestScore => attempts.fold<double>(
    0,
    (best, attempt) => attempt.percentage > best ? attempt.percentage : best,
  );

  DateTime get lastActivity =>
      attempts.isEmpty ? createdAt : attempts.first.createdAt;

  factory LearningInventoryItem.fromJson(Map<String, dynamic> json) {
    final type = switch (json['item_type']) {
      'flashcards' => LearningActivityType.flashcards,
      'matching' => LearningActivityType.matching,
      _ => throw const FormatException('Invalid learning activity type.'),
    };
    final content = json['content'];
    if (content is! List) {
      throw const FormatException('The saved learning activity is invalid.');
    }
    final attemptsJson = json['attempts'];
    if (attemptsJson is! List) {
      throw const FormatException('The saved learning activity is invalid.');
    }
    final attempts = attemptsJson
        .map(
          (attempt) => LearningInventoryAttempt.fromJson(
            Map<String, dynamic>.from(attempt as Map),
          ),
        )
        .toList(growable: false);
    final entries = content
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList(growable: false);
    return LearningInventoryItem(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String,
      sourceFile: json['source_file'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      flashcards: type == LearningActivityType.flashcards
          ? entries.map(Flashcard.fromJson).toList(growable: false)
          : const [],
      matchingPairs: type == LearningActivityType.matching
          ? entries.map(MatchingPair.fromJson).toList(growable: false)
          : const [],
      attempts: attempts,
    );
  }
}

class LearningModeService {
  LearningModeService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  Future<Set<String>> inventoryFavorites() async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_learning_inventory_favorites',
        params: {'p_session_token': token},
      );
      return response.map((item) {
        final favorite = Map<String, dynamic>.from(item as Map);
        final type = favorite['item_type'];
        final id = favorite['item_id'];
        if (type is! String || id is! String) {
          throw const FormatException('A saved favorite was invalid.');
        }
        return inventoryFavoriteKey(type, id);
      }).toSet();
    } on PostgrestException catch (error) {
      throw LearningModeServiceException(
        _sessionAwareMessage(error, 'Your favorites could not be loaded.'),
      );
    } on FormatException {
      throw const LearningModeServiceException(
        'Your favorites could not be read.',
      );
    } on TypeError {
      throw const LearningModeServiceException(
        'Your favorites could not be read.',
      );
    }
  }

  Future<void> setInventoryFavorite({
    required String itemType,
    required String itemId,
    required bool isFavorite,
  }) async {
    if (!const {'quiz', 'flashcards', 'matching'}.contains(itemType)) {
      throw const LearningModeServiceException(
        'This activity cannot be favorited.',
      );
    }
    final token = await _requireSessionToken();
    try {
      await _client.rpc<void>(
        'set_learning_inventory_favorite',
        params: {
          'p_session_token': token,
          'p_item_type': itemType,
          'p_item_id': itemId,
          'p_is_favorite': isFavorite,
        },
      );
    } on PostgrestException catch (error) {
      throw LearningModeServiceException(
        _sessionAwareMessage(
          error,
          isFavorite
              ? 'This activity could not be added to favorites.'
              : 'This activity could not be removed from favorites.',
        ),
      );
    }
  }

  Future<List<Flashcard>> generateFlashcards({
    required int itemCount,
    required String fileName,
    required String sourceText,
  }) async {
    final response = await _generate(
      functionName: 'generate-flashcards',
      resultKey: 'cards',
      itemCount: itemCount,
      fileName: fileName,
      sourceText: sourceText,
    );
    try {
      return response
          .map(
            (item) =>
                Flashcard.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on Object {
      throw const LearningModeServiceException(
        'The generated flashcards were invalid. Please generate them again.',
      );
    }
  }

  Future<List<MatchingPair>> generateMatchingPairs({
    required int itemCount,
    required String fileName,
    required String sourceText,
  }) async {
    final response = await _generate(
      functionName: 'generate-matching',
      resultKey: 'pairs',
      itemCount: itemCount,
      fileName: fileName,
      sourceText: sourceText,
    );
    try {
      return response
          .map(
            (item) =>
                MatchingPair.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on Object {
      throw const LearningModeServiceException(
        'The generated matching activity was invalid. Please generate it again.',
      );
    }
  }

  Future<List<dynamic>> _generate({
    required String functionName,
    required String resultKey,
    required int itemCount,
    required String fileName,
    required String sourceText,
  }) async {
    if (itemCount < 1 || itemCount > 30) {
      throw const LearningModeServiceException(
        'Choose between 1 and 30 items.',
      );
    }
    final token = await _requireSessionToken();
    FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        functionName,
        body: {
          'sessionToken': token,
          'questionCount': itemCount,
          'sourceFileName': fileName,
          'sourceText': sourceText,
        },
      );
    } on FunctionException catch (error) {
      throw LearningModeServiceException(
        error.status == 0
            ? 'Could not connect to the learning service. Please try again.'
            : 'The learning activity could not be generated. Please try again.',
      );
    }
    final payload = response.data;
    if (response.status < 200 || response.status >= 300) {
      throw const LearningModeServiceException(
        'The learning activity could not be generated. Please try again.',
      );
    }
    if (payload is! Map || payload[resultKey] is! List) {
      throw const LearningModeServiceException(
        'The learning service returned an invalid response.',
      );
    }
    final items = payload[resultKey] as List<dynamic>;
    if (items.length != itemCount) {
      throw const LearningModeServiceException(
        'The generated activity was incomplete. Please generate it again.',
      );
    }
    return items;
  }

  Future<String> saveActivity({
    required LearningActivityType type,
    required String title,
    required String sourceFile,
    required List<Map<String, dynamic>> content,
  }) async {
    final token = await _requireSessionToken();
    try {
      return await _client.rpc<String>(
        'save_learning_inventory_item',
        params: {
          'p_session_token': token,
          'p_item_type': type.name,
          'p_title': title,
          'p_source_file': sourceFile,
          'p_content': content,
        },
      );
    } on PostgrestException catch (error) {
      throw LearningModeServiceException(
        _sessionAwareMessage(
          error,
          'The learning activity could not be saved. Please try again.',
        ),
      );
    }
  }

  Future<void> saveAttempt({
    required String itemId,
    required int score,
    required int totalItems,
  }) async {
    final token = await _requireSessionToken();
    try {
      await _client.rpc<void>(
        'save_learning_inventory_attempt',
        params: {
          'p_session_token': token,
          'p_item_id': itemId,
          'p_score': score,
          'p_total_items': totalItems,
        },
      );
    } on PostgrestException catch (error) {
      throw LearningModeServiceException(
        _sessionAwareMessage(
          error,
          'Your learning activity could not be saved. Please try again.',
        ),
      );
    }
  }

  Future<List<LearningInventoryItem>> inventoryItems() async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_learning_inventory_items',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (item) => LearningInventoryItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw LearningModeServiceException(
        _sessionAwareMessage(
          error,
          'Your learning inventory could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const LearningModeServiceException(
        'Your learning inventory could not be read.',
      );
    } on TypeError {
      throw const LearningModeServiceException(
        'Your learning inventory could not be read.',
      );
    }
  }

  Future<String> _requireSessionToken() async {
    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const LearningModeServiceException(
        'Your session has expired. Please log in again.',
      );
    }
    return token;
  }

  String _sessionAwareMessage(PostgrestException error, String fallback) =>
      error.message.contains('Invalid or expired session')
      ? 'Your session has expired. Please log in again.'
      : fallback;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('A generated learning item was invalid.');
  }
  return value;
}

class LearningModeServiceException implements Exception {
  const LearningModeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
