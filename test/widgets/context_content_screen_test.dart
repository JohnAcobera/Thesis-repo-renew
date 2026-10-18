import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/context_content_screen.dart';
import 'package:thesis_repo_renew/screens/home/student_home_screen.dart';
import 'package:thesis_repo_renew/services/handout_pdf_exporter.dart';
import 'package:thesis_repo_renew/services/handout_service.dart';

void main() {
  testWidgets('dashboard content action opens the context screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentHomeScreen(
          user: UserModel(
            id: 1,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final contentButton = find.widgetWithText(
      OutlinedButton,
      'Generate content',
    );
    await tester.ensureVisible(contentButton);
    await tester.pumpAndSettle();
    await tester.tap(contentButton);
    await tester.pumpAndSettle();

    expect(find.byType(ContextContentScreen), findsOneWidget);
  });

  testWidgets('context is limited to 200 characters', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContextContentScreen()));

    final contextField = tester.widget<TextField>(find.byType(TextField));
    expect(contextField.inputFormatters, isNotEmpty);

    await tester.enterText(find.byType(TextField), 'x' * 201);
    await tester.pump();
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.controller.text, hasLength(200));
    expect(find.text('200/200'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '😀' * 101);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      hasLength(200),
    );
  });

  testWidgets('color palette updates the preview text color', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContextContentScreen()));

    expect(find.text('Start with an idea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final paletteButton = find.widgetWithText(OutlinedButton, 'Palette').first;
    await _selectColor(tester, paletteButton, 'Green');

    final previewTitle = tester.widget<Text>(find.text('Preview'));
    expect(previewTitle.style?.color, const Color(0xFF388343));
  });

  testWidgets('generation displays structured content and exports its PDF', (
    tester,
  ) async {
    final generator = _FakeHandoutGenerator();
    final exporter = _FakeHandoutPdfExporter();
    await tester.pumpWidget(
      MaterialApp(
        home: ContextContentScreen(generator: generator, pdfExporter: exporter),
      ),
    );
    await tester.enterText(find.byType(TextField), 'The water cycle');
    final titlePalette = find.widgetWithText(OutlinedButton, 'Palette').first;
    await _selectColor(tester, titlePalette, 'Green');
    final generateButton = find.text('Generate content');
    await tester.ensureVisible(generateButton);
    await tester.pumpAndSettle();
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(generator.context, 'The water cycle');
    expect(generator.style?.titleColor, const Color(0xFF388343));
    expect(find.text('Water Cycle'), findsOneWidget);
    expect(find.text('Evaporation'), findsOneWidget);
    expect(find.text('Water balance'), findsOneWidget);
    expect(find.text('Key takeaways'), findsOneWidget);
    expect(find.text('Solar energy drives the cycle.'), findsOneWidget);

    final termsPalette = find.widgetWithText(OutlinedButton, 'Palette').at(1);
    await _selectColor(tester, termsPalette, 'Red');
    expect(
      tester.widget<Text>(find.text('Evaporation')).style?.color,
      const Color(0xFFB54040),
    );

    final downloadButton = find.text('Download PDF');
    await tester.ensureVisible(downloadButton);
    await tester.pumpAndSettle();
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();
    expect(exporter.exportedHandout?.title, 'Water Cycle');
    expect(exporter.exportedHandout?.style.termsColor, const Color(0xFFB54040));
  });

  testWidgets('long handouts scroll in preview while download stays visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ContextContentScreen(
          generator: _FakeHandoutGenerator(longOutput: true),
          pdfExporter: _FakeHandoutPdfExporter(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'The water cycle');
    await tester.tap(find.text('Generate content'));
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('generated-handout-scroll'));
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    final previewRect = tester.getRect(preview);
    final downloadButton = find.text('Download PDF');
    final downloadRect = tester.getRect(downloadButton);
    expect(downloadRect.bottom, lessThanOrEqualTo(640));
    expect(downloadRect.top, greaterThan(400));
    expect(find.text('Start with an idea'), findsOneWidget);
    expect(previewRect.height, lessThan(300));

    await tester.ensureVisible(find.text('Cycle detail 40.'));
    await tester.pumpAndSettle();

    final lastDetailRect = tester.getRect(find.text('Cycle detail 40.'));
    final scrolledPreviewRect = tester.getRect(preview);
    expect(lastDetailRect.top, greaterThanOrEqualTo(scrolledPreviewRect.top));
    expect(
      lastDetailRect.bottom,
      lessThanOrEqualTo(scrolledPreviewRect.bottom),
    );
    expect(tester.getRect(downloadButton), downloadRect);
  });
}

Future<void> _selectColor(
  WidgetTester tester,
  Finder paletteButton,
  String colorName,
) async {
  tester.widget<OutlinedButton>(paletteButton).onPressed!();
  await tester.pumpAndSettle();
  final swatch = tester.widget<InkWell>(
    find.descendant(
      of: find.byTooltip(colorName),
      matching: find.byType(InkWell),
    ),
  );
  swatch.onTap!();
  await tester.pumpAndSettle();
}

class _FakeHandoutGenerator implements HandoutGenerator {
  _FakeHandoutGenerator({this.longOutput = false});

  final bool longOutput;
  String? context;
  HandoutStyle? style;

  @override
  Future<StudyHandout> generate({
    required String context,
    required HandoutStyle style,
  }) async {
    this.context = context;
    this.style = style;
    return StudyHandout(
      title: 'Water Cycle',
      summary: 'Water moves through Earth systems.',
      sections: [
        HandoutSection(
          heading: 'Water movement',
          overview: 'The Sun powers the cycle.',
          subsections: [
            HandoutSubsection(
              heading: 'Main stages',
              explanation: 'Heat turns liquid water into vapor.',
              style: HandoutListStyle.numbered,
              items: longOutput
                  ? List.generate(40, (index) => 'Cycle detail ${index + 1}.')
                  : ['Water evaporates.', 'Clouds form.'],
            ),
          ],
        ),
        HandoutSection(
          heading: 'Earth systems',
          overview: 'Water is stored in multiple places.',
          subsections: [
            HandoutSubsection(
              heading: 'Storage',
              explanation: 'Storage locations change over time.',
              style: HandoutListStyle.bullets,
              items: ['Water is stored in oceans.', 'Water is stored in ice.'],
            ),
          ],
        ),
        HandoutSection(
          heading: 'Water balance',
          overview: 'Water returns and continues circulating.',
          subsections: [
            HandoutSubsection(
              heading: 'Cycle',
              explanation: 'The stages repeat over time.',
              style: HandoutListStyle.bullets,
              items: ['Rain replenishes water.', 'Runoff reaches rivers.'],
            ),
          ],
        ),
      ],
      terms: const [
        HandoutTerm(
          term: 'Evaporation',
          definition: 'Liquid water becomes vapor.',
        ),
        HandoutTerm(
          term: 'Condensation',
          definition: 'Vapor cools into droplets.',
        ),
        HandoutTerm(
          term: 'Precipitation',
          definition: 'Water falls from clouds.',
        ),
      ],
      keyTakeaways: const [
        'Solar energy drives the cycle.',
        'Water continually moves through Earth systems.',
      ],
      style: style,
    );
  }
}

class _FakeHandoutPdfExporter implements HandoutPdfExporter {
  StudyHandout? exportedHandout;

  @override
  Future<void> export(StudyHandout handout) async {
    exportedHandout = handout;
  }
}
