import type { Metadata } from "next";
import { LegalLayout } from "@/components/legal-layout";

export const metadata: Metadata = { title: "Privacy Policy" };

export default function PrivacyPage() {
  return (
    <LegalLayout title="Privacy Policy" updated="[date]">
      <p>
        This policy explains what FinStreak collects, how we use it, and the choices you have. It
        applies to the FinStreak website, the dashboard at dashboard.finstreak.app, and the
        FinStreak mobile app.
      </p>

      <h2>What we collect</h2>
      <ul>
        <li>
          <strong>Account details:</strong> your name, email address and profile photo from the
          Google account you sign in with.
        </li>
        <li>
          <strong>Financial information you add or import:</strong> accounts, transactions,
          budgets, goals, loans and related categories.
        </li>
        <li>
          <strong>Messages and statements you choose to import:</strong> bank SMS, email alerts and
          PDF statements, processed to extract transactions. We only read what you import.
        </li>
        <li>
          <strong>Technical data:</strong> basic device and usage information needed to run and
          secure the service.
        </li>
      </ul>

      <h2>How we use it</h2>
      <p>
        We use this information to run FinStreak: to show your dashboard, calculate budgets and
        scores, reconcile loans, and provide AI insights when you ask for them. We do not sell your
        personal information.
      </p>

      <h2>Where it is stored and who processes it</h2>
      <p>
        Your data is stored with Google Firebase. Each account&apos;s data is kept under that
        account and can only be read by that signed-in user. When you use AI features, the relevant
        data is sent to Google&apos;s Gemini service to generate a response. [Confirm the exact
        data sent and any retention terms with the provider.]
      </p>

      <h2>Keeping and deleting your data</h2>
      <p>
        You can delete your account and its data at any time. See the{" "}
        <a className="underline" href="/account-deletion">account deletion page</a>. [State how long
        backups and logs are kept.]
      </p>

      <h2>Your choices and rights</h2>
      <p>
        You can edit or delete your data in the app, stop importing messages or statements at any
        time, and ask us for a copy of your data. [Add the rights that apply in your region.]
      </p>

      <h2>Children</h2>
      <p>FinStreak is not intended for anyone under 18.</p>

      <h2>Contact us</h2>
      <p>
        Questions about this policy? Email{" "}
        <a className="underline" href="mailto:[privacy email]">[privacy email]</a>.
      </p>
    </LegalLayout>
  );
}
