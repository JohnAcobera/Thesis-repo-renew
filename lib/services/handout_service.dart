import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

enum HandoutListStyle { bullets, numbered }

class HandoutSubsection {
  const HandoutSubsection({
    required this.heading,
    required this.explanation,
    required this.style,
    required this.items,
  });

  final String heading;
  final String explanation;
  final HandoutListStyle style;
  final List<String> items;
}

class HandoutSection {
  const HandoutSection({
    required this.heading,
    required this.overview,
    required this.subsections,
  });

  final String heading;
  final String overview;
  final List<HandoutSubsection> subsections;
}

class HandoutTerm {
  const HandoutTerm({required this.term, required this.definition});

  final String term;
  final String definition;
}

class HandoutStyle {
  const HandoutStyle({
    required this.titleColor,
    required this.termsColor,
    required this.definitionsColor,
  });

  final Color titleColor;
  final Color termsColor;
  final Color definitionsColor;

  Map<String, String> toJson() => {
    'titleColor': _colorToHex(titleColor),
    'termsColor': _colorToHex(termsColor),
    'definitionsColor': _colorToHex(definitionsColor),
  };

  factory HandoutStyle.fromJson(Object? value) {
    final json = _readObject(value, 'style');
    return HandoutStyle(
      titleColor: _parseColor(json['titleColor'], 'titleColor'),
      termsColor: _parseColor(json['termsColor'], 'termsColor'),
      definitionsColor: _parseColor(
        json['definitionsColor'],
        'definitionsColor',
      ),
    );
  }
}

class StudyHandout {
  const StudyHandout({
    required this.title,
    required this.summary,
    required this.sections,
    required this.terms,
    required this.keyTakeaways,
    required this.style,
  });

  final String title;
  final String summary;
  final List<HandoutSection> sections;
  final List<HandoutTerm> terms;
  final List<String> keyTakeaways;
  final HandoutStyle style;

  StudyHandout copyWith({HandoutStyle? style}) => StudyHandout(
    title: title,
    summary: summary,
    sections: sections,
    terms: terms,
    keyTakeaways: keyTakeaways,
    style: style ?? this.style,
  );

  factory StudyHandout.fromResponse(Object? value) {
    final response = _readObject(value, 'response');
    final handout = _readObject(response['handout'], 'handout');
    final rawSections = _readList(handout['sections'], 'sections');
    final rawTerms = _readList(handout['terms'], 'terms');

    final sections = rawSections.map(_readSection).toList(growable: false);
    final terms = rawTerms.map(_readTerm).toList(growable: false);

    if (sections.length < 3 || sections.length > 8) {
      throw const FormatException('The handout sections were invalid.');
    }
    if (terms.length < 4 || terms.length > 15) {
      throw const FormatException('The handout terms were invalid.');
    }
    final rawTakeaways = _readList(handout['keyTakeaways'], 'key takeaways');
    final keyTakeaways = rawTakeaways
        .map((item) => _readText(item, 'key takeaway', 300))
        .toList(growable: false);
    if (keyTakeaways.length < 2 || keyTakeaways.length > 8) {
      throw const FormatException('The handout key takeaways were invalid.');
    }

    return StudyHandout(
      title: _readText(handout['title'], 'title', 120),
      summary: _readText(handout['summary'], 'summary', 700),
      sections: sections,
      terms: terms,
      keyTakeaways: keyTakeaways,
      style: HandoutStyle.fromJson(response['style']),
    );
  }
}

abstract interface class HandoutGenerator {
  Future<StudyHandout> generate({
    required String context,
    required HandoutStyle style,
  });
}

class HandoutService implements HandoutGenerator {
  HandoutService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  @override
  Future<StudyHandout> generate({
    required String context,
    required HandoutStyle style,
  }) async {
    final topic = context.trim();
    if (topic.isEmpty) {
      throw const HandoutServiceException(
        'Describe what you want to learn about.',
      );
    }
    if (topic.length > 200) {
      throw const HandoutServiceException(
        'Your context must be 200 characters or less.',
      );
    }

    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const HandoutServiceException(
        'Your session has expired. Please log in again.',
      );
    }

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'pdf-generation',
        body: {'sessionToken': token, 'context': topic, ...style.toJson()},
      );
    } on FunctionException catch (error) {
      final message = _readErrorMessage(error.details);
      throw HandoutServiceException(
        (error.status == 404 && _isMissingFunctionError(error.details)
                ? null
                : message) ??
            _functionFailureMessage(
              status: error.status,
              reasonPhrase: error.reasonPhrase,
              details: error.details,
            ),
      );
    }

    if (response.status < 200 || response.status >= 300) {
      throw HandoutServiceException(
        _readErrorMessage(response.data) ??
            'Study content could not be generated. Please try again.',
      );
    }

    try {
      return StudyHandout.fromResponse(response.data);
    } on FormatException {
      throw const HandoutServiceException(
        'The content service returned an invalid handout. Please try again.',
      );
    }
  }
}

