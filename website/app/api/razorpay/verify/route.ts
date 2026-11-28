import { uidFromRequest } from "@/lib/server/auth";
import { grantPremium } from "@/lib/server/entitlements";
import { fetchOrder, isPlanId, verifyPaymentSignature } from "@/lib/server/razorpay";

// POST /api/razorpay/verify  { orderId, paymentId, signature }
// Called by the app after Razorpay Checkout reports success.
export async function POST(request: Request) {
  const uid = await uidFromRequest(request);
  if (!uid) {
    return Response.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as {
    orderId?: unknown;
    paymentId?: unknown;
    signature?: unknown;
  } | null;
  if (
    !body ||
    typeof body.orderId !== "string" ||
    typeof body.paymentId !== "string" ||
    typeof body.signature !== "string"
  ) {
    return Response.json({ error: "Missing payment details" }, { status: 400 });
  }

  // 1. The signature proves Razorpay signed this order and payment.
  if (!verifyPaymentSignature({ orderId: body.orderId, paymentId: body.paymentId, signature: body.signature })) {
    return Response.json({ error: "Payment could not be verified" }, { status: 400 });
  }

  // 2. The order must belong to this user, and carry a valid plan.
  try {
    const order = await fetchOrder(body.orderId);
    if (order.notes.uid !== uid || !isPlanId(order.notes.plan)) {
      return Response.json({ error: "Payment does not match this account" }, { status: 403 });
    }
    const result = await grantPremium({
      uid,
      plan: order.notes.plan,
      paymentId: body.paymentId,
      orderId: body.orderId,
    });
    return Response.json({ premium: true, expiresAt: result.expiresAt?.toISOString() ?? null });
  } catch (e) {
    console.error("verify failed", e);
    return Response.json({ error: "Could not activate premium" }, { status: 502 });
  }
}
