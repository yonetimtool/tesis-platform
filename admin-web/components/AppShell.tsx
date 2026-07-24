"use client";

import { motion, MotionConfig } from "framer-motion";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";

import { ThemeToggle } from "@/components/ThemeToggle";
import { YonetioLogo } from "@/components/YonetioLogo";

type IconName =
  | "grid" | "building" | "clock" | "scan" | "route" | "check"
  | "box" | "home" | "edit" | "pin" | "money" | "chart"
  | "users" | "megaphone" | "chat" | "bell" | "hub" | "gear";

const LINKS: { href: string; label: string; icon: IconName }[] = [
  { href: "/dashboard", label: "Canlı Panel", icon: "grid" },
  { href: "/tenants", label: "Tesisler", icon: "building" },
  { href: "/shifts", label: "Vardiyalar", icon: "clock" },
  { href: "/checkpoints", label: "NFC Noktaları", icon: "scan" },
  { href: "/patrol-plans", label: "Devriye Planları", icon: "route" },
  { href: "/tasks", label: "Görevler", icon: "check" },
  { href: "/assets", label: "Demirbaş", icon: "box" },
  { href: "/units", label: "Daireler", icon: "home" },
  { href: "/building-editor", label: "Bina Düzenleme", icon: "edit" },
  { href: "/schematic", label: "Şikayet Haritası", icon: "pin" },
  { href: "/dues", label: "Aidat", icon: "money" },
  { href: "/reports/dues", label: "Raporlar", icon: "chart" },
  { href: "/transparency", label: "Şeffaflık", icon: "money" },
  { href: "/users", label: "Kullanıcılar", icon: "users" },
  { href: "/announcements", label: "Duyurular", icon: "megaphone" },
  { href: "/complaints", label: "Talepler", icon: "chat" },
  { href: "/notifications", label: "Bildirimler", icon: "bell" },
  { href: "/integrations", label: "Entegrasyonlar", icon: "hub" },
  { href: "/support", label: "Destek", icon: "chat" },
  { href: "/audit", label: "Denetim Kaydı", icon: "scan" },
  { href: "/settings", label: "Ayarlar", icon: "gear" },
];

