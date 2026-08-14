"use client";

/**
 * (P160 / Asama 2) KOMUT PALETI — Ctrl+K / Cmd+K.
 *
 * =========================================================================
 * ARAMA MANTIGI YENIDEN YAZILMADI
 * =========================================================================
 * Sorgu, gecikme, sonuc bicimi ve KAYNAK->ROTA eslemesi
 * `components/GlobalArama.tsx`te duruyor ve P154'ten beri calisiyor.
 * Burada yalniz SUNUM ve KLAVYE var.
 *
 * Ozellikle YETKI: brief "sonuclarda yetki sizintisi olmayacak" diyor ve
 * bu kural SUNUCUDA (`/api/panel/arama`) uygulaniyor — istemci yalnizca
 * ucun donduklerini cizer. Paletin kendi suzgeci YOKTUR; olsaydi ikinci
 * bir yetki karari uretmis ve ikisi ayrisabilir olurdu.
 *
 * =========================================================================
 * NEDEN AYRI BILESEN, NEDEN `GlobalArama`YA GOMULMEDI
 * =========================================================================
 * `GlobalArama` ust barda SATIR ICI bir kutudur ve oyle kalmali (fareyle
 * gelen kullanici onu goruyor). Palet ise TAM EKRAN bir katman; ikisini
 * tek bilesende toplamak, "acikken satir ici mi tam ekran mi" diye
 * dallanan bir cizim uretirdi. Ikisi ayni ucu cagirir, sunumlari ayrilir.
 *
 * =========================================================================
 * KLAVYE — paletin varlik sebebi
 * =========================================================================
 * * Ctrl+K / Cmd+K acar (form alanindayken de acilir: kullanici bir
 *   metin kutusundayken de aramak isteyebilir).
 * * ↑/↓ gezinir, Enter secer, ESC kapatir.
 * * Odak acilista girdiye, kapanista ACAN OGEYE doner.
 * * Secili satir `aria-activedescendant` ile bildirilir — odak girdide
 *   KALIR (yoksa her okta odak ziplar ve yazmaya devam edilemez).
 */
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useId, useRef, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

import { Girinti } from "./yuzey";

export interface PaletVurusu {
  kaynak: string;
  id: string;
  baslik: string;
  ayrinti?: string | null;
}

/** Kaynak -> (etiket anahtari, rota). `GlobalArama` ile AYNI tablo. */
export const PALET_HEDEF: Record<string, { etiket: SozlukAnahtari; rota: string }> = {
  kisi: { etiket: "kabukKullanicilar", rota: "/users" },
  daire: { etiket: "kabukDaireler", rota: "/units" },
  blok: { etiket: "kabukBinaDuzenleme", rota: "/building-editor" },
  firma: { etiket: "kabukTanimlar", rota: "/tanimlar" },
  gorev: { etiket: "kabukGorevler", rota: "/tasks" },
  duyuru: { etiket: "kabukDuyurular", rota: "/announcements" },
  talep: { etiket: "kabukTalepler", rota: "/complaints" },
  finans: { etiket: "kabukFinans", rota: "/finans" },
};

const UC = "/api/panel/arama";
const YEDEK_ETIKET: SozlukAnahtari = "aramaEtiket";
const GECIKME_MS = 300;
const KOK_ROTA = "/";

