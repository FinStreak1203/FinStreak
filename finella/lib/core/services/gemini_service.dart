import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Thin wrapper around Google's Gemini API for Finella's AI features:
/// transaction categorisation, merchant-name cleanup, spending insights and
/// the chat coach. Every call is defensive — on any failure (missing key,
/// network, rate-limit, bad response) it returns a sensible non-AI fallback so
/// the app keeps working without Gemini.
class GeminiService {
  // Tried in order. Free-tier flash models are frequently overloaded (503) or
  // out of quota (429), so we fall through to the next on any failure. The
  // pinned gemini-2.0-flash alias has zero free-tier quota on this project, so
  // it's intentionally left out. Edit/reorder this list to change models.
  static const List<String> _modelCandidates = [
    'gemini-2.5-flash',
    'gemini-flash-latest',
    'gemini-2.5-flash-lite',
    'gemini-flash-lite-latest',
  ];

  final String _apiKey;
  final Map<String, GenerativeModel> _modelCache = {};

  GeminiService()
      : _apiKey = dotenv.isInitialized
            ? (dotenv.maybeGet('GEMINI_API_KEY') ?? '')
            : '' {
    if (!isEnabled) {
      debugPrint('GeminiService: no API key set — AI features will fall back.');
    }
  }

  /// True when a usable API key is configured.
  bool get isEnabled =>
      _apiKey.isNotEmpty && _apiKey != 'your_actual_api_key_here';

  GenerativeModel _modelFor(String name) => _modelCache.putIfAbsent(
        name,
        () => GenerativeModel(model: name, apiKey: _apiKey),
      );

  /// One-line, plain-text generation shared by every method below. Walks the
  /// candidate models and returns the first success; null only if AI is off or
  /// every model fails (overloaded / quota / error), so callers can fall back.
  Future<String?> _generate(String prompt) async {
    if (!isEnabled) return null;
    final content = [Content.text(prompt)];
    for (final name in _modelCandidates) {
      try {
        final response = await _modelFor(name).generateContent(content);
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) return text;
      } catch (e) {
        // 503 overloaded / 429 quota / transient — try the next model.
        debugPrint('Gemini ($name) failed, trying next: $e');
      }
    }
    debugPrint('Gemini: all models failed.');
    return null;
  }

  static const List<String> _validCategories = [
    'Food', 'Shopping', 'Transport', 'Health', 'Entertainment', 'Education',
    'Utilities', 'Insurance', 'Finance', 'Transfer', 'Cash', 'Other',
  ];

  // ── 1 — Categorize a transaction ───────────────────────────────────────
  Future<String> categorizeTransaction({
    required String merchant,
    required double amount,
    required String type,
  }) async {
    final prompt = '''
Categorize this Indian bank transaction into EXACTLY ONE category from this list:
Food, Shopping, Transport, Health, Entertainment, Education, Utilities,
Insurance, Finance, Transfer, Cash, Other.

Merchant: $merchant
Amount: ₹$amount
Type: $type

Rules:
- Reply with ONLY the category name
- No explanation, no punctuation
- Just one word from the list above

Examples:
SWIGGY → Food
AMAZON → Shopping
UBER → Transport
APOLLO PHARMACY → Health
NETFLIX → Entertainment
HDFC LIFE → Insurance
ATM WITHDRAWAL → Cash
UPI TRANSFER → Transfer
''';
    final result = await _generate(prompt) ?? 'Other';
    return _validCategories.contains(result) ? result : 'Other';
  }

  // ── 2 — Clean up a raw merchant name ───────────────────────────────────
  Future<String> cleanMerchantName(String rawMerchant) async {
    if (rawMerchant.trim().isEmpty) return rawMerchant;
    final prompt = '''
Clean up this merchant name from an Indian bank transaction alert.

Input: $rawMerchant

Rules:
- Return ONLY the clean merchant name
- No explanation
- Fix ALL CAPS to proper case
- Expand known abbreviations
- Max 3 words

Examples:
WESTSIDEAUNITOFTREN → Westside
SWIGGY → Swiggy
AIRTELPREDIRECT1 → Airtel
APOLLOPHARMACY → Apollo Pharmacy
ZOMATOONLINE → Zomato
''';
    return await _generate(prompt) ?? rawMerchant;
  }

  // ── 3 — Financial insight for a period ─────────────────────────────────
  Future<String> getFinancialInsight({
    required Map<String, double> categoryTotals,
    required double totalExpense,
    required double totalIncome,
    required String period,
  }) async {
    final categoryBreakdown = categoryTotals.entries
        .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}')
        .join('\n');
    final prompt = '''
You are Finella, an AI financial coach for Indian users.

User's spending for $period:
Total Income : ₹${totalIncome.toStringAsFixed(0)}
Total Expense: ₹${totalExpense.toStringAsFixed(0)}

Category breakdown:
$categoryBreakdown

Give ONE short, friendly financial insight (2-3 sentences max).
Use ₹ symbol.
Be specific with numbers.
Suggest one improvement.
''';
    return await _generate(prompt) ?? 'Keep tracking your expenses!';
  }

  // ── 4 — Finella AI chat ────────────────────────────────────────────────
  Future<String> chat({
    required String userMessage,
    required String transactionContext,
  }) async {
    final prompt = '''
You are Finella, a friendly AI financial coach for Indian users.

User's financial context:
$transactionContext

User asks: $userMessage

Rules:
- Answer in simple English
- Use ₹ for Indian Rupees
- Be friendly and encouraging
- Keep response under 100 words
- Give actionable advice
''';
    return await _generate(prompt) ??
        'Something went wrong. Please try again!';
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());
