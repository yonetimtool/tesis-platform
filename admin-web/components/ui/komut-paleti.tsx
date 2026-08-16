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
import { ogeBaglantisi, sayfaAra, type SayfaVurusu } from "@/lib/menu";
import { useRol } from "@/lib/rol-kullan";
import type { Yuzey } from "@/lib/yuzey";

import { Girinti } from "./yuzey";

export interface PaletVurusu {
  kaynak: string;
  id: string;
  baslik: string;
  ayrinti?: string | null;
}

/**
 * Kaynak -> (etiket anahtari, rota, ikon). `GlobalArama` ile AYNI tablo.
 *
 * (P162 §3) SEKIZ KAYNAKTAN ON YEDIYE. Sunucu artik demirbas, etkinlik,
 * arac, NFC noktasi, kamera, devriye plani, vardiya, icra ve sayac da
 * tariyor; bu tablo onlarin NEREYE GOTURECEGINI soyler. Tablodaki bir
 * kaynak eksik kalirsa sonuc koke ("/") giderdi — yani kullanici
 * tikladigi kaydi bulamazdi. `tests/global-arama.test.ts` sunucudaki
 * kaynak listesiyle bu tablonun AYNI oldugunu kilitler.
 *
 * IKON: kaynak turunu bir bakista ayirir (brief: "tipe gore gruplanmis,
 * ikonlu"). Tek bir `path` dizesi — ayri ikon dosyasi getirmeye degmez.
 */
export interface PaletHedef {
  etiket: SozlukAnahtari;
  rota: string;
  /** 24x24 `viewBox` icin SVG `d` — cizgi ikon. */
  ikon: string;
}

const I_KISI = "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8";
const I_BINA = "M3 21h18M5 21V7l7-4 7 4v14M9 21v-4h6v4";
const I_KUTU = "M21 8v8a2 2 0 0 1-1 1.7l-7 4a2 2 0 0 1-2 0l-7-4A2 2 0 0 1 3 16V8a2 2 0 0 1 1-1.7l7-4a2 2 0 0 1 2 0l7 4A2 2 0 0 1 21 8zM3.3 7L12 12l8.7-5M12 22V12";
const I_LISTE = "M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01";
const I_MEGAFON = "M3 11v2a1 1 0 0 0 1 1h2l4 4V6L6 10H4a1 1 0 0 0-1 1zM16 8a5 5 0 0 1 0 8";
const I_TAKVIM = "M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z";
const I_SOHBET = "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z";
const I_PARA = "M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6";
const I_ARAC = "M5 17h14M6 17v2M18 17v2M3 13l2-6h14l2 6v4H3zM7 13h.01M17 13h.01";
const I_NOKTA = "M12 21s7-6 7-11a7 7 0 1 0-14 0c0 5 7 11 7 11zM12 10h.01";
const I_KAMERA = "M23 7l-7 5 7 5V7zM14 5H3a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2z";
const I_ROTA = "M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01";
const I_SAAT = "M12 6v6l4 2M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z";
const I_DOSYA = "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6M9 15h6";
const I_SAYAC = "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM12 12l4-4";
const I_FIRMA = "M3 21h18M5 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16M15 21v-9h4v9M9 7h2M9 11h2M9 15h2";

