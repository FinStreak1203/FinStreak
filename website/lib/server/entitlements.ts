import { Timestamp } from "firebase-admin/firestore";
import { adminDb } from "@/lib/server/firebase-admin";
import { PLANS, type PlanId } from "@/lib/server/razorpay";

/**
 * Grants or extends premium for a successful payment.
 *
 * - Idempotent: the same payment id is only processed once (checkout return
 *   and webhook can both report it).
 * - Extends from the current expiry if the user is still premium.
 * - Writes to users/{uid}/billing/entitlement, which the app can read but
 *   Firestore rules block it from writing.
 */
export async function grantPremium(params: {
  uid: string;
  plan: PlanId;
  paymentId: string;
  orderId: string;
}): Promise<{ alreadyProcessed: boolean; expiresAt: Date | null }> {
  const db = adminDb();
  const paymentRef = db.doc(`payments/${params.paymentId}`);
  const entitlementRef = db.doc(`users/${params.uid}/billing/entitlement`);

  return db.runTransaction(async (tx) => {
    const paid = await tx.get(paymentRef);
    if (paid.exists) {
      const existing = paid.data()?.expiresAt as Timestamp | undefined;
      return { alreadyProcessed: true, expiresAt: existing ? existing.toDate() : null };
    }

    const current = await tx.get(entitlementRef);
    const currentExpiry = current.data()?.expiresAt as Timestamp | undefined;
    const now = Date.now();
    const base = Math.max(now, currentExpiry ? currentExpiry.toMillis() : 0);
    const expiresAt = new Date(base + PLANS[params.plan].days * 24 * 60 * 60 * 1000);

    tx.set(paymentRef, {
      uid: params.uid,
      plan: params.plan,
      orderId: params.orderId,
      expiresAt: Timestamp.fromDate(expiresAt),
      createdAt: Timestamp.fromDate(new Date(now)),
    });
    tx.set(
      entitlementRef,
      {
        tier: "premium",
        plan: params.plan,
        expiresAt: Timestamp.fromDate(expiresAt),
        lastPaymentId: params.paymentId,
        updatedAt: Timestamp.fromDate(new Date(now)),
      },
      { merge: true },
    );

    return { alreadyProcessed: false, expiresAt };
  });
}
