"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { ogeBaglantisi, sayfaAra, type SayfaVurusu } from "@/lib/menu";
import { useRol } from "@/lib/rol-kullan";
import { SAKIN_MODU, rotaRoldeGorunur, type Yuzey } from "@/lib/yuzey";

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

/**
 * (P247 §2) SAKIN MODUNDA kayit -> SAKININ kendi ekrani.
 *
 * Sunucu sakin modunda zaten sakin kapsamiyla arar (duyuru, KENDI
 * talepleri). Ama yukaridaki harita YONETIM ekranlarina gider ve
 * middleware onlari sakin modunda Aidatim'a geri atar — tiklanan sonuc
 * baska bir yere varirdi. Burada yoksa sonuc sakin modunda CIZILMEZ.
 */
const SAKIN_HEDEF: Record<string, { etiket: SozlukAnahtari; rota: string }> = {
  duyuru: { etiket: "kabukDuyurularim", rota: "/duyurular" },
  talep: { etiket: "kabukTaleplerim", rota: "/taleplerim" },
};

function kayitHedefi(
  kaynak: string,
  rol: string | null,
): { etiket: SozlukAnahtari; rota: string } | null {
  if (rol !== SAKIN_MODU) return HEDEF[kaynak] ?? null;
  const h = SAKIN_HEDEF[kaynak];
  return h && rotaRoldeGorunur(h.rota, rol) ? h : null;
}

const UC = "/api/panel/arama";
// Bilinmeyen kaynak icin yedek etiket. Modul duzeyinde adlandirildi:
// `t(... ?? "aramaEtiket")` yazmak, `sabit-metin` taramasinda ucludaki
// dizgeyi (cevrilmemis metin adayi) hakli olarak isaretletiyordu — oysa
// bu bir CEVIRI ANAHTARI, gorunen metin degil.
const _YEDEK_ETIKET: SozlukAnahtari = "aramaEtiket";
//: Tuslama basina istek atmak, her harfte bir tam metin taramasi demekti.
const GECIKME_MS = 300;

