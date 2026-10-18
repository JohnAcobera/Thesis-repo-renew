import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/handout_pdf_exporter.dart';
import 'package:thesis_repo_renew/services/handout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'invokes the function with context, custom session, and style',
    () async {
      Map<String, dynamic>? requestBody;
      Uri? requestUri;
      final client = _supabaseClient((request) async {
        requestUri = request.url;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_response()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = HandoutService(
        client: client,
        authService: _TestAuthService(client),
      );

      final handout = await service.generate(
        context: '  Water cycle  ',
        style: const HandoutStyle(
          titleColor: Color(0xFF388343),
          termsColor: Color(0xFF2764AE),
          definitionsColor: Color(0xFF725F53),
        ),
      );

      expect(handout.title, 'Water Cycle');
      expect(requestUri?.path, '/functions/v1/pdf-generation');
      expect(requestBody, {
        'sessionToken': 's' * 40,
        'context': 'Water cycle',
        'titleColor': '#388343',
        'termsColor': '#2764AE',
        'definitionsColor': '#725F53',
      });
      await client.dispose();
    },
  );

  test('does not expose Edge Function error details to the caller', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({'error': 'No supported AI API keys are configured.'}),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = HandoutService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.generate(
        context: 'Water cycle',
        style: const HandoutStyle(
          titleColor: Color(0xFF388343),
          termsColor: Color(0xFF2764AE),
          definitionsColor: Color(0xFF725F53),
        ),
      ),
      throwsA(
        isA<HandoutServiceException>().having(
          (error) => error.message,
          'message',
          'Study content could not be generated. Please try again.',
        ),
      ),
    );
    await client.dispose();
  });

  test('reports an undeployed function with a deployment hint', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        'Function not found',
        404,
        headers: {'content-type': 'text/plain'},
        reasonPhrase: 'Not Found',
      );
    });
    final service = HandoutService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.generate(
        context: 'Water cycle',
        style: const HandoutStyle(
          titleColor: Color(0xFF388343),
          termsColor: Color(0xFF2764AE),
          definitionsColor: Color(0xFF725F53),
        ),
      ),
      throwsA(
        isA<HandoutServiceException>().having(
          (error) => error.message,
          'message',
          contains('Deploy pdf-generation'),
        ),
      ),
    );
    await client.dispose();
  });

  test('parses the handout response and preserves its selected colors', () {
    final handout = StudyHandout.fromResponse(_response());

    expect(handout.title, 'Water Cycle');
    expect(handout.summary, 'Water moves through Earth systems.');
    expect(handout.sections, hasLength(3));
    expect(
      handout.sections.first.overview,
      'The Sun provides energy for movement.',
    );
    expect(
      handout.sections.first.subsections.first.explanation,
      'Heat changes liquid water into vapor.',
    );
    expect(
      handout.sections.first.subsections.first.style,
      HandoutListStyle.numbered,
    );
    expect(handout.terms.first.term, 'Evaporation');
    expect(handout.keyTakeaways, hasLength(2));
    expect(handout.style.titleColor, const Color(0xFF388343));
    expect(handout.style.termsColor, const Color(0xFF2764AE));
    expect(handout.style.toJson()['definitionsColor'], '#725F53');
  });

  test('rejects incomplete handout responses', () {
    final response = _response();
    (response['handout'] as Map<String, dynamic>)['terms'] = const [];

    expect(() => StudyHandout.fromResponse(response), throwsFormatException);
  });

  test('parses updated prose-first handouts without takeaways', () {
    final response = _response();
    final handout = response['handout'] as Map<String, dynamic>;
    handout.remove('keyTakeaways');
    final sections = handout['sections'] as List;
    final subsections =
        (sections.first as Map<String, dynamic>)['subsections'] as List;
    (subsections.first as Map<String, dynamic>)['items'] = const [];

    final parsed = StudyHandout.fromResponse(response);

    expect(parsed.keyTakeaways, isEmpty);
    expect(parsed.sections.first.subsections.first.items, isEmpty);
    expect(
      parsed.sections.first.subsections.first.explanation,
      'Heat changes liquid water into vapor.',
    );
  });

  test('renders a PDF with the handout structure', () async {
    final response = _response();
    final sections =
        (response['handout'] as Map<String, dynamic>)['sections'] as List;
    ((sections.first as Map<String, dynamic>)['subsections'] as List)
        .cast<Map<String, dynamic>>()
        .first['items'] = [
      'Liquid water changes into vapor → water vapor.',
      'It continues through the cycle.',
    ];
    final handout = StudyHandout.fromResponse(response);
    final bytes = await PrintingHandoutPdfExporter().render(handout);

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test(
    'explains how to recover when the native printing plugin is missing',
    () {
      final handout = StudyHandout.fromResponse(_response());

      expect(
        PrintingHandoutPdfExporter().export(handout),
        throwsA(
          isA<HandoutPdfExportException>().having(
            (error) => error.message,
            'message',
            contains('Fully close and rebuild/relaunch'),
          ),
        ),
      );
    },
  );
}

Map<String, dynamic> _response() => {
  'handout': {
    'title': 'Water Cycle',
    'summary': 'Water moves through Earth systems.',
    'sections': [
      {
        'heading': 'Water movement',
        'overview': 'The Sun provides energy for movement.',
        'subsections': [
          {
            'heading': 'Main stages',
            'explanation': 'Heat changes liquid water into vapor.',
            'style': 'numbered',
            'items': ['Water evaporates.', 'Clouds form.'],
          },
        ],
      },
      {
        'heading': 'Earth systems',
        'overview': '',
        'subsections': [
          {
            'heading': 'Storage',
            'explanation': '',
            'style': 'bullets',
            'items': ['Water is stored in oceans.', 'Water is stored in ice.'],
          },
        ],
      },
      {
        'heading': 'Water balance',
        'overview': 'Water returns to Earth and continues moving.',
        'subsections': [
          {
            'heading': 'Cycle',
            'explanation': 'The stages repeat over time.',
            'style': 'bullets',
            'items': ['Rain replenishes water.', 'Runoff reaches rivers.'],
          },
        ],
      },
    ],
    'terms': [
      {'term': 'Evaporation', 'definition': 'Liquid water becomes vapor.'},
      {'term': 'Condensation', 'definition': 'Vapor cools into droplets.'},
      {'term': 'Precipitation', 'definition': 'Water falls from clouds.'},
      {'term': 'Runoff', 'definition': 'Water flows over land.'},
    ],
    'keyTakeaways': [
      'Solar energy drives evaporation.',
      'Water continuously cycles through Earth systems.',
    ],
  },
  'style': {
    'titleColor': '#388343',
    'termsColor': '#2764AE',
    'definitionsColor': '#725F53',
  },
};

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