export const PALET_HEDEF: Record<string, PaletHedef> = {
  kisi: { etiket: "kabukKullanicilar", rota: "/users", ikon: I_KISI },
  daire: { etiket: "kabukDaireler", rota: "/units", ikon: I_BINA },
  blok: { etiket: "kabukBinaDuzenleme", rota: "/building-editor", ikon: I_BINA },
  firma: { etiket: "kabukTanimlar", rota: "/tanimlar", ikon: I_FIRMA },
  gorev: { etiket: "kabukGorevler", rota: "/tasks", ikon: I_LISTE },
  duyuru: { etiket: "kabukDuyurular", rota: "/announcements", ikon: I_MEGAFON },
  talep: { etiket: "kabukTalepler", rota: "/complaints", ikon: I_SOHBET },
  finans: { etiket: "kabukFinans", rota: "/finans", ikon: I_PARA },
  demirbas: { etiket: "kabukDemirbas", rota: "/assets", ikon: I_KUTU },
  etkinlik: { etiket: "kabukEtkinlikler", rota: "/etkinlikler", ikon: I_TAKVIM },
  arac: { etiket: "kabukAraclar", rota: "/tanimlar", ikon: I_ARAC },
  nokta: { etiket: "kabukNfcNoktalari", rota: "/checkpoints", ikon: I_NOKTA },
  kamera: { etiket: "kabukKameralar", rota: "/kameralar", ikon: I_KAMERA },
  plan: { etiket: "kabukDevriyePlanlari", rota: "/patrol-plans", ikon: I_ROTA },
  vardiya: { etiket: "kabukVardiyalar", rota: "/shifts", ikon: I_SAAT },
  icra: { etiket: "kabukIcra", rota: "/icra", ikon: I_DOSYA },
  sayac: { etiket: "kabukSayaclar", rota: "/tanimlar", ikon: I_SAYAC },
};

const UC = "/api/panel/arama";
const YEDEK_ETIKET: SozlukAnahtari = "aramaEtiket";
const GECIKME_MS = 300;
const KOK_ROTA = "/";
const BUYUK_HARF = "uppercase" as const;

/** Kaynak ikonu — 24x24 cizgi. */
function Ikon({ d }: { d: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-3.5 w-3.5 shrink-0"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={d} />
    </svg>
  );
}

/**
 * Vuruslari KAYNAGA gore gruplar ve her grubun DUZ LISTEDEKI baslangic
 * indeksini tasir.
 *
 * Baslangic indeksi olmadan klavye gezinmesi kirilirdi: `secili` duz bir
 * sayidir (0..n-1) ve gruplu cizimde her grup kendi icinde 0'dan
 * baslasaydi ikinci gruptaki ilk oge de "0" olurdu.
 */
export function vuruslariGrupla(
  vuruslar: PaletVurusu[],
): { kaynak: string; ogeler: PaletVurusu[]; baslangic: number }[] {
  const gruplar: { kaynak: string; ogeler: PaletVurusu[]; baslangic: number }[] = [];
  for (const v of vuruslar) {
    const son = gruplar[gruplar.length - 1];
    // BITISIK AYNI KAYNAKLAR tek grup: sunucu kaynagi bloklar halinde
    // donuyor. Haritaya almak yerine bitisiklik kullanmak, sunucunun
    // siralamasini oldugu gibi korur.
    if (son && son.kaynak === v.kaynak) son.ogeler.push(v);
    else gruplar.push({ kaynak: v.kaynak, ogeler: [v], baslangic: 0 });
  }
  let n = 0;
  for (const g of gruplar) {
    g.baslangic = n;
    n += g.ogeler.length;
  }
  return gruplar;
}