export function KomutPaleti() {
  const t = useT();
  const router = useRouter();
  const [acik, setAcik] = useState(false);
  const [q, setQ] = useState("");
  const [vuruslar, setVuruslar] = useState<PaletVurusu[]>([]);
  const [secili, setSecili] = useState(0);
  const [yukleniyor, setYukleniyor] = useState(false);
  const girdiRef = useRef<HTMLInputElement | null>(null);
  const acanRef = useRef<HTMLElement | null>(null);
  const listeId = useId();

  const kapat = useCallback(() => {
    setAcik(false);
    setQ("");
    setVuruslar([]);
    setSecili(0);
    acanRef.current?.focus?.();
  }, []);

  // --- Ctrl+K / Cmd+K ---
  useEffect(() => {
    function tus(e: KeyboardEvent) {
      // `metaKey` macOS icin: orada Ctrl+K terminal kisayoludur ve
      // kullanicilar Cmd bekler.
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        acanRef.current = document.activeElement as HTMLElement | null;
        setAcik(true);
      }
    }
    document.addEventListener("keydown", tus);
    return () => document.removeEventListener("keydown", tus);
  }, []);

  // Acilista odak girdiye.
  useEffect(() => {
    if (acik) girdiRef.current?.focus();
  }, [acik]);

  // --- SORGU ---
  useEffect(() => {
    if (!acik) return;
    // EN AZ IKI KARAKTER — sunucunun kurali (422). Istemcide de
    // uygulamak, kullaniciya sebepsiz hata gostermemek icin.
    if (q.trim().length < 2) {
      setVuruslar([]);
      return;
    }
    let iptal = false;
    setYukleniyor(true);
    const zaman = setTimeout(async () => {
      try {
        const r = await fetch(`${UC}?q=${encodeURIComponent(q.trim())}`);
        if (!r.ok) throw new Error(String(r.status));
        const govde = (await r.json()) as { items: PaletVurusu[] };
        if (iptal) return;
        setVuruslar(govde.items);
        setSecili(0);
      } catch {
        // SESSIZ: arama ikincil bir yuzeydir (GlobalArama ile ayni karar).
        if (!iptal) setVuruslar([]);
      } finally {
        if (!iptal) setYukleniyor(false);
      }
    }, GECIKME_MS);
    return () => {
      iptal = true;
      clearTimeout(zaman);
    };
  }, [q, acik]);

  function git(v: PaletVurusu) {
    kapat();
    router.push(PALET_HEDEF[v.kaynak]?.rota ?? KOK_ROTA);
  }

  function girdiTus(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Escape") {
      e.preventDefault();
      kapat();
      return;
    }
    if (vuruslar.length === 0) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setSecili((s) => (s + 1) % vuruslar.length);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSecili((s) => (s - 1 + vuruslar.length) % vuruslar.length);
    } else if (e.key === "Enter") {
      e.preventDefault();
      const v = vuruslar[secili];
      if (v) git(v);
    }
  }

  if (!acik) return null;

  return (
    <div
      className="fixed inset-0 flex items-start justify-center p-4 pt-[12vh]"
      style={{ zIndex: "var(--yz-z-modal)" as unknown as number }}
    >
      <div
        aria-hidden="true"
        onClick={kapat}
        className="absolute inset-0"
        style={{ background: "rgba(0,0,0,.5)", backdropFilter: "blur(2px)" }}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={t("paletAc")}
        className="relative w-full max-w-xl"
        style={{
          borderRadius: "var(--yz-radius-card)",
          background: "var(--yz-metal-1)",
          borderWidth: "var(--yz-border-w)",
          borderStyle: "solid",
          borderColor: "var(--yz-border)",
          boxShadow: "var(--yz-raised-hover)",
        }}
      >
        <div className="p-3">
          <Girinti>
            <input
              ref={girdiRef}
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={girdiTus}
              placeholder={t("paletIpucu")}
              aria-label={t("aramaEtiket")}
              // ODAK GIRDIDE KALIR; secili satir bununla bildirilir.
              // Oklarla odagi tasisaydik kullanici yazmaya devam edemezdi.
              role="combobox"
              aria-expanded={vuruslar.length > 0}
              aria-controls={listeId}
              aria-activedescendant={
                vuruslar.length > 0 ? `${listeId}-${secili}` : undefined
              }
              className="odak-ic h-11 w-full bg-transparent px-3 outline-none"
              style={{ color: "var(--yz-text)", fontSize: "var(--yz-fs-body)" }}
            />
          </Girinti>
        </div>

        <div
          id={listeId}
          role="listbox"
          aria-label={t("aramaSonuclari")}
          className="max-h-[50vh] overflow-y-auto px-2 pb-2"
        >
          {vuruslar.length === 0 && !yukleniyor && q.trim().length >= 2 && (
            <p
              className="px-3 py-4"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("aramaSonucYok")}
            </p>
          )}
          {vuruslar.map((v, i) => (
            <button
              key={`${v.kaynak}-${v.id}`}
              id={`${listeId}-${i}`}
              type="button"
              role="option"
              aria-selected={i === secili}
              onClick={() => git(v)}
              onMouseEnter={() => setSecili(i)}
              className="flex w-full flex-col items-start gap-0.5 px-3 py-2 text-start"
              style={{
                borderRadius: "var(--yz-radius-btn)",
                background: i === secili ? "var(--yz-surface-2)" : undefined,
              }}
            >
              <span style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
                {v.baslik}
              </span>
              <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t(PALET_HEDEF[v.kaynak]?.etiket ?? YEDEK_ETIKET)}
                {v.ayrinti ? ` · ${v.ayrinti}` : ""}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
