import Image from "next/image";
import Link from "next/link";

export const DASHBOARD_URL = "https://dashboard.finstreak.app";

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-10 border-b border-[#E5E7EB] bg-[#F9F9F7]/90 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <Link href="/" aria-label="FinStreak home">
          <Image src="/logo-lockup.png" alt="FinStreak" width={150} height={39} priority />
        </Link>
        <nav className="flex items-center gap-6 text-sm font-medium text-[#141613]">
          <a href="#features" className="hidden hover:text-[#3C8B47] sm:inline">Features</a>
          <a href="#how" className="hidden hover:text-[#3C8B47] sm:inline">How it works</a>
          <a
            href={DASHBOARD_URL}
            className="rounded-full bg-[#214D2A] px-4 py-2 text-white transition-colors hover:bg-[#3C8B47]"
          >
            Sign in
          </a>
        </nav>
      </div>
    </header>
  );
}

export function SiteFooter() {
  const supportEmail = process.env.NEXT_PUBLIC_SUPPORT_EMAIL;
  return (
    <footer className="border-t border-[#E5E7EB] bg-white">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-8 text-sm text-[#6B7280] sm:flex-row sm:items-center sm:justify-between">
        <p>© FinStreak. All rights reserved.</p>
        <nav className="flex flex-wrap gap-x-6 gap-y-2">
          <Link href="/privacy" className="hover:text-[#141613]">Privacy</Link>
          <Link href="/terms" className="hover:text-[#141613]">Terms</Link>
          <Link href="/account-deletion" className="hover:text-[#141613]">Delete account</Link>
          {supportEmail ? (
            <a href={`mailto:${supportEmail}`} className="hover:text-[#141613]">Support</a>
          ) : null}
        </nav>
      </div>
    </footer>
  );
}
