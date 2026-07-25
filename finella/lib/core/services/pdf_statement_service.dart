import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../parser/axis_parser.dart';
import '../parser/icici_statement_extractor.dart';
import 'email_parser_service.dart' show ParsedTransaction;

/// Thrown when a statement PDF is password-protected (ICICI monthly
/// e-statements usually are). The UI surfaces this distinctly so it can ask
/// for the password instead of showing a generic failure.
class PdfPasswordRequiredException implements Exception {
  const PdfPasswordRequiredException();
}

/// Extracts transactions from a bank-statement PDF.
///
/// Reads the PDF's layout-preserving text and routes it to the matching bank
/// extractor. Today only ICICI savings-account statements are supported; the
/// bank is detected from the document text so more can be added later.
class PdfStatementService {
  const PdfStatementService();

  /// Parses [bytes] (the raw PDF) into transactions. [password] is used for
  /// encrypted statements. Throws [PdfPasswordRequiredException] when the file
  /// is encrypted and no/insufficient password was given.
  List<ParsedTransaction> parse(Uint8List bytes, {String? password}) {
    PdfDocument? doc;
    try {
      doc = password != null && password.isNotEmpty
          ? PdfDocument(inputBytes: bytes, password: password)
          : PdfDocument(inputBytes: bytes);
    } catch (e) {
      // Syncfusion throws when an encrypted doc is opened without the right
      // password. Normalise that to our typed exception.
      final msg = e.toString().toLowerCase();
      if (msg.contains('password') || msg.contains('encrypt')) {
        throw const PdfPasswordRequiredException();
      }
      rethrow;
    }

    try {
      debugPrint('📄 PDF: opened, pages=${doc.pages.count}, '
          'bytes=${bytes.length}');

      // NOTE: extractText(layoutText: true) silently drops ~13% of rows on
      // these statements. extractTextLines() returns every line intact (dates
      // at line start, amount + balance space-separated), so use that.
      final text =
          PdfTextExtractor(doc).extractTextLines().map((l) => l.text).join('\n');
      // Route to the matching bank parser. Axis first (distinct UTIB/AXIS
      // markers), else fall back to the ICICI extractor.
      final List<ParsedTransaction> txs;
      final String bank;
      if (_looksLikeAxis(text)) {
        bank = 'Axis';
        txs = AxisParser.parseStatementText(text);
      } else {
        bank = 'ICICI';
        txs = IciciStatementExtractor.parse(text);
      }
      debugPrint('📄 PDF: textLines length=${text.length}, '
          'bank=$bank, parsed transactions=${txs.length}');
      // Only dump the raw text when we found nothing — that's when we need it
      // to diagnose an unrecognised statement layout.
      if (txs.isEmpty) _dumpText(text);
      return txs;
    } finally {
      doc.dispose();
    }
  }

  /// Logs the extracted text in chunks so the full layout is visible in the
  /// console (debugPrint truncates long single lines). Helps diagnose why a
  /// statement layout isn't recognised.
  void _dumpText(String text) {
    final lines = text.split('\n');
    debugPrint('📄 PDF: ── extracted text (${lines.length} lines) ──');
    final limit = lines.length < 80 ? lines.length : 80;
    for (var i = 0; i < limit; i++) {
      debugPrint('📄│${i.toString().padLeft(3)}│${lines[i]}');
    }
    if (lines.length > limit) {
      debugPrint('📄│ … ${lines.length - limit} more lines …');
    }
    debugPrint('📄 PDF: ── end extracted text ──');
  }

  bool _looksLikeAxis(String text) {
    final t = text.toLowerCase();
    return t.contains('axis bank') ||
        t.contains('statement of axis') ||
        t.contains('utib0'); // Axis IFSC prefix
  }
}

final pdfStatementServiceProvider =
    Provider<PdfStatementService>((ref) => const PdfStatementService());
