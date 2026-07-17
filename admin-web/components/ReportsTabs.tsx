"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/reports/dues", label: "Aidat Tahsilat" },
  { href: "/reports/patrols", label: "Tur Geçmişi" },
  { href: "/reports/tasks", label: "Görev Geçmişi" },
];

export function ReportsTabs() {
  const pathname = usePathname();
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
            {t.label}
          </Link>
        );
      })}
    </div>
  );
}