class HandoutServiceException implements Exception {
  const HandoutServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

HandoutSection _readSection(Object? value) {
  final json = _readObject(value, 'section');
  final subsections = _readList(
    json['subsections'],
    'subsections',
  ).map(_readSubsection).toList(growable: false);
  if (subsections.isEmpty || subsections.length > 4) {
    throw const FormatException('A handout section was invalid.');
  }
  return HandoutSection(
    heading: _readText(json['heading'], 'section heading', 100),
    overview: _readText(
      json['overview'],
      'section overview',
      700,
      allowEmpty: true,
    ),
    subsections: subsections,
  );
}

HandoutSubsection _readSubsection(Object? value) {
  final json = _readObject(value, 'subsection');
  final rawItems = _readList(json['items'], 'items');
  final items = rawItems
      .map((item) => _readText(item, 'item', 400))
      .toList(growable: false);
  if (items.length < 2 || items.length > 8) {
    throw const FormatException('A handout subsection was invalid.');
  }

  final style = switch (json['style']) {
    'bullets' => HandoutListStyle.bullets,
    'numbered' => HandoutListStyle.numbered,
    _ => throw const FormatException('A handout list style was invalid.'),
  };
  return HandoutSubsection(
    heading: _readText(json['heading'], 'subsection heading', 100),
    explanation: _readText(
      json['explanation'],
      'subsection explanation',
      700,
      allowEmpty: true,
    ),
    style: style,
    items: items,
  );
}

HandoutTerm _readTerm(Object? value) {
  final json = _readObject(value, 'term');
  return HandoutTerm(
    term: _readText(json['term'], 'term', 80),
    definition: _readText(json['definition'], 'definition', 400),
  );
}

Map<String, dynamic> _readObject(Object? value, String label) {
  if (value is! Map) throw FormatException('The $label was invalid.');
  return Map<String, dynamic>.from(value);
}

List<dynamic> _readList(Object? value, String label) {
  if (value is! List) throw FormatException('The $label were invalid.');
  return value;
}

String _readText(
  Object? value,
  String label,
  int maxLength, {
  bool allowEmpty = false,
}) {
  if (value is! String) throw FormatException('The $label was invalid.');
  final text = value.trim();
  if ((!allowEmpty && text.isEmpty) || text.length > maxLength) {
    throw FormatException('The $label was invalid.');
  }
  return text;
}

Color _parseColor(Object? value, String label) {
  if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw FormatException('The $label was invalid.');
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}

String _colorToHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _functionFailureMessage({
  required int status,
  required String? reasonPhrase,
  required Object? details,
}) {
  if (status == 0) {
    return 'Could not connect to the content service. Check your connection and try again.';
  }
  if (status == 404) {
    return 'The PDF generation function was not found. Deploy pdf-generation to your Supabase project.';
  }
  if (status == 401 || status == 403) {
    return 'Your session could not be verified. Please log in again.';
  }

  final detail = details is String
      ? details.trim().replaceAll(RegExp(r'\s+'), ' ')
      : null;
  final safeDetail = detail == null || detail.isEmpty
      ? null
      : detail.substring(0, detail.length > 240 ? 240 : detail.length);
  final reason = reasonPhrase?.trim();
  final statusText = reason == null || reason.isEmpty
      ? 'HTTP $status'
      : 'HTTP $status ($reason)';
  return safeDetail == null
      ? 'The content service returned $statusText. Please try again.'
      : 'The content service returned $statusText: $safeDetail';
}

String? _readErrorMessage(Object? value) {
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    try {
      return _readErrorMessage(jsonDecode(text));
    } on FormatException {
      return text;
    }
  }
  if (value is! Map) return null;

  final error = value['error'];
  if (error is String && error.trim().isNotEmpty) return error.trim();
  if (error is Map) {
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  }
  final message = value['message'];
  return message is String && message.trim().isNotEmpty ? message.trim() : null;
}

bool _isMissingFunctionError(Object? value) {
  final message = _readErrorMessage(value)?.toLowerCase();
  return message == 'function not found' ||
      message == 'requested function was not found';
}
