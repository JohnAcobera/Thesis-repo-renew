import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'handout_service.dart';

abstract interface class HandoutPdfExporter {
  Future<void> export(StudyHandout handout);
}

class PrintingHandoutPdfExporter implements HandoutPdfExporter {
  @override
  Future<void> export(StudyHandout handout) async {
    final bytes = await render(handout);
    final bool shared;
    try {
      shared = await Printing.sharePdf(
        bytes: bytes,
        filename: _pdfFileName(handout.title),
      );
    } on MissingPluginException {
      throw const HandoutPdfExportException(
        'PDF support is not registered in this app instance. Fully close and '
        'rebuild/relaunch the Windows app; hot reload cannot load native '
        'plugins.',
      );
    }
    if (!shared) {
      throw const HandoutPdfExportException(
        'The PDF could not be opened for download or sharing.',
      );
    }
  }

  Future<Uint8List> render(StudyHandout handout) async {
    final document = pw.Document();
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final symbolsFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansSymbols-Regular.ttf'),
    );
    final symbols2Font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf'),
    );
    final titleColor = _pdfColor(handout.style.titleColor);
    final termsColor = _pdfColor(handout.style.termsColor);
    final definitionsColor = _pdfColor(handout.style.definitionsColor);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(44),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
          fontFallback: [symbolsFont, symbols2Font],
        ),
        build: (context) => [
          pw.Text(
            handout.title,
            style: pw.TextStyle(
              color: titleColor,
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            handout.summary,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
          pw.SizedBox(height: 20),
          for (final section in handout.sections) ...[
            pw.Header(
              level: 1,
              child: pw.Text(
                section.heading,
                style: pw.TextStyle(
                  color: titleColor,
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (section.overview.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  section.overview,
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                ),
              ),
            for (final subsection in section.subsections) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
                child: pw.Text(
                  subsection.heading,
                  style: pw.TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (subsection.explanation.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    subsection.explanation,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                  ),
                ),
              for (var index = 0; index < subsection.items.length; index++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 18,
                        child: pw.Text(
                          subsection.style == HandoutListStyle.numbered
                              ? '${index + 1}.'
                              : '-',
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          subsection.items[index],
                          style: const pw.TextStyle(
                            fontSize: 10,
                            lineSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
          pw.Header(
            level: 1,
            child: pw.Text(
              'Key terms',
              style: pw.TextStyle(
                color: titleColor,
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          for (final term in handout.terms)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    term.term,
                    style: pw.TextStyle(
                      color: termsColor,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    term.definition,
                    style: pw.TextStyle(color: definitionsColor),
                  ),
                ],
              ),
            ),
          if (handout.keyTakeaways.isNotEmpty) ...[
            pw.Header(
              level: 1,
              child: pw.Text(
                'Key takeaways',
                style: pw.TextStyle(
                  color: titleColor,
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            for (final takeaway in handout.keyTakeaways)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(width: 18, child: pw.Text('-')),
                    pw.Expanded(
                      child: pw.Text(
                        takeaway,
                        style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );

    return document.save();
  }
}

class HandoutPdfExportException implements Exception {
  const HandoutPdfExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

PdfColor _pdfColor(Color color) => PdfColor.fromInt(color.toARGB32());

String _pdfFileName(String title) {
  final safeTitle = title
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
      .trim();
  final baseName = safeTitle.isEmpty ? 'study-handout' : safeTitle;
  return '$baseName.pdf';
}
