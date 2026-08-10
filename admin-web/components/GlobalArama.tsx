"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P154 / Asama 6.3) GLOBAL ARAMA — ust barda, TEK yer.
 *
 * Brief: "Merkezi kur, her ekrana ayri arama yazma." Ayri yazilsaydi
 * yetki kurali her ekranda tekrar edilirdi ve biri unutuldugunda sizinti
 * SESSIZ olurdu.
 *
 * YETKI SUNUCUDA, BURADA DEGIL: bu bilesen ne gorunecegine KARAR VERMEZ,
 * yalnizca `/api/panel/arama`nin donduklerini cizer. Istemcide suzmek,
 * veriyi tarayiciya GONDERIP saklamak olurdu — yani hic suzmemek.
 *
 * KAYNAK -> HEDEF esleme burada durur cunku bu bir YONLENDIRME karari
 * (hangi ekran o kaydi gosterir), sunucunun bilgisi degil.
 */

interface Vurus {
  kaynak: string;
  id: string;
  baslik: string;
  ayrinti?: string | null;
}

/** Kaynak -> (etiket anahtari, gidilecek rota). */
const HEDEF: Record<string, { etiket: SozlukAnahtari; rota: string }> = {
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
// Bilinmeyen kaynak icin yedek etiket. Modul duzeyinde adlandirildi:
// `t(... ?? "aramaEtiket")` yazmak, `sabit-metin` taramasinda ucludaki
// dizgeyi (cevrilmemis metin adayi) hakli olarak isaretletiyordu — oysa
// bu bir CEVIRI ANAHTARI, gorunen metin degil.
const _YEDEK_ETIKET: SozlukAnahtari = "aramaEtiket";
//: Tuslama basina istek atmak, her harfte bir tam metin taramasi demekti.
const GECIKME_MS = 300;

export function GlobalArama() {
  const t = useT();
  const router = useRouter();
  const [q, setQ] = useState("");
  const [vuruslar, setVuruslar] = useState<Vurus[]>([]);
  const [acik, setAcik] = useState(false);
  const [yukleniyor, setYukleniyor] = useState(false);
  const kutuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // EN AZ IKI KARAKTER — sunucunun kurali (422). Istemcide de
    // uygulamak, kullaniciya sebepsiz bir hata gostermemek icin.
    if (q.trim().length < 2) {
      setVuruslar([]);
      setAcik(false);
      return;
    }
    let iptal = false;
    setYukleniyor(true);
    const zaman = setTimeout(async () => {
      try {
        const r = await fetch(`${UC}?q=${encodeURIComponent(q.trim())}`);
        if (!r.ok) throw new Error(String(r.status));
        const govde = (await r.json()) as { items: Vurus[] };
        if (iptal) return;
        setVuruslar(govde.items);
        setAcik(true);
      } catch {
        // SESSIZ: arama ikincil bir yuzeydir. Ust barda kirmizi bir hata
        // kutusu acmak, kullanicinin asil isini bolerdi.
        if (!iptal) setVuruslar([]);
      } finally {
        if (!iptal) setYukleniyor(false);
      }
    }, GECIKME_MS);
    return () => {
      iptal = true;
      clearTimeout(zaman);
    };
  }, [q]);

  // DISARI TIKLAYINCA KAPAN: acik kalan bir sonuc listesi, kullanici
  // baska bir ise gectiginde ekranin ustunde asili kalirdi.
  useEffect(() => {
    function tik(e: MouseEvent) {
      if (!kutuRef.current?.contains(e.target as Node)) setAcik(false);
    }
    document.addEventListener("mousedown", tik);
    return () => document.removeEventListener("mousedown", tik);
  }, []);

  function git(v: Vurus) {
    setAcik(false);
    setQ("");
    router.push(HEDEF[v.kaynak]?.rota ?? "/");
  }

  return (
    <div ref={kutuRef} className="relative w-full max-w-md">
      <input
        type="search"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        onFocus={() => vuruslar.length > 0 && setAcik(true)}
        onKeyDown={(e) => e.key === "Escape" && setAcik(false)}
        placeholder={t("aramaIpucu")}
        aria-label={t("aramaEtiket")}
        className="w-full rounded-lg border border-slate-300 bg-yuzey-card px-3 py-1.5 text-sm text-metin-body outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/25"
      />

      {acik && (
        <div
          role="listbox"
          aria-label={t("aramaSonuclari")}
          className="kart-kenar absolute end-0 top-full z-40 mt-1 max-h-80 w-full overflow-y-auto rounded-kart border bg-yuzey-card shadow-yuzen"
        >
          {vuruslar.length === 0 && !yukleniyor && (
            <p className="px-3 py-4 text-sm text-metin-muted">{t("aramaSonucYok")}</p>
          )}
          {vuruslar.map((v) => (
            <button
              key={`${v.kaynak}-${v.id}`}
              type="button"
              role="option"
              aria-selected={false}
              onClick={() => git(v)}
              className="flex w-full flex-col items-start gap-0.5 px-3 py-2 text-start transition hover:bg-yuzey-divider"
            >
              <span className="text-sm font-medium">{v.baslik}</span>
              <span className="text-xs text-metin-muted">
                {t(HEDEF[v.kaynak]?.etiket ?? _YEDEK_ETIKET)}
                {v.ayrinti ? ` · ${v.ayrinti}` : ""}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