export function KomutPaleti({
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
  const [acik, setAcik] = useState(false);
  const [q, setQ] = useState("");
  const [vuruslar, setVuruslar] = useState<PaletVurusu[]>([]);
  const [secili, setSecili] = useState(0);
  const [yukleniyor, setYukleniyor] = useState(false);
  const girdiRef = useRef<HTMLInputElement | null>(null);
  const acanRef = useRef<HTMLElement | null>(null);
  const listeId = useId();
  const gruplar = vuruslariGrupla(vuruslar);

  /* (P166 §2) SAYFALAR — `GlobalArama` ile AYNI fonksiyondan, ayni yetki
   * kapisindan. Palet burada da kendi suzgecini yazmiyor. */
  const sayfalar: SayfaVurusu[] = acik ? sayfaAra(yuzey, rol, q, t) : [];
  /* KLAVYE INDEKSI TEK DIZI UZERINDE: sayfalar once (0..n-1), kayitlar
   * onlarin ardindan. Iki ayri sayac tutmak, ok tuslarinin gruplar
   * arasinda takilmasi demekti. */
  const toplamSatir = sayfalar.length + vuruslar.length;

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

  function sayfayaGit(s: SayfaVurusu) {
    kapat();
    router.push(ogeBaglantisi(s.oge));
  }

  /** Duz indeksi (sayfa mi kayit mi) cozup gider. */
  function indekseGit(i: number) {
    const s = sayfalar[i];
    if (s) {
      sayfayaGit(s);
      return;
    }
    const v = vuruslar[i - sayfalar.length];
    if (v) git(v);
  }

  function girdiTus(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Escape") {
      e.preventDefault();
      kapat();
      return;
    }
    if (toplamSatir === 0) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setSecili((s) => (s + 1) % toplamSatir);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSecili((s) => (s - 1 + toplamSatir) % toplamSatir);
    } else if (e.key === "Enter") {
      e.preventDefault();
      indekseGit(secili);
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
              aria-expanded={toplamSatir > 0}
              aria-controls={listeId}
              aria-activedescendant={
                toplamSatir > 0 ? `${listeId}-${secili}` : undefined
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
          {toplamSatir === 0 && !yukleniyor && q.trim().length >= 2 && (
            <p
              className="px-3 py-4"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("aramaSonucYok")}
            </p>
          )}
          {/* (P162 §3) TIPE GORE GRUPLU. Duz bir liste, on yedi kaynakta
              okunmaz oluyordu: kullanici "bu hangi tur kayit" sorusunu
              her satirda yeniden soruyordu. Gruplama SUNUCUNUN dondugu
              SIRAYI korur (kaynak sirasi zaten anlamli) — istemcide
              yeniden siralamak, sunucunun oncelik karari varsa onu
              bozardi.

              KLAVYE INDEKSI DUZ KALIR: `mutlakIndeks` gruplar arasinda
              artmaya devam eder, yoksa ok tuslari grup basinda takilirdi. */}
          {/* (P166 §2) SAYFALAR GRUBU — kayitlarin USTUNDE ve AYRI. */}
          {sayfalar.length > 0 && (
            <div role="group" aria-labelledby={`${listeId}-b-sayfa`}>
              <p
                id={`${listeId}-b-sayfa`}
                className="flex items-center gap-1.5 px-3 pb-1 pt-3"
                style={{
                  fontSize: "var(--yz-fs-xs)",
                  color: "var(--yz-text-3)",
                  textTransform: BUYUK_HARF,
                  letterSpacing: "0.04em",
                }}
              >
                <Ikon d={I_LISTE} />
                {t("aramaSayfalar")}
              </p>
              {sayfalar.map((s, i) => (
                <button
                  key={ogeBaglantisi(s.oge)}
                  id={`${listeId}-${i}`}
                  type="button"
                  role="option"
                  aria-selected={i === secili}
                  onClick={() => sayfayaGit(s)}
                  onMouseEnter={() => setSecili(i)}
                  className="flex w-full flex-col items-start gap-0.5 px-3 py-2 text-start"
                  style={{
                    borderRadius: "var(--yz-radius-btn)",
                    background: i === secili ? "var(--yz-surface-2)" : undefined,
                  }}
                >
                  <span style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
                    {t(s.oge.anahtar)}
                  </span>
                  <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                    {t(s.grupAnahtari)}
                  </span>
                </button>
              ))}
            </div>
          )}
          {gruplar.map(({ kaynak, ogeler, baslangic }) => (
            <div key={kaynak} role="group" aria-labelledby={`${listeId}-b-${kaynak}`}>
              <p
                id={`${listeId}-b-${kaynak}`}
                className="flex items-center gap-1.5 px-3 pb-1 pt-3"
                style={{
                  fontSize: "var(--yz-fs-xs)",
                  color: "var(--yz-text-3)",
                  textTransform: BUYUK_HARF,
                  letterSpacing: "0.04em",
                }}
              >
                <Ikon d={PALET_HEDEF[kaynak]?.ikon ?? ""} />
                {t(PALET_HEDEF[kaynak]?.etiket ?? YEDEK_ETIKET)}
              </p>
              {ogeler.map((v, j) => {
                // SAYFALAR duz indeksin BASINDA durdugu icin kayit
                // indeksleri onlarin sayisi kadar kayar.
                const i = sayfalar.length + baslangic + j;
                return (
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
                    {v.ayrinti && (
                      <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                        {v.ayrinti}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
