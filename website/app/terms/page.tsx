import type { Metadata } from "next";
import { LegalLayout } from "@/components/legal-layout";

export const metadata: Metadata = { title: "Terms of Service" };

export default function TermsPage() {
  return (
    <LegalLayout title="Terms of Service" updated="[date]">
      <h2>Using FinStreak</h2>
      <p>
        FinStreak is a personal finance tool. By signing in, you agree to these terms. If you do
        not agree, please do not use FinStreak.
      </p>

      <h2>Your account</h2>
      <p>
        You sign in with a Google account and are responsible for activity under it. Keep your
        account secure.
      </p>

      <h2>Not financial advice</h2>
      <p>
        FinStreak shows information and estimates to help you plan. It does not provide financial,
        investment, tax or legal advice. Check important decisions with a qualified professional.
      </p>

      <h2>Your content</h2>
      <p>
        You keep ownership of the data you add or import. You give us permission to process it only
        to provide FinStreak to you.
      </p>

      <h2>Acceptable use</h2>
      <ul>
        <li>Do not try to access other people&apos;s data or interfere with the service.</li>
        <li>Do not use FinStreak for anything unlawful.</li>
      </ul>

      <h2>Availability</h2>
      <p>
        We work to keep FinStreak available, but it may be interrupted or change. [Add any uptime or
        support commitments.]
      </p>

      <h2>Limitation of liability</h2>
      <p>
        [Insert the liability limitation and governing law that apply to your business.]
      </p>

      <h2>Changes</h2>
      <p>We may update these terms. We will show the new date at the top of this page.</p>

      <h2>Contact</h2>
      <p>
        <a className="underline" href="mailto:[support email]">[support email]</a>
      </p>
    </LegalLayout>
  );
}
