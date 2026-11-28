import { createHmac, timingSafeEqual } from "node:crypto";

// Plan prices in paise (INR x 100). Keep in sync with the app's plan list.
// Prices are decided here on the server, so the app cannot change what is charged.
export const PLANS = {
  monthly: { amount: 19900, days: 30, label: "Monthly" },
  yearly: { amount: 149900, days: 365, label: "Yearly" },
} as const;

export type PlanId = keyof typeof PLANS;

export function isPlanId(value: unknown): value is PlanId {
  return value === "monthly" || value === "yearly";
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

/** Creates a Razorpay order for a plan. The key secret stays on the server. */
export async function createOrder(params: { uid: string; plan: PlanId }) {
  const keyId = requireEnv("RAZORPAY_KEY_ID");
  const keySecret = requireEnv("RAZORPAY_KEY_SECRET");
  const plan = PLANS[params.plan];

  const res = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64"),
    },
    body: JSON.stringify({
      amount: plan.amount,
      currency: "INR",
      // Receipts are limited to 40 characters.
      receipt: `${params.plan}_${Date.now()}`.slice(0, 40),
      notes: { uid: params.uid, plan: params.plan },
    }),
  });

  if (!res.ok) {
    throw new Error(`Razorpay order failed: ${res.status}`);
  }
  const order = (await res.json()) as { id: string; amount: number; currency: string };
  return { orderId: order.id, amount: order.amount, currency: order.currency, keyId };
}

function safeEqualHex(a: string, b: string): boolean {
  const ab = Buffer.from(a, "hex");
  const bb = Buffer.from(b, "hex");
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

/** Checks the signature Razorpay Checkout returns after a successful payment. */
export function verifyPaymentSignature(params: {
  orderId: string;
  paymentId: string;
  signature: string;
}): boolean {
  const secret = requireEnv("RAZORPAY_KEY_SECRET");
  const expected = createHmac("sha256", secret)
    .update(`${params.orderId}|${params.paymentId}`)
    .digest("hex");
  return safeEqualHex(expected, params.signature);
}

/** Checks the signature on a Razorpay webhook request body. */
export function verifyWebhookSignature(rawBody: string, signature: string): boolean {
  const secret = requireEnv("RAZORPAY_WEBHOOK_SECRET");
  const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
  return safeEqualHex(expected, signature);
}

/** Fetches an order from Razorpay so we trust its notes (uid, plan), not the client. */
export async function fetchOrder(orderId: string): Promise<{
  id: string;
  amount: number;
  notes: { uid?: string; plan?: string };
}> {
  const keyId = requireEnv("RAZORPAY_KEY_ID");
  const keySecret = requireEnv("RAZORPAY_KEY_SECRET");
  const res = await fetch(`https://api.razorpay.com/v1/orders/${encodeURIComponent(orderId)}`, {
    headers: {
      Authorization: "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64"),
    },
  });
  if (!res.ok) {
    throw new Error(`Razorpay order lookup failed: ${res.status}`);
  }
  return (await res.json()) as { id: string; amount: number; notes: { uid?: string; plan?: string } };
}
