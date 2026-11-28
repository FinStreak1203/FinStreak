import type { ReactNode } from "react";
import { SiteFooter, SiteHeader } from "@/components/site-chrome";

export function LegalLayout({ title, updated, children }: { title: string; updated: string; children: ReactNode }) {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto w-full max-w-3xl flex-1 px-6 py-16">
        <div className="mb-8 rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900">
          <strong>Draft.</strong> This page needs review by a qualified lawyer before it is published.
        </div>
        <h1 className="text-4xl font-bold tracking-tight text-[#141613]">{title}</h1>
        <p className="mt-2 text-sm text-[#6B7280]">Last updated: {updated}</p>
        <div className="mt-10 space-y-6 leading-7 text-[#141613] [&_h2]:mt-10 [&_h2]:text-xl [&_h2]:font-semibold [&_ul]:list-disc [&_ul]:space-y-2 [&_ul]:pl-6">
          {children}
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
