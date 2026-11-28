import { uidFromRequest } from "@/lib/server/auth";
import { adminDb } from "@/lib/server/firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

// Tried in order. Free-tier flash models are often overloaded (503) or out of
// quota (429), so a failure on one falls through to the next.
const MODELS = [
  "gemini-2.5-flash",
  "gemini-flash-latest",
  "gemini-2.5-flash-lite",
  "gemini-flash-lite-latest",
];

const MAX_PROMPT_CHARS = 12000;
const DAILY_LIMIT = Number(process.env.AI_DAILY_LIMIT ?? 300);

// POST /api/ai/generate  { prompt: string } -> { text: string }
// Requires a Firebase ID token. The Gemini key lives only in server env
// (GEMINI_API_KEY), so it is never shipped inside the mobile app.
export async function POST(request: Request) {
  const uid = await uidFromRequest(request);
  if (!uid) {
    return Response.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as { prompt?: unknown } | null;
  const prompt = typeof body?.prompt === "string" ? body.prompt : "";
  if (!prompt.trim() || prompt.length > MAX_PROMPT_CHARS) {
    return Response.json({ error: "Invalid prompt" }, { status: 400 });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return Response.json({ error: "AI not configured" }, { status: 503 });
  }

  if (!(await reserveQuota(uid))) {
    return Response.json({ error: "Daily AI limit reached" }, { status: 429 });
  }

  for (const model of MODELS) {
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
        },
      );
      if (!res.ok) {
        console.warn(`gemini ${model} responded ${res.status}, trying next`);
        continue;
      }
      const data = (await res.json()) as {
        candidates?: { content?: { parts?: { text?: string }[] } }[];
      };
      const text = data.candidates?.[0]?.content?.parts
        ?.map((p) => p.text ?? "")
        .join("")
        .trim();
      if (text) {
        return Response.json({ text });
      }
    } catch (e) {
      console.warn(`gemini ${model} failed, trying next`, e);
    }
  }

  return Response.json({ error: "AI unavailable" }, { status: 502 });
}

/**
 * Counts one request against the user's daily allowance. The counter lives in
 * `aiUsage`, which the Firestore rules do not open to clients, so users can't
 * reset their own count.
 */
async function reserveQuota(uid: string): Promise<boolean> {
  const day = new Date().toISOString().slice(0, 10);
  const db = adminDb();
  const ref = db.doc(`aiUsage/${uid}_${day}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count as number | undefined) ?? 0;
    if (count >= DAILY_LIMIT) return false;
    tx.set(
      ref,
      { uid, day, count: count + 1, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return true;
  });
}
