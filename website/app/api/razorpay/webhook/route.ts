import { grantPremium } from "@/lib/server/entitlements";
import { fetchOrder, isPlanId, verifyWebhookSignature } from "@/lib/server/razorpay";

// POST /api/razorpay/webhook
// Razorpay calls this when a payment is captured. It is the backup for the
// app's verify call, so premium is granted even if the app closes mid-payment.
export async function POST(request: Request) {
  const rawBody = await request.text();
  const signature = request.headers.get("x-razorpay-signature") ?? "";

  if (!signature || !verifyWebhookSignature(rawBody, signature)) {
    return Response.json({ error: "Bad signature" }, { status: 400 });
  }

  const event = JSON.parse(rawBody) as {
    event?: string;
    payload?: { payment?: { entity?: { id?: string; order_id?: string } } };
  };
  if (event.event !== "payment.captured") {
    return Response.json({ ignored: true });
  }

  const payment = event.payload?.payment?.entity;
  if (!payment?.id || !payment.order_id) {
    return Response.json({ error: "Missing payment" }, { status: 400 });
  }

  try {
    const order = await fetchOrder(payment.order_id);
    const uid = order.notes.uid;
    if (!uid || !isPlanId(order.notes.plan)) {
      return Response.json({ ignored: true });
    }
    await grantPremium({ uid, plan: order.notes.plan, paymentId: payment.id, orderId: payment.order_id });
    return Response.json({ ok: true });
  } catch (e) {
    console.error("webhook failed", e);
    // Non-2xx makes Razorpay retry the webhook later.
    return Response.json({ error: "Retry later" }, { status: 500 });
  }
}
