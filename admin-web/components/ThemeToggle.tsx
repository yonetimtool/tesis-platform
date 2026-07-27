"use client";

import { useEffect, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

// Tema modu: sistem (OS'i izle), acik veya koyu. Secim localStorage'da kalici.
// Ilk boyama oncesi `.dark` sinifi layout'taki satir-ici script ile atanir
// (FOUC yok); bu bilesen calisma-zamani degisimini ve senkronu yonetir.
type Mode = "system" | "light" | "dark";

const ORDER: Mode[] = ["system", "light", "dark"];
// Etiket METIN degil ANAHTAR (tur 17) — cizim aninda aktif dilde cozulur.
const LABEL: Record<Mode, SozlukAnahtari> = {
  system: "temaSistem",
  light: "temaAcik",
  dark: "temaKoyu",
};
const ICON: Record<Mode, string> = { system: "🖥️", light: "☀️", dark: "🌙" };

function systemPrefersDark(): boolean {
  return window.matchMedia("(prefers-color-scheme: dark)").matches;
}

function applyMode(mode: Mode) {
  const dark = mode === "dark" || (mode === "system" && systemPrefersDark());
  document.documentElement.classList.toggle("dark", dark);
}

export function ThemeToggle() {
  const t = useT();
  const [mode, setMode] = useState<Mode>("system");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("theme") as Mode | null;
    if (stored === "light" || stored === "dark" || stored === "system") {
      setMode(stored);
    }
    setMounted(true);
  }, []);

  // Sistem modundayken OS tema degisimini canli izle.
  useEffect(() => {
    if (mode !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => applyMode("system");
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [mode]);

  function cycle() {
    const next = ORDER[(ORDER.indexOf(mode) + 1) % ORDER.length];
    setMode(next);
    localStorage.setItem("theme", next);
    applyMode(next);
  }

  // Hydration uyumu: sunucu modu bilmez; ilk render'da notr etiket goster.
  const label = mounted ? t(LABEL[mode]) : t("temaSecici");
  const icon = mounted ? ICON[mode] : "🎨";

  return (
    <button
      onClick={cycle}
      title={`${t("temaSecici")}: ${label}`}
      aria-label={`${t("temaSecici")}: ${label}`}
      className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm text-slate-700 transition hover:bg-slate-100"
    >
      <span aria-hidden>{icon}</span> {label}
    </button>
  );
}
