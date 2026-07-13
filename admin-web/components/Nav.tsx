"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

const LINKS = [
  { href: "/dashboard", label: "Canlı Panel" },
  { href: "/shifts", label: "Vardiyalar" },
  { href: "/checkpoints", label: "NFC Noktaları" },
  { href: "/patrol-plans", label: "Devriye Planları" },
  { href: "/tasks", label: "Görevler" },
  { href: "/assets", label: "Demirbaş" },
  { href: "/units", label: "Daireler" },
  { href: "/schematic", label: "Şikayet Haritası" },
  { href: "/dues", label: "Aidat" },
  { href: "/reports/dues", label: "Raporlar" },
  { href: "/users", label: "Kullanıcılar" },
  { href: "/emergency", label: "Acil Durum" },
  { href: "/announcements", label: "Duyurular" },
  { href: "/complaints", label: "Talepler" },
  { href: "/notifications", label: "Bildirimler" },
  { href: "/integrations", label: "Entegrasyonlar" },
  { href: "/settings", label: "Ayarlar" },
];

export function Nav() {
  const pathname = usePathname();
  const router = useRouter();

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/login");
    router.refresh();
  }

  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <div className="flex items-center gap-6">
          <span className="font-semibold">Tesis Paneli</span>
          <nav className="flex gap-1">
            {LINKS.map((l) => {
              const active = pathname === l.href;
              return (
                <Link
                  key={l.href}
                  href={l.href}
                  className={`rounded-lg px-3 py-1.5 text-sm transition ${
                    active
                      ? "bg-ink text-white"
                      : "text-slate-600 hover:bg-slate-100"
                  }`}
                >
                  {l.label}
                </Link>
              );
            })}
          </nav>
        </div>
        <button
          onClick={logout}
          className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-100"
        >
          Çıkış
        </button>
      </div>
    </header>
  );
}
