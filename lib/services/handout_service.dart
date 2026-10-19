import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

const _maxHandoutSections = 4;
const _maxHandoutSubsections = 3;
const _maxHandoutTerms = 8;

// The Edge Function may append a period after truncating text at its limit.
const _maxTitleLength = 101;
const _maxSummaryLength = 601;
const _maxHeadingLength = 81;
const _maxOverviewLength = 601;
const _maxExplanationLength = 1301;
const _maxItemLength = 351;
const _maxTermLength = 61;
const _maxDefinitionLength = 351;

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

    if (sections.length < 3 || sections.length > _maxHandoutSections) {
      throw const FormatException('The handout sections were invalid.');
    }
    if (terms.length < 4 || terms.length > _maxHandoutTerms) {
      throw const FormatException('The handout terms were invalid.');
    }
    final takeawaysValue = handout['keyTakeaways'];
    final rawTakeaways = takeawaysValue == null
        ? const <dynamic>[]
        : _readList(takeawaysValue, 'key takeaways');
    final keyTakeaways = rawTakeaways
        .map((item) => _readText(item, 'key takeaway', 300))
        .toList(growable: false);
    if (keyTakeaways.length > 8) {
      throw const FormatException('The handout key takeaways were invalid.');
    }

    return StudyHandout(
      title: _readText(handout['title'], 'title', _maxTitleLength),
      summary: _readText(handout['summary'], 'summary', _maxSummaryLength),
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
      throw HandoutServiceException(
        _functionFailureMessage(status: error.status),
      );
    }

    if (response.status < 200 || response.status >= 300) {
      throw HandoutServiceException(
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
  if (subsections.isEmpty || subsections.length > _maxHandoutSubsections) {
    throw const FormatException('A handout section was invalid.');
  }
  return HandoutSection(
    heading: _readText(json['heading'], 'section heading', _maxHeadingLength),
    overview: _readText(
      json['overview'],
      'section overview',
      _maxOverviewLength,
      allowEmpty: true,
    ),
    subsections: subsections,
  );
}

HandoutSubsection _readSubsection(Object? value) {
  final json = _readObject(value, 'subsection');
  final style = switch (json['style']) {
    'bullets' => HandoutListStyle.bullets,
    'numbered' => HandoutListStyle.numbered,
    _ => throw const FormatException('A handout list style was invalid.'),
  };
  final rawItems = _readList(json['items'], 'items');
  final items = rawItems
      .map((item) => _readText(item, 'item', _maxItemLength))
      .expand(
        (item) => style == HandoutListStyle.numbered
            ? _splitInlineNumberedItems(item)
            : [item],
      )
      .toList(growable: false);
  if (items.length > 5) {
    throw const FormatException('A handout subsection was invalid.');
  }

  final heading = _readText(
    json['heading'],
    'subsection heading',
    _maxHeadingLength,
  );
  final explanation = _readText(
    json['explanation'],
    'subsection explanation',
    _maxExplanationLength,
    allowEmpty: true,
  );
  if (items.isEmpty && explanation.isEmpty) {
    throw const FormatException('A handout subsection was invalid.');
  }

  return HandoutSubsection(
    heading: heading,
    explanation: explanation,
    style: style,
    items: items,
  );
}

List<String> _splitInlineNumberedItems(String item) {
  final markers = RegExp(
    r'(?:^|;\s*)(\d{1,2})[.)]\s+',
  ).allMatches(item).toList(growable: false);
  if (markers.length < 2 ||
      markers.first.start != 0 ||
      markers.indexed.any((entry) => int.parse(entry.$2[1]!) != entry.$1 + 1)) {
    return [item];
  }

  return [
    for (var index = 0; index < markers.length; index++)
      item
          .substring(
            markers[index].end,
            index + 1 < markers.length ? markers[index + 1].start : item.length,
          )
          .replaceFirst(RegExp(r';\s*$'), '')
          .trim(),
  ];
}

HandoutTerm _readTerm(Object? value) {
  final json = _readObject(value, 'term');
  return HandoutTerm(
    term: _readText(json['term'], 'term', _maxTermLength),
    definition: _readText(
      json['definition'],
      'definition',
      _maxDefinitionLength,
    ),
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

String _functionFailureMessage({required int status}) {
  if (status == 0) {
    return 'Could not connect to the content service. Check your connection and try again.';
  }
  if (status == 404) {
    return 'The PDF generation function was not found. Deploy pdf-generation to your Supabase project.';
  }
  if (status == 401 || status == 403) {
    return 'Your session could not be verified. Please log in again.';
  }

  return 'Study content could not be generated. Please try again.';
}
