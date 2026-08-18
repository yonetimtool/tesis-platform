"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { RaporModali, type RaporKatalogOgesi, type RaporSutun, type RaporTablosu } from "@/components/rapor/rapor-modali";
import { IkonKutu } from "@/components/tasarim";
import { useToast } from "@/components/Toast";
import {
  BosDurum,
  Dugme,
  HataDurumu,
  Kart,
  Rozet,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { agIstegi } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { kurusToTLSade } from "@/lib/money";
import { useT } from "@/lib/i18n/kullan";
import {
  DURUM_ETIKETI,
  KATEGORI_BASLIGI,
  KATEGORI_VURGUSU,
} from "@/lib/rapor-alanlari";

/**
 * P167 §5 — RAPOR MOTORU.
 *
 * =========================================================================
 * NE DEGISTI (P40'tan bu yana)
 * =========================================================================
 * Eskiden sayfa duz bir kart listesi + SAYFA ICINDE sabit dort alanli bir
 * parametre bolumuydu. Brief kategorili bir kart izgarasi ve rapor basina
 * DEGISEN alanlara sahip bir YAPILANDIRMA MODALI istiyor.
 *
 * Sabit dort alan gercek bir kusurdu, sadece bir eksiklik degil: kasa
 * ekstresi "kasa" secmeden, firma ekstresi "firma" secmeden calisiyordu.
 * Yani rapor uretiliyordu ama SORULAN SORUYU sormadan.
 *
 * =========================================================================
 * SAYFA HICBIR RAPOR ADINI TASIMAZ
 * =========================================================================
 * Katalog (kod, baslik, aciklama, KATEGORI, ALANLAR, AGIR) sunucudan
 * gelir. Rapor listesini ya da alan listesini burada tekrarlamak,
 * sunucuya eklenen bir raporun panelde unutulmasi demekti.
 *
 * =========================================================================
 * IKI SONUC ALANI, IKI AYRI SEBEP
 * =========================================================================
 *   * TABLO — "Goster" sonucu; ekranda okunur, indirilmez.
 *   * ISLER — kuyruga alinmis agir raporlar; hazir olunca indirilir.
 * Ikisini tek listede birlestirmek, "gosterilen" ile "uretilen"i ayni
 * seymis gibi gostermek olurdu.
 */

interface Katalog {
  items: RaporKatalogOgesi[];
  kategoriler: string[];
}

interface RaporIsi {
  id: string;
  kod: string;
  bicim: string;
  durum: string;
  dosya_adi: string | null;
  hata: string | null;
  created_at: string;
  biten_at: string | null;
}

const TIP_KURUS = "kurus";
const DURUM_HAZIR = "hazir";
const DURUM_HATA = "hata";
const YOK_ISARETI = "—";
/** Bekleyen is varken liste kendi kendine tazelenir. Kullaniciyi
 *  "yenile"ye basmaya birakmak, isin bittigini FARK ETMEMESI demekti. */
const TAZELEME_MS = 5000;
const ROZET_NOTR = "notr";
const VARSAYILAN_DURUM_ANAHTARI = "raporIsBekliyor";
const VARSAYILAN_KATEGORI_ANAHTARI = "raporKatDokumler";

/** Is durumu -> rozet rengi. Ucluda yazmak dorduncu bir durum eklendiginde
 *  sessizce "notr" birakirdi; harita eksigi GORUNUR kilar. */
const ROZET_DURUMU: Record<string, "olumlu" | "kritik" | "bilgi"> = {
  hazir: "olumlu",
  hata: "kritik",
  bekliyor: "bilgi",
  uretiliyor: "bilgi",
};

/** Hucre metni. KURUS sutunu TL'ye cevrilir — Excel/PDF ile ayni rakam. */
function hucreMetni(sutun: RaporSutun, ham: unknown): string {
  if (ham === null || ham === undefined) return YOK_ISARETI;
  if (sutun.tip === TIP_KURUS && typeof ham === "number") return kurusToTLSade(ham);
  return String(ham);
}

function KategoriIkonu() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M6 3h9l5 5v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path d="M14 3v6h6M8.5 13h7M8.5 17h4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

export default function RaporlarPage() {
  const t = useT();
  const toast = useToast();
  const { data: katalog, error: katErr } = useSWR<Katalog>(
    "/api/panel/rapor-katalog",
    jsonFetcher,
  );
  const {
    data: isler,
    error: isErr,
    mutate: islerTazele,
  } = useSWR<RaporIsi[]>("/api/panel/rapor/isler", jsonFetcher, {
    // `Array.isArray` KONTROLU SART: vekil bir hata dondurdugunde govde
    // bir NESNEDIR (`{error: ...}`), dizi degil. `veri ?? []` bunu
    // yakalamaz ve `some` cagrisi sayfayi COKERTIRDI — hem de tam olarak
    // sunucunun sorunlu oldugu anda.
    refreshInterval: (veri) =>
      (Array.isArray(veri) ? veri : []).some(
        (i) => i.durum !== DURUM_HAZIR && i.durum !== DURUM_HATA,
      )
        ? TAZELEME_MS
        : 0,
  });

  const [secili, setSecili] = useState<RaporKatalogOgesi | null>(null);
  const [tablo, setTablo] = useState<RaporTablosu | null>(null);
  const [hata, setHata] = useState<string | null>(null);

  /** Kategori -> raporlar. SIRA SUNUCUDAN (`kategoriler`): alfabetik
   *  siralamak "Listeler"i "Dokumler"in altina duserirdi. */
  const bolumler = useMemo(() => {
    const items = katalog?.items ?? [];
    return (katalog?.kategoriler ?? []).map((k) => ({
      id: k,
      raporlar: items.filter((r) => r.kategori === k),
    }));
  }, [katalog]);

  async function indir(is: RaporIsi): Promise<void> {
    setHata(null);
    try {
      const res = await agIstegi(`/api/panel/rapor/isler/${is.id}/indir`);
      if (res === null) return; // oturum bitti -> yonlendirildi
      const veri = await res.json().catch(() => null);
      if (!res.ok) throw new Error(veri?.error?.message ?? String(res.status));
      // Baglanti KISA OMURLU presigned URL — yeni sekmede acilir, cunku
      // ayni sekmede gezinmek panelden cikmak olurdu.
      window.open(veri.url as string, "_blank", "noopener");
      toast.success(t("raporIndirildi"));
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  const kolonlar: Kolon<Record<string, unknown>>[] = useMemo(
    () =>
      (tablo?.sutunlar ?? []).map((s) => ({
        id: s.anahtar,
        baslik: s.baslik,
        sayisal: s.tip === TIP_KURUS,
        hucre: (satir: Record<string, unknown>) => hucreMetni(s, satir[s.anahtar]),
        deger: (satir: Record<string, unknown>) => {
          const ham = satir[s.anahtar];
          return typeof ham === "number" || typeof ham === "string" ? ham : null;
        },
      })),
    [tablo],
  );

  const isKolonlari: Kolon<RaporIsi>[] = useMemo(
    () => [
      {
        id: "kod", kartRolu: "baslik",
        baslik: t("raporIsAdi"),
        hucre: (i) =>
          (katalog?.items ?? []).find((r) => r.kod === i.kod)?.baslik ?? i.kod,
      },
      { id: "bicim", kartRolu: "ozet", baslik: t("raporIsBicim"), hucre: (i) => i.bicim },
      {
        id: "durum", kartRolu: "rozet",
        baslik: t("ortakDurum"),
        hucre: (i) => (
          <Rozet
            durum={ROZET_DURUMU[i.durum] ?? ROZET_NOTR}
          >
            {t(DURUM_ETIKETI[i.durum] ?? VARSAYILAN_DURUM_ANAHTARI)}
          </Rozet>
        ),
      },
      {
        id: "created_at", kartRolu: "ozet",
        baslik: t("raporIsZaman"),
        hucre: (i) => new Date(i.created_at).toLocaleString(),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: t("listeIslemler"),
        hucre: (i) =>
          // "Indir" YALNIZ hazir iste cizilir: hazir olmayan bir isin
          // dugmesi, tiklandiginda hicbir sey olmayan bir dugme olurdu.
          i.durum === DURUM_HAZIR ? (
            <Dugme boy="kucuk" onClick={() => void indir(i)}>
              {t("raporIsIndir")}
            </Dugme>
          ) : (
            <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {i.hata ?? YOK_ISARETI}
            </span>
          ),
      },
    ],
    [katalog, t],
  );

  const toplamVar = tablo != null && Object.keys(tablo.toplamlar ?? {}).length > 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("raporBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("raporAlt")}
        </p>
      </div>

      {(katErr || hata) && <HataDurumu mesaj={katErr ? t("raporKatalogHata") : hata!} />}

      {/* --------------------------- kart izgarasi -------------------------- */}
      {katalog && katalog.items.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("raporYok")} aciklama={t("raporYokAlt")} />
        </Kart>
      ) : null}

      {bolumler.map((bolum) =>
        bolum.raporlar.length === 0 ? null : (
          <section key={bolum.id} className="space-y-3">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t(KATEGORI_BASLIGI[bolum.id] ?? VARSAYILAN_KATEGORI_ANAHTARI)}
            </h2>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {bolum.raporlar.map((r) => (
                <button
                  key={r.kod}
                  type="button"
                  // KART BIR DIYALOG ACAR, bir secim degildir. Eskiden
                  // `aria-pressed` vardi (P160) cunku secim SAYFA ICINDE
                  // kaliyordu; simdi bir modal aciliyor ve `aria-pressed`
                  // ekran okuyucuya "acik/kapali bir anahtar" diye YANLIS
                  // bilgi verirdi. Secilenin ne oldugunu artik diyalogun
                  // KENDI BASLIGI soyluyor.
                  aria-haspopup="dialog"
                  onClick={() => setSecili(r)}
                  className="odak-ic yz-lift flex items-start gap-3 p-3 text-start"
                  style={{
                    borderRadius: "var(--yz-radius-btn)",
                    border: "var(--yz-border-w) solid var(--yz-border)",
                    background: "var(--yz-metal-1)",
                  }}
                >
                  <IkonKutu vurgu={KATEGORI_VURGUSU[bolum.id] ?? "blue"} kucuk>
                    <KategoriIkonu />
                  </IkonKutu>
                  <span className="min-w-0">
                    <span
                      className="block"
                      style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
                    >
                      {r.baslik}
                    </span>
                    <span
                      className="mt-1 block"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                    >
                      {r.aciklama}
                    </span>
                  </span>
                </button>
              ))}
            </div>
          </section>
        ),
      )}

      {/* ------------------------ yapilandirma modali ----------------------- */}
      <RaporModali
        rapor={secili}
        kapat={() => setSecili(null)}
        onTablo={(veri) => setTablo(veri)}
        onKuyruk={() => void islerTazele()}
      />

      {/* ------------------------------ isler ------------------------------ */}
      {isErr || !Array.isArray(isler) || isler.length === 0 ? null : (
        <section className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("raporIslerim")}
          </h2>
          <VeriTablosu<RaporIsi>
            kolonlar={isKolonlari}
            satirlar={isler}
            satirId={(i) => i.id}
            bosBaslik={t("raporIsYok")}
            bosAciklama={t("raporIsYokAlt")}
          />
        </section>
      )}

      {/* ------------------------------ sonuc ------------------------------ */}
      {tablo ? (
        <div className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{tablo.baslik}</h2>
          {tablo.metin ? (
            // Serbest metin bolumu (ihtar govdesi, denetim notu): duz metin
            // olarak cizilir — HTML kabul etmek XSS yuzeyi acardi.
            <Kart>
              <pre
                className="whitespace-pre-wrap"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text)" }}
              >
                {tablo.metin}
              </pre>
            </Kart>
          ) : null}
          {/* SATIR YOKSA BOS DURUM — sutun sayisindan BAGIMSIZ (P160):
              sutunsuz donen raporlarda (serbest metin raporlari) ekranda
              hicbir sey kalmiyor, yani "kayit bulunamadi" bilgisi
              kayboluyordu. */}
          {tablo.satirlar.length === 0 ? (
            <Kart>
              <BosDurum baslik={t("raporSatirYok")} aciklama={t("raporSatirYokAlt")} />
            </Kart>
          ) : (
            <VeriTablosu<Record<string, unknown>>
              kolonlar={kolonlar}
              satirlar={tablo.satirlar}
              // Rapor satirlarinin kimligi YOK; sira numarasi kararlidir
              // cunku liste tek seferde gelir ve yerinde degismez.
              satirId={(satir) => String(tablo.satirlar.indexOf(satir))}
              bosBaslik={t("raporSatirYok")}
              bosAciklama={t("raporSatirYokAlt")}
              altbilgi={
                toplamVar
                  ? (gorunen) => (
                      <tr>
                        {gorunen.map((k, i) => (
                          <td
                            key={k.id}
                            className={["p-3", k.sayisal ? "text-end tabular-nums" : ""]
                              .filter(Boolean)
                              .join(" ")}
                            style={{
                              fontSize: "var(--yz-fs-body)",
                              fontWeight: 600,
                              color: "var(--yz-text)",
                            }}
                          >
                            {i === 0
                              ? t("ortakToplam")
                              : hucreMetni(
                                  tablo.sutunlar.find((s) => s.anahtar === k.id)!,
                                  tablo.toplamlar[k.id],
                                )}
                          </td>
                        ))}
                      </tr>
                    )
                  : undefined
              }
            />
          )}
        </div>
      ) : null}
    </div>
  );
}
