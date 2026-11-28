import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// dashboard.finstreak.app shows the sign-in and dashboard at its root.
// Rewrite the root path to the /dashboard route; the browser URL is unchanged.
export function proxy(request: NextRequest) {
  const host = request.headers.get("host") ?? "";
  const isDashboardHost = host.startsWith("dashboard.");

  if (isDashboardHost && request.nextUrl.pathname === "/") {
    const url = request.nextUrl.clone();
    url.pathname = "/dashboard";
    return NextResponse.rewrite(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/", "/((?!_next|favicon.ico|.*\\..*).*)"],
};
