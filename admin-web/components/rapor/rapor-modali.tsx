"use client";

// (P167 §5) ORTAK RAPOR MODALI.
//
// Brief: "Ortak bir RaporModali bileseni yaz; her rapor kendi alan
// tanimini versin. Her raporda ayri modal kodu YAZMA."
//
// =========================================================================
// ALAN TANIMI NEREDEN GELIYOR
// =========================================================================
// Katalogdan: `/raporlar/katalog` her rapor icin `alanlar: string[]`
// doner. Bu bilesen o adlari `ALAN_TANIMLARI` sozlugunden cozup cizer.
//
// Yani "hangi alanlar" SUNUCUNUN, "nasil cizilir" ISTEMCININ bilgisi.
// Ikisini de istemcide tutsaydik, bir rapora yeni suzgec eklendiginde
// alan cizilir ama sunucu okumazdi — ve bu SESSIZ bir kusurdur.
//
// =========================================================================
// DORT DUGME, UC AYRI DAVRANIS
// =========================================================================
//   [Iptal]  modali kapatir.
//   [Goster] tablo bicimini ceker, modali kapatir, sonucu sayfaya verir.
//   [PDF] / [Excel] dosya uretir.
//
// Ve PDF/Excel'in IKI YOLU var: rapor `agir` isaretliyse istek KUYRUGA
// gider (202 + is kimligi), degilse dosya dogrudan iner. Karari SUNUCU
// verir — hangi raporun tum defteri taradigini istemci bilemez.
//
// "Goster" agir raporlarda da SENKRONDUR: kullanici ekranda gormek
// istiyorsa zaten beklemeye razidir ve tabloyu kuyruga almak, gormek
// istedigi seyi indirilecek bir dosyaya cevirmek olurdu.

import { useEffect, useMemo, useState } from "react";

import {
  useDaireler,
  useFirmalar,
  useGelirGiderTanimlari,
  useKasalar,
  useKisiler,
  type Secenek,
} from "@/components/finans/ortak";
import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Modal, Secim } from "@/components/ui";
import { agIstegi } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import {
  ALAN_TANIMLARI,
  baslangicDurumu,
  govdeyeCevir,
  type AlanTanimi,
} from "@/lib/rapor-alanlari";

export interface RaporKatalogOgesi {
  kod: string;
  baslik: string;
  aciklama: string;
  kategori: string;
  alanlar: string[];
  agir: boolean;
}

export interface RaporSutun {
  anahtar: string;
  baslik: string;
  tip?: string;
}
export interface RaporTablosu {
  kod: string;
  baslik: string;
  sutunlar: RaporSutun[];
  satirlar: Record<string, unknown>[];
  toplamlar: Record<string, unknown>;
  metin: string | null;
}

/** Bicim -> dosya UZANTISI. Ucluda dize yazmak (`"excel" ? "xlsx" : ...`)
 *  `sabit-metin` taramasini cevrilmemis metin sanip uyarmaya iterdi. */
const UZANTI: Record<string, string> = { excel: "xlsx", pdf: "pdf" };
const BICIM_TABLO = "tablo";
const BICIM_EXCEL = "excel";
const BICIM_PDF = "pdf";
const BOS = "";

/** Ay secenegi degerleri — etiket sozlukten gelir, deger 1..12. */
const GIRDI_TARIH = "date";
const GIRDI_SAYI = "number";
const GIRDI_METIN = "text";
const GIRDI_ONDALIK = "decimal";

const AYLAR = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

type Deger = string | boolean | string[];

export interface RaporModaliProps {
  rapor: RaporKatalogOgesi | null;
  kapat: () => void;
  /** "Goster" sonucu — sayfa tabloyu kendisi cizer. */
  onTablo: (tablo: RaporTablosu) => void;
  /** Bir is kuyruga alindi — sayfa is listesini tazeler. */
  onKuyruk: () => void;
}

