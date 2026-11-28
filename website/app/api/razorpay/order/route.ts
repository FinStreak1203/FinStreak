import { uidFromRequest } from "@/lib/server/auth";
import { createOrder, isPlanId } from "@/lib/server/razorpay";

// POST /api/razorpay/order  { plan: "monthly" | "yearly" }
// Requires a Firebase ID token. Returns a Razorpay order for the app to pay.
export async function POST(request: Request) {
  const uid = await uidFromRequest(request);
  if (!uid) {
    return Response.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as { plan?: unknown } | null;
  if (!body || !isPlanId(body.plan)) {
    return Response.json({ error: "Unknown plan" }, { status: 400 });
  }

  try {
    const order = await createOrder({ uid, plan: body.plan });
    return Response.json(order);
  } catch (e) {
    console.error("order failed", e);
    return Response.json({ error: "Could not start payment" }, { status: 502 });
  }
}
