import Image from "next/image";
import { DASHBOARD_URL, SiteFooter, SiteHeader } from "@/components/site-chrome";

const features = [
  {
    title: "Every account in one place",
    body: "Bank accounts, wallets and cards together, so you always know where your money sits.",
  },
  {
    title: "Transactions added for you",
    body: "Import from bank SMS, email alerts or a PDF statement, then review and categorise in seconds.",
  },
  {
    title: "Budgets that keep you honest",
    body: "Set a monthly limit per category and see how much is left before the month runs out.",
  },
  {
    title: "Goals and savings",
    body: "Plan for what matters, track progress, and build a streak you can see.",
  },
  {
    title: "Loans, reconciled monthly",
    body: "Track EMIs and outstanding balances, and reconcile each month against your lender's statement.",
  },
  {
    title: "Your FinScore",
    body: "One number that reflects your money habits, with the reasons behind it.",
  },
  {
    title: "Split trips with friends",
    body: "Share a trip budget, log who paid what, and settle up without the awkward chasing.",
  },
  {
    title: "AI insights",
    body: "Ask questions about your spending in plain language and get answers from your own data.",
  },
];

const steps = [
  { n: "1", title: "Sign in with Google", body: "Use the same account on the web and on your phone." },
  { n: "2", title: "Add or import", body: "Connect your accounts, or import transactions from messages and statements." },
  { n: "3", title: "See where you stand", body: "Your dashboard shows balances, budgets, loans, goals and your score." },
];

export default function Home() {
  return (
    <>
      <SiteHeader />

      <main className="flex-1">
        {/* Hero */}
        <section className="mx-auto flex max-w-6xl flex-col-reverse items-center gap-12 px-6 py-20 md:flex-row md:py-28">
          <div className="flex-1">
            <p className="mb-4 text-sm font-semibold uppercase tracking-widest text-[#3C8B47]">
              Personal finance
            </p>
            <h1 className="text-4xl font-bold leading-tight tracking-tight text-[#141613] md:text-5xl">
              Your money.
              <br />
              Your clarity.
              <br />
              <span className="text-[#3C8B47]">Your future.</span>
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-8 text-[#6B7280]">
              FinStreak brings your accounts, spending, budgets, loans and goals into one place, and
              shows you where you stand every month.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <a
                href={DASHBOARD_URL}
                className="inline-flex h-12 items-center justify-center rounded-full bg-[#214D2A] px-6 font-semibold text-white transition-colors hover:bg-[#3C8B47]"
              >
                Open dashboard
              </a>
              <a
                href="#features"
                className="inline-flex h-12 items-center justify-center rounded-full border border-[#D1D5DB] px-6 font-semibold text-[#141613] transition-colors hover:bg-white"
              >
                See what it does
              </a>
            </div>
          </div>
          <div className="flex-1 flex justify-center">
            <Image
              src="/app-icon.png"
              alt="FinStreak app icon"
              width={280}
              height={280}
              className="rounded-[56px] shadow-xl"
              priority
            />
          </div>
        </section>

        {/* Features */}
        <section id="features" className="bg-white py-20">
          <div className="mx-auto max-w-6xl px-6">
            <h2 className="text-3xl font-bold tracking-tight text-[#141613]">Everything in one place</h2>
            <p className="mt-3 max-w-2xl text-[#6B7280]">
              Built for people who want to understand their money without a spreadsheet.
            </p>
            <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
              {features.map((f) => (
                <div key={f.title} className="rounded-2xl border border-[#E5E7EB] bg-[#F9F9F7] p-6">
                  <h3 className="font-semibold text-[#141613]">{f.title}</h3>
                  <p className="mt-2 text-sm leading-6 text-[#6B7280]">{f.body}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* How it works */}
        <section id="how" className="py-20">
          <div className="mx-auto max-w-6xl px-6">
            <h2 className="text-3xl font-bold tracking-tight text-[#141613]">How it works</h2>
            <div className="mt-12 grid gap-8 md:grid-cols-3">
              {steps.map((s) => (
                <div key={s.n}>
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[#3C8B47] font-bold text-white">
                    {s.n}
                  </div>
                  <h3 className="mt-4 font-semibold text-[#141613]">{s.title}</h3>
                  <p className="mt-2 text-sm leading-6 text-[#6B7280]">{s.body}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Final call to action */}
        <section className="px-6 pb-24">
          <div className="mx-auto max-w-6xl rounded-3xl bg-[#214D2A] px-8 py-14 text-center text-white">
            <h2 className="text-3xl font-bold tracking-tight">Start seeing your money clearly</h2>
            <p className="mx-auto mt-3 max-w-xl text-white/80">
              Sign in to your dashboard with the Google account you use in the app.
            </p>
            <a
              href={DASHBOARD_URL}
              className="mt-8 inline-flex h-12 items-center justify-center rounded-full bg-white px-6 font-semibold text-[#214D2A] transition-colors hover:bg-[#F9F9F7]"
            >
              Sign in to dashboard
            </a>
          </div>
        </section>
      </main>

      <SiteFooter />
    </>
  );
}
