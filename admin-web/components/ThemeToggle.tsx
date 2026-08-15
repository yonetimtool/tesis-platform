"use client";

import { useEffect, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { kayitliMod, moduKaydet, temayiUygula, type TemaModu } from "@/lib/tema";

// Tema modu: sistem (OS'i izle), acik veya koyu. Secim localStorage'da kalici.
// Ilk boyama oncesi `.dark` sinifi layout'taki satir-ici script ile atanir
// (FOUC yok); bu bilesen calisma-zamani degisimini ve senkronu yonetir.
//
// (P161) UYGULAMA MANTIGI `lib/tema.ts`e TASINDI: modun hangi sinifi
// verdigi ve 200 ms'lik renk gecisi artik tek kaynakta. Bu bilesen
// yalnizca DUGME.
type Mode = TemaModu;

const ORDER: Mode[] = ["system", "light", "dark"];
// Etiket METIN degil ANAHTAR (tur 17) — cizim aninda aktif dilde cozulur.
const LABEL: Record<Mode, SozlukAnahtari> = {
  system: "temaSistem",
  light: "temaAcik",
  dark: "temaKoyu",
};
const ICON: Record<Mode, string> = { system: "🖥️", light: "☀️", dark: "🌙" };

export function ThemeToggle() {
  const t = useT();
  const [mode, setMode] = useState<Mode>("system");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // Korumali okuma `lib/tema.ts`te; erisilemez depolamada `system`.
    const stored = kayitliMod();
    if (stored) setMode(stored);
    setMounted(true);
  }, []);

  // Sistem modundayken OS tema degisimini canli izle.
  useEffect(() => {
    if (mode !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    // Isletim sistemi temasi degisince de YUMUSAK gecilir: ani bir renk
    // sicramasi, kullanicinin kendi yapmadigi bir degisimde daha rahatsiz.
    const onChange = () => temayiUygula("system", true);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [mode]);

  function cycle() {
    const next = ORDER[(ORDER.indexOf(mode) + 1) % ORDER.length];
    setMode(next);
    moduKaydet(next);
    temayiUygula(next, true);
  }

  // Hydration uyumu: sunucu modu bilmez; ilk render'da notr etiket goster.
  const label = mounted ? t(LABEL[mode]) : t("temaSecici");
  const icon = mounted ? ICON[mode] : "🎨";

  return (
    <button
      onClick={cycle}
      title={`${t("temaSecici")}: ${label}`}
      aria-label={`${t("temaSecici")}: ${label}`}
      // (P161) TOKEN'A GECTI. Tema anahtarinin KENDISI temasizdi:
      // `border-slate-300` ve `hover:bg-slate-100` sabit acik-tema
      // renkleriydi; koyu temada dugme cevresinden kopuk duruyordu.
      className="yz-tema-dugme rounded-lg px-3 py-1.5 text-sm"
      style={{
        borderWidth: "var(--yz-border-w)",
        borderStyle: "solid",
        borderColor: "var(--yz-border)",
        background: "var(--yz-surface-1)",
        color: "var(--yz-text-2)",
      }}
    >
      <span aria-hidden>{icon}</span> {label}
    </button>
  );
}