export function GlobalArama({
  yuzey,
  rolBaslangic,
}: {
  yuzey: Yuzey;
  /** Sunucunun cerezden cozdugu rol; `null` ise `/api/me` ile tamamlanir. */
  rolBaslangic: string | null;
}) {
  const t = useT();
  const router = useRouter();
  const rol = useRol(rolBaslangic);
  const [q, setQ] = useState("");
  const [vuruslar, setVuruslar] = useState<Vurus[]>([]);
  // (P247 §2) Sakin modunda gidecegi ekrani olmayan kayit cizilmez.
  const gorunenVuruslar =
    rol === SAKIN_MODU
      ? vuruslar.filter((v) => kayitHedefi(v.kaynak, rol) !== null)
      : vuruslar;
  const [acik, setAcik] = useState(false);
  const [yukleniyor, setYukleniyor] = useState(false);
  const kutuRef = useRef<HTMLDivElement>(null);

  /* (P166 §2) SAYFALAR — kayit sonuclarindan AYRI grup.
   *
   * ANINDA cizilir, sunucu yanitini BEKLEMEZ: kume istemcide (menu
   * kaydinda) zaten duruyor. 300 ms gecikme kayit aramasi icindir —
   * "aidat" yazan kullaniciyi sayfa sonucu icin de bekletmek, elde olan
   * bilgiyi saklamak olurdu.
   *
   * `t` her karede yeni bir kapanis oldugu icin bagimliliga KONMADI;
   * konsaydi `useMemo` her cizimde yeniden hesaplanir, yani `useMemo`
   * hicbir sey yapmazdi. Dil degisimi zaten kabugu yeniden monte eder. */
  const sayfalar = useMemo(
    () => sayfaAra(yuzey, rol, q, t),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [yuzey, rol, q],
  );

  useEffect(() => {
    // EN AZ IKI KARAKTER — sunucunun kurali (422). Istemcide de
    // uygulamak, kullaniciya sebepsiz bir hata gostermemek icin.
    if (q.trim().length < 2) {
      setVuruslar([]);
      setAcik(false);
      return;
    }
    // (P166 §2) LISTE HEMEN ACILIR. Eskiden yalniz sunucu yaniti gelince
    // aciliyordu; sayfa sonuclari istemcide HAZIR oldugu icin bu, elde
    // olan cevabi 300 ms saklamak olurdu.
    setAcik(true);
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
    router.push(kayitHedefi(v.kaynak, rol)?.rota ?? "/");
  }

  function sayfayaGit(s: SayfaVurusu) {
    setAcik(false);
    setQ("");
    router.push(ogeBaglantisi(s.oge));
  }

  return (
    <div ref={kutuRef} className="relative w-full max-w-md">
      {/* (P244 §2) ARAMA ALANI YENI DILE TASINDI.
          Eski sinif dizesi (`border-slate-300 bg-[color:var(--yz-surface-1)]
          text-[color:var(--yz-text)]`) ESKI dilin kalintisiydi: kabuk her sayfada
          ciziliyor, yani urunun en cok gorunen tek kontrolu eski dilde
          kaliyordu. */}
      <input
        type="search"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        onFocus={() => (gorunenVuruslar.length > 0 || sayfalar.length > 0) && setAcik(true)}
        onKeyDown={(e) => e.key === "Escape" && setAcik(false)}
        placeholder={t("aramaIpucu")}
        aria-label={t("aramaEtiket")}
        className="odak-ic w-full outline-none transition"
        style={{
          borderRadius: "var(--yz-radius-btn)",
          border: "var(--yz-border-w) solid var(--yz-border)",
          background: "var(--yz-surface-1)",
          color: "var(--yz-text)",
          fontSize: "var(--yz-fs-sm)",
          // SAG BOSLUK KISAYOL ROZETI ICIN: rozet alanin USTUNDE duruyor,
          // metin altina girmesin.
          padding: "0 5.5rem 0 0.75rem",
        }}
      />
      {/* (P244 §2) KISAYOL ROZETI — referansta arama alaninin sag ucunda.
          DEKORATIF DEGIL: kisayol (Ctrl/Cmd+K) P166'dan beri CALISIYOR ama
          hicbir yerde YAZMIYORDU, yani yalniz deneyerek bulunabiliyordu.
          `aria-hidden`: alanin erisilebilir adi `aria-label`dan geliyor,
          rozet onu tekrarlayip uzatmasin. */}
      <kbd
        aria-hidden="true"
        className="pointer-events-none absolute end-2 top-1/2 -translate-y-1/2 select-none rounded px-1.5 py-0.5 font-sans"
        style={{
          fontSize: "var(--yz-fs-xs)",
          color: "var(--yz-text-3)",
          background: "var(--yz-surface-2)",
          border: "var(--yz-border-w) solid var(--yz-border)",
        }}
      >
        {t("kabukAramaKisayolu")}
      </kbd>

      {acik && (
        <div
          role="listbox"
          aria-label={t("aramaSonuclari")}
          className="border-[color:var(--yz-border)] absolute end-0 top-full z-40 mt-1 max-h-80 w-full overflow-y-auto rounded-kart border bg-[color:var(--yz-surface-1)] shadow-yuzen"
        >
          {gorunenVuruslar.length === 0 && sayfalar.length === 0 && !yukleniyor && (
            <p className="px-3 py-4 text-sm text-[color:var(--yz-text-2)]">{t("aramaSonucYok")}</p>
          )}

          {/* (P166 §2) SAYFALAR ONCE. Kullanici bir sayfa adi yazdiysa
              (`aidat`, `devriye`) aradigi sey neredeyse her zaman o
              sayfadir; onlarca aidat KAYDININ altina gomulmesi, aramayi
              yine ise yaramaz kilardi. Ayri baslik da brief'in sarti. */}
          {sayfalar.length > 0 && (
            <div role="group" aria-labelledby="arama-sayfalar-baslik">
              <p
                id="arama-sayfalar-baslik"
                className="px-3 pb-1 pt-2 text-xs uppercase tracking-wide text-[color:var(--yz-text-2)]"
              >
                {t("aramaSayfalar")}
              </p>
              {sayfalar.map((s) => (
                <button
                  key={ogeBaglantisi(s.oge)}
                  type="button"
                  role="option"
                  aria-selected={false}
                  onClick={() => sayfayaGit(s)}
                  className="flex w-full flex-col items-start gap-0.5 px-3 py-2 text-start transition hover:bg-[color:var(--yz-border)]"
                >
                  <span className="text-sm font-medium">{t(s.oge.anahtar)}</span>
                  <span className="text-xs text-[color:var(--yz-text-2)]">{t(s.grupAnahtari)}</span>
                </button>
              ))}
            </div>
          )}

          {gorunenVuruslar.length > 0 && sayfalar.length > 0 && (
            <p
              className="px-3 pb-1 pt-2 text-xs uppercase tracking-wide text-[color:var(--yz-text-2)]"
              aria-hidden="true"
            >
              {t("aramaKayitlar")}
            </p>
          )}
          {gorunenVuruslar.map((v) => (
            <button
              key={`${v.kaynak}-${v.id}`}
              type="button"
              role="option"
              aria-selected={false}
              onClick={() => git(v)}
              className="flex w-full flex-col items-start gap-0.5 px-3 py-2 text-start transition hover:bg-[color:var(--yz-border)]"
            >
              <span className="text-sm font-medium">{v.baslik}</span>
              <span className="text-xs text-[color:var(--yz-text-2)]">
                {t(kayitHedefi(v.kaynak, rol)?.etiket ?? _YEDEK_ETIKET)}
                {v.ayrinti ? ` · ${v.ayrinti}` : ""}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
