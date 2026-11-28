import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Client for FinStreak's AI features: transaction categorisation, merchant-name
/// cleanup, spending insights and the chat coach. Prompts go to our own API
/// (`/api/ai/generate`), which holds the Gemini key on the server, so no key is
/// shipped in the app. Every call is defensive: on any failure (not signed in,
/// no network, rate-limit, bad response) it returns a non-AI fallback so the
/// app keeps working without Gemini.
class GeminiService {
  // Base URL of the FinStreak web API. Set PAYMENTS_API_BASE in .env.
  final String _baseUrl;

  GeminiService()
      : _baseUrl = dotenv.isInitialized
            ? (dotenv.maybeGet('PAYMENTS_API_BASE') ?? '')
            : '' {
    if (!isEnabled) {
      debugPrint('GeminiService: no API base URL set — AI features will fall back.');
    }
  }

  /// True when the AI API base URL is configured.
  bool get isEnabled => _baseUrl.isNotEmpty;

  /// One-line, plain-text generation shared by every method below. Sends the
  /// prompt to the API with the user's Firebase ID token. Returns null if AI is
  /// off, the user is signed out, or the API fails, so callers can fall back.
  Future<String?> _generate(String prompt) async {
    if (!isEnabled) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Gemini: not signed in, using fallback.');
      return null;
    }
    try {
      final token = await user.getIdToken();
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/ai/generate'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        debugPrint('Gemini API ${res.statusCode}: ${res.body}');
        return null;
      }
      final text = (jsonDecode(res.body) as Map<String, dynamic>)['text'];
      final trimmed = text is String ? text.trim() : '';
      return trimmed.isEmpty ? null : trimmed;
    } catch (e) {
      debugPrint('Gemini API request failed: $e');
      return null;
    }
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
You are FinStreak, an AI financial coach for Indian users.

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

  // ── 4 — FinStreak AI chat ────────────────────────────────────────────────
  Future<String> chat({
    required String userMessage,
    required String transactionContext,
  }) async {
    final prompt = '''
You are FinStreak, a friendly AI financial coach for Indian users.

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
