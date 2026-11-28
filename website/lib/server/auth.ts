import { adminAuth } from "@/lib/server/firebase-admin";

/** Returns the signed-in user's uid from a Firebase ID token, or null. */
export async function uidFromRequest(request: Request): Promise<string | null> {
  const header = request.headers.get("authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) return null;
  try {
    const decoded = await adminAuth().verifyIdToken(token);
    return decoded.uid;
  } catch {
    return null;
  }
}
