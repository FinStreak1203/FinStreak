import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

enum PurchaseOutcome { success, cancelled, failed }

class PurchaseResult {
  final PurchaseOutcome outcome;
  final String? message;

  const PurchaseResult(this.outcome, [this.message]);
}

/// Runs a premium purchase: the server creates the order, Razorpay Checkout
/// collects payment, and the server verifies it and grants premium.
///
/// The app never holds the Razorpay key secret. It only sends the user's ID
/// token and the plan id; prices are decided on the server.
class PaymentService {
  Future<PurchaseResult> purchase({required String plan}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const PurchaseResult(PurchaseOutcome.failed, 'Please sign in again.');
    }

    final base = dotenv.maybeGet('PAYMENTS_API_BASE') ?? '';
    if (base.isEmpty) {
      return const PurchaseResult(PurchaseOutcome.failed, 'Payments are not set up yet.');
    }

    try {
      final token = await user.getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 1. Ask the server for an order.
      final orderRes = await http.post(
        Uri.parse('$base/api/razorpay/order'),
        headers: headers,
        body: jsonEncode({'plan': plan}),
      );
      if (orderRes.statusCode != 200) {
        return const PurchaseResult(PurchaseOutcome.failed, 'Could not start payment. Try again.');
      }
      final order = jsonDecode(orderRes.body) as Map<String, dynamic>;

      // 2. Open Razorpay Checkout and wait for the result.
      final completer = Completer<PurchaseResult>();
      final razorpay = Razorpay();

      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (dynamic response) async {
        final success = response as PaymentSuccessResponse;
        final result = await _verify(
          base: base,
          headers: headers,
          orderId: success.orderId,
          paymentId: success.paymentId,
          signature: success.signature,
        );
        if (!completer.isCompleted) completer.complete(result);
      });

      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (dynamic response) {
        final failure = response as PaymentFailureResponse;
        final outcome = failure.code == Razorpay.PAYMENT_CANCELLED
            ? PurchaseResult(PurchaseOutcome.cancelled)
            : PurchaseResult(PurchaseOutcome.failed, failure.message ?? 'Payment failed.');
        if (!completer.isCompleted) completer.complete(outcome);
      });

      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

      razorpay.open({
        'key': order['keyId'],
        'amount': order['amount'],
        'currency': order['currency'],
        'order_id': order['orderId'],
        'name': 'FinStreak',
        'description': plan == 'yearly' ? 'FinStreak Premium - Yearly' : 'FinStreak Premium - Monthly',
        'prefill': {'email': user.email ?? ''},
        'theme': {'color': '#2E7D32'},
      });

      final result = await completer.future;
      razorpay.clear();
      return result;
    } catch (_) {
      return const PurchaseResult(PurchaseOutcome.failed, 'Something went wrong. Try again.');
    }
  }

  Future<PurchaseResult> _verify({
    required String base,
    required Map<String, String> headers,
    required String? orderId,
    required String? paymentId,
    required String? signature,
  }) async {
    if (orderId == null || paymentId == null || signature == null) {
      return const PurchaseResult(PurchaseOutcome.failed, 'Payment could not be confirmed.');
    }
    final res = await http.post(
      Uri.parse('$base/api/razorpay/verify'),
      headers: headers,
      body: jsonEncode({
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      }),
    );
    if (res.statusCode == 200) {
      return const PurchaseResult(PurchaseOutcome.success);
    }
    return const PurchaseResult(
      PurchaseOutcome.failed,
      'Payment received but premium could not be activated yet. It will activate shortly.',
    );
  }
}
