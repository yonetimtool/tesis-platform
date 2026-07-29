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
    // DAR EKRAN + UZUN CEVIRI: Almanca sekme adlari 360 dp'ye sigmiyor ve
    // SAYFAYI yana kaydiriyordu (tur 25 surusu +84 px olctu). Sekmeler
    // sarmamali (alt cizgi bozulur) — bu yuzden serit KENDI ICINDE
    // kaydirilir; sayfa govdesi sabit kalir.
    <div className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0" tabIndex={0}>
      <div className="flex min-w-max gap-1 border-b border-slate-200">
      {TABS.map((t) => {
        const active = pathname === t.href;
        return (
          <Link
            key={t.href}
            href={t.href}
            className={`-mb-px border-b-2 px-3 py-2 text-sm transition ${
              active
                ? "border-brand-teal font-medium text-brand-tealInk"
                : "border-transparent text-slate-600 hover:text-ink"
            }`}
          >
            {ceviri(t.anahtar)}
          </Link>
        );
      })}
      </div>
    </div>
  );
}