function Icon({ name }: { name: IconName }) {
  const p = {
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.75,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
  const svg = (children: ReactNode) => (
    <svg viewBox="0 0 24 24" className="h-[18px] w-[18px] shrink-0" {...p}>
      {children}
    </svg>
  );
  switch (name) {
    case "grid":
      return svg(<>
        <rect x="3" y="3" width="7" height="7" rx="1.5" />
        <rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" />
        <rect x="14" y="14" width="7" height="7" rx="1.5" />
      </>);
    case "building":
      return svg(<>
        <rect x="4" y="3" width="16" height="18" rx="1.5" />
        <line x1="9" y1="7" x2="9" y2="7" /><line x1="15" y1="7" x2="15" y2="7" />
        <line x1="9" y1="11" x2="9" y2="11" /><line x1="15" y1="11" x2="15" y2="11" />
        <path d="M10 21v-3h4v3" />
      </>);
    case "clock":
      return svg(<><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></>);
    case "scan":
      return svg(<>
        <path d="M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16" />
        <circle cx="12" cy="12" r="2.5" />
      </>);
    case "route":
      return svg(<><polyline points="4 18 9 11 14 15 20 6" /><circle cx="4" cy="18" r="1.4" /><circle cx="20" cy="6" r="1.4" /></>);
    case "check":
      return svg(<><rect x="4" y="4" width="16" height="16" rx="2" /><polyline points="8.5 12 11 14.5 16 9" /></>);
    case "box":
      return svg(<><path d="M4 8l8-4 8 4v8l-8 4-8-4z" /><path d="M4 8l8 4 8-4M12 12v8" /></>);
    case "home":
      return svg(<><path d="M4 11l8-7 8 7" /><path d="M6 10v10h12V10" /></>);
    case "edit":
      return svg(<><path d="M14 5l5 5L9 20H4v-5z" /><path d="M13 6l5 5" /></>);
    case "pin":
      return svg(<><path d="M12 21s7-6.5 7-12a7 7 0 1 0-14 0c0 5.5 7 12 7 12Z" /><circle cx="12" cy="9" r="2.5" /></>);
    case "money":
      return svg(<><rect x="3" y="6" width="18" height="12" rx="2" /><circle cx="12" cy="12" r="2.5" /></>);
    case "chart":
      return svg(<><line x1="4" y1="20" x2="20" y2="20" /><rect x="6" y="12" width="3" height="6" /><rect x="11" y="8" width="3" height="10" /><rect x="16" y="5" width="3" height="13" /></>);
    case "users":
      return svg(<><circle cx="9" cy="8" r="3" /><path d="M4 20a5 5 0 0 1 10 0" /><path d="M16 6a3 3 0 0 1 0 6M17 20a5 5 0 0 0-2-4" /></>);
    case "megaphone":
      return svg(<><path d="M4 11v2a1 1 0 0 0 1 1h2l8 4V6L7 10H5a1 1 0 0 0-1 1Z" /><path d="M17 9a3 3 0 0 1 0 6" /></>);
    case "chat":
      return svg(<path d="M5 5h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H9l-4 4v-4H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z" />);
    case "bell":
      return svg(<><path d="M6 9a6 6 0 1 1 12 0c0 4 1.5 5 2 6H4c.5-1 2-2 2-6Z" /><path d="M10 20a2 2 0 0 0 4 0" /></>);
    case "hub":
      return svg(<><circle cx="12" cy="12" r="2.5" /><circle cx="5" cy="6" r="1.6" /><circle cx="19" cy="6" r="1.6" /><circle cx="12" cy="20" r="1.6" /><path d="M6.3 7l4 3.4M17.7 7l-4 3.4M12 14.5V18.4" /></>);
    case "gear":
      return svg(<><circle cx="12" cy="12" r="3" /><path d="M12 3v2.5M12 18.5V21M4.2 7l2.2 1.3M17.6 15.7l2.2 1.3M4.2 17l2.2-1.3M17.6 8.3l2.2-1.3" /></>);
  }
}

function SidebarBody({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  const router = useRouter();

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/login");
    router.refresh();
  }

  return (
    <div className="flex h-full flex-col">
      <div className="flex h-16 shrink-0 items-center border-b border-slate-200 px-5">
        <Link href="/dashboard" aria-label="Yönetio" onClick={onNavigate}>
          <YonetioLogo size={26} />
        </Link>
      </div>

      <nav className="flex-1 space-y-0.5 overflow-y-auto px-3 py-4">
        {LINKS.map((l) => {
          const active = pathname === l.href;
          return (
            <Link
              key={l.href}
              href={l.href}
              onClick={onNavigate}
              aria-current={active ? "page" : undefined}
              className={`group relative flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
                active
                  ? "bg-brand-teal/10 font-medium text-brand-teal"
                  : "text-slate-600 hover:bg-slate-100 hover:text-ink"
              }`}
            >
              {active && (
                <motion.span
                  layoutId="nav-active-bar"
                  className="absolute inset-y-1.5 left-0 w-1 rounded-r-full bg-brand-teal"
                  transition={{ type: "spring", stiffness: 500, damping: 40 }}
                />
              )}
              <span className={active ? "text-brand-teal" : "text-slate-400 group-hover:text-slate-500"}>
                <Icon name={l.icon} />
              </span>
              <span className="truncate">{l.label}</span>
            </Link>
          );
        })}
      </nav>

      <div className="shrink-0 space-y-2 border-t border-slate-200 px-3 py-4">
        <ThemeToggle />
        <button
          onClick={logout}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-left text-sm text-slate-700 transition hover:border-slate-400 hover:bg-slate-100"
        >
          Çıkış
        </button>
      </div>
    </div>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  // Rota degisince mobil cekmeceyi kapat.
  useEffect(() => setOpen(false), [pathname]);

  return (
    <MotionConfig reducedMotion="user">
      <div className="min-h-screen">
        {/* Masaustu sabit kenar cubugu */}
        <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-slate-200 bg-white lg:block">
          <SidebarBody />
        </aside>

        {/* Mobil ust cubuk */}
        <header className="sticky top-0 z-20 flex h-14 items-center justify-between border-b border-slate-200 bg-white px-4 lg:hidden">
          <button
            onClick={() => setOpen(true)}
            aria-label="Menüyü aç"
            className="rounded-lg border border-slate-300 p-2 text-slate-700 transition hover:bg-slate-100"
          >
            <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round">
              <line x1="4" y1="7" x2="20" y2="7" /><line x1="4" y1="12" x2="20" y2="12" /><line x1="4" y1="17" x2="20" y2="17" />
            </svg>
          </button>
          <YonetioLogo size={24} />
          <span className="w-9" />
        </header>

        {/* Mobil cekmece + arka plan */}
        {open && (
          <button
            aria-label="Menüyü kapat"
            onClick={() => setOpen(false)}
            className="fixed inset-0 z-40 bg-slate-900/40 backdrop-blur-sm lg:hidden"
          />
        )}
        <aside
          className={`fixed inset-y-0 left-0 z-50 w-64 border-r border-slate-200 bg-white transition-transform duration-300 lg:hidden ${
            open ? "translate-x-0" : "-translate-x-full"
          }`}
        >
          <SidebarBody onNavigate={() => setOpen(false)} />
        </aside>

        {/* Icerik */}
        <div className="lg:pl-64">
          <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
            {children}
          </main>
        </div>
      </div>
    </MotionConfig>
  );
}
