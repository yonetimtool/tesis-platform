"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

const TABS: { href: string; anahtar: SozlukAnahtari }[] = [
  { href: "/reports/dues", anahtar: "raporAidatTahsilat" },
  { href: "/reports/patrols", anahtar: "raporTurGecmisi" },
  { href: "/reports/tasks", anahtar: "raporGorevGecmisi" },
];

export function ReportsTabs() {
  const pathname = usePathname();
  const ceviri = useT();
  return (
    <div className="flex gap-1 border-b border-slate-200">
      {TABS.map((t) => {
        const active = pathname === t.href;
        return (
          <Link
            key={t.href}
            href={t.href}
            className={`-mb-px border-b-2 px-3 py-2 text-sm transition ${
              active
                ? "border-brand-teal font-medium text-brand-teal"
                : "border-transparent text-slate-600 hover:text-ink"
            }`}
          >
            {ceviri(t.anahtar)}
          </Link>
        );
      })}
    </div>
  );
}