export function RaporModali({ rapor, kapat, onTablo, onKuyruk }: RaporModaliProps) {
  const t = useT();
  const toast = useToast();
  const [durum, setDurum] = useState<Record<string, Deger>>({});
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  // Rapor DEGISINCE form sifirlanir: onceki raporun tarih araligini
  // yeni raporda tasimak, kullanicinin gormedigi bir suzgecle rapor
  // uretmesi demekti.
  useEffect(() => {
    setDurum(rapor ? baslangicDurumu(rapor.alanlar) : {});
    setHata(null);
  }, [rapor]);

  const kasalar = useKasalar();
  const firmalar = useFirmalar();
  const kisiler = useKisiler();
  const daireler = useDaireler();
  const tanimlar = useGelirGiderTanimlari();

  const kaynaklar = useMemo(
    () => ({ kasa: kasalar, firma: firmalar, kisi: kisiler, daire: daireler, tanim: tanimlar }),
    [kasalar, firmalar, kisiler, daireler, tanimlar],
  );

  function yaz(ad: string, deger: Deger): void {
    setDurum((o) => ({ ...o, [ad]: deger }));
  }

  async function calistir(bicim: string): Promise<void> {
    if (!rapor) return;
    setHata(null);
    setMesgul(true);
    const govde = JSON.stringify(govdeyeCevir(durum));
    const baslik = { "Content-Type": "application/json" };
    try {
      // ---- KUYRUK YOLU ----------------------------------------------- //
      if (bicim !== BICIM_TABLO && rapor.agir) {
        const res = await agIstegi(`/api/panel/rapor/${rapor.kod}/kuyruk?bicim=${bicim}`, {
          method: "POST",
          headers: baslik,
          body: govde,
        });
        if (res === null) return; // oturum bitti -> yonlendirildi
        const veri = await res.json().catch(() => null);
        if (!res.ok) throw new Error(veri?.error?.message ?? String(res.status));
        toast.success(t("raporKuyrugaAlindi"));
        onKuyruk();
        kapat();
        return;
      }

      const res = await agIstegi(`/api/panel/rapor/${rapor.kod}?bicim=${bicim}`, {
        method: "POST",
        headers: baslik,
        body: govde,
      });
      if (res === null) return;

      // ---- GOSTER ------------------------------------------------------ //
      if (bicim === BICIM_TABLO) {
        const veri = await res.json();
        if (!res.ok) throw new Error(veri?.error?.message ?? String(res.status));
        onTablo(veri as RaporTablosu);
        kapat();
        return;
      }

      // ---- DOGRUDAN INDIRME -------------------------------------------- //
      if (!res.ok) {
        const veri = await res.json().catch(() => null);
        throw new Error(veri?.error?.message ?? String(res.status));
      }
      // DOSYA ADI SUNUCUDAN: `Content-Disposition`i yeniden uydurmak,
      // indirilen dosyanin adiyla raporun adinin ayrismasi demekti.
      const cd = res.headers.get("content-disposition") ?? BOS;
      const eslesme = /filename="?([^";]+)"?/i.exec(cd);
      const ad = eslesme?.[1] ?? `${rapor.kod}.${UZANTI[bicim]}`;
      const url = URL.createObjectURL(await res.blob());
      const a = document.createElement("a");
      a.href = url;
      a.download = ad;
      a.click();
      URL.revokeObjectURL(url);
      toast.success(t("raporIndirildi"));
      kapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  /** Tek bir alani cizer. Sozlukte karsiligi yoksa `null` doner —
   *  `tests/rapor-alanlari.test.ts` bu durumu KIRMIZI yapar, cunku
   *  sessizce atlamak sunucunun sundugu bir suzgeci kullaniciya hic
   *  gostermemek olurdu. */
  function alanCiz(ad: string): JSX.Element | null {
    const tanim: AlanTanimi | undefined = ALAN_TANIMLARI[ad];
    if (!tanim) return null;
    const deger = durum[ad];

    if (tanim.tur === "onay") {
      return (
        <label
          key={ad}
          className="flex items-center gap-2 self-end pb-2"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
        >
          <input
            type="checkbox"
            checked={deger === true}
            onChange={(e) => yaz(ad, e.target.checked)}
          />
          {t(tanim.etiket)}
        </label>
      );
    }

    if (tanim.tur === "tanimCoklu") {
      const secili = Array.isArray(deger) ? deger : [];
      return (
        <AlanSarmal key={ad} etiket={t(tanim.etiket)}>
          {() => (
            // COKLU SECIM tek bir `<select multiple>`: brief'in "bes ayri
            // alan"i bir yerlesim tarifidir; bes ayri acilir liste, ayni
            // kalemin bes kez secilebilmesi demekti.
            <select
              multiple
              size={4}
              className="odak-ic w-full px-3 py-2 outline-none"
              style={{
                borderRadius: "var(--yz-radius-btn)",
                border: "var(--yz-border-w) solid var(--yz-border)",
                background: "var(--yz-metal-1)",
                color: "var(--yz-text)",
                fontSize: "var(--yz-fs-sm)",
              }}
              value={secili}
              onChange={(e) =>
                yaz(
                  ad,
                  Array.from(e.target.selectedOptions)
                    .map((o) => o.value)
                    .slice(0, 5),
                )
              }
            >
              {tanimlar.map((s: Secenek) => (
                <option key={s.id} value={s.id}>
                  {s.ad}
                </option>
              ))}
            </select>
          )}
        </AlanSarmal>
      );
    }

    const liste =
      tanim.tur === "kasa" || tanim.tur === "firma" || tanim.tur === "kisi" ||
      tanim.tur === "daire" || tanim.tur === "tanim"
        ? kaynaklar[tanim.tur]
        : null;

    if (liste !== null) {
      return (
        <AlanSarmal key={ad} etiket={t(tanim.etiket)}>
          {(b) => (
            <Secim
              {...b}
              value={typeof deger === "string" ? deger : BOS}
              onChange={(e) => yaz(ad, e.target.value)}
            >
              {/* BOS SECENEK "hepsi" demektir ve ILK sirada durur:
                  zorunlu olmayan bir suzgeci bosaltamamak, kullaniciyi
                  modali kapatip yeniden acmaya zorlardi. */}
              <option value={BOS}>{t("raporHepsi")}</option>
              {liste.map((s: Secenek) => (
                <option key={s.id} value={s.id}>
                  {s.ad}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
      );
    }

    if (tanim.tur === "secim") {
      return (
        <AlanSarmal key={ad} etiket={t(tanim.etiket)}>
          {(b) => (
            <Secim
              {...b}
              value={typeof deger === "string" ? deger : BOS}
              onChange={(e) => yaz(ad, e.target.value)}
            >
              <option value={BOS}>{t("raporHepsi")}</option>
              {(tanim.secenekler ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {t(s.etiket)}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
      );
    }

    if (tanim.tur === "ay") {
      return (
        <AlanSarmal key={ad} etiket={t(tanim.etiket)}>
          {(b) => (
            <Secim
              {...b}
              value={typeof deger === "string" ? deger : BOS}
              onChange={(e) => yaz(ad, e.target.value)}
            >
              <option value={BOS}>{t("raporHepsi")}</option>
              {AYLAR.map((a) => (
                <option key={a} value={String(a)}>
                  {String(a)}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
      );
    }

    const tip =
      tanim.tur === "tarih"
        ? GIRDI_TARIH
        : tanim.tur === "yil"
          ? GIRDI_SAYI
          : GIRDI_METIN;
    return (
      <AlanSarmal key={ad} etiket={t(tanim.etiket)}>
        {(b) => (
          <Alan
            {...b}
            type={tip}
            // KURUS alani metin girdisi: `number` girdisi virgullu yazimi
            // (Turkiye'de olagan olan "1250,50") tarayiciya gore ya
            // reddeder ya da sessizce bosaltir.
            inputMode={tanim.tur === "kurus" ? GIRDI_ONDALIK : undefined}
            value={typeof deger === "string" ? deger : BOS}
            onChange={(e) => yaz(ad, e.target.value)}
          />
        )}
      </AlanSarmal>
    );
  }

  return (
    <Modal
      acik={rapor !== null}
      onKapat={kapat}
      baslik={rapor?.baslik ?? BOS}
      genislikSinifi="max-w-3xl"
      eylemler={
        <div className="flex flex-wrap justify-end gap-2">
          <Dugme tur="sessiz" onClick={kapat}>
            {t("ortakIptal")}
          </Dugme>
          <Dugme disabled={mesgul} onClick={() => void calistir(BICIM_PDF)}>
            {t("raporPdf")}
          </Dugme>
          <Dugme disabled={mesgul} onClick={() => void calistir(BICIM_EXCEL)}>
            {t("raporExcel")}
          </Dugme>
          <Dugme tur="birincil" disabled={mesgul} onClick={() => void calistir(BICIM_TABLO)}>
            {t("raporGoster")}
          </Dugme>
        </div>
      }
    >
      <div className="space-y-3">
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {rapor?.aciklama}
        </p>
        {/* AGIR RAPOR UYARISI ONCEDEN: dosyanin neden hemen inmedigini
            sonradan aciklamak, kullanicinin "bir sey olmadi" diye ikinci
            kez tiklamasini engellemezdi. */}
        {rapor?.agir ? (
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("raporAgirUyari")}
          </p>
        ) : null}
        {hata ? <HataDurumu mesaj={hata} /> : null}
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {(rapor?.alanlar ?? []).map((ad) => alanCiz(ad))}
        </div>
      </div>
    </Modal>
  );
}
