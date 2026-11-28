import type { Metadata } from "next";
import { LegalLayout } from "@/components/legal-layout";

export const metadata: Metadata = { title: "Delete your account" };

export default function AccountDeletionPage() {
  return (
    <LegalLayout title="Delete your account" updated="[date]">
      <p>
        You can delete your FinStreak account and the data stored with it. Deleting your account
        cannot be undone.
      </p>

      <h2>Delete from the app</h2>
      <ul>
        <li>Open FinStreak and go to [in-app path to delete account].</li>
        <li>Confirm deletion. Your account and its data are removed.</li>
      </ul>

      <h2>Request deletion by email</h2>
      <p>
        If you can&apos;t access the app, email{" "}
        <a className="underline" href="mailto:[support email]">[support email]</a> from the email
        address on your account. We will delete your account within [number] days and confirm when
        it is done.
      </p>

      <h2>What gets deleted</h2>
      <p>
        Your profile, accounts, transactions, budgets, goals, loans and other data stored in your
        account. [List anything kept after deletion, such as records we must retain by law, and for
        how long.]
      </p>
    </LegalLayout>
  );
}
