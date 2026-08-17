"use client";

// (P167 Asama 4) SATIR TABANLI GIRIS — brief'in "Yeni Satır" akisi.
//
// Brief §4.2/§4.3/§4.4 ucu de AYNI seyi tarif ediyor: modal icinde bir
// tablo, her satir bir kayit, altta "+ Yeni Satır", her satirin sonunda
// cop kutusu, en altta "Toplam Kayit: N" ve "Toplam Tutar: X".
//
// UC KEZ YAZILMADI: satir ekleme/silme, toplam hesabi, bos satir
// dogrulamasi ve klavye erisimi ucunde de ayni. Kopyalasaydik biri
// duzeltildiginde otekiler unutulurdu — ve toplamin YANLIS oldugu bir
// ekran, kullanicinin fark etmesi en zor kusurdur.
//
// =====================================================================
// TOPLAM ISTEMCIDE HESAPLANIR VE BU BIR ISTISNA
// =====================================================================
// Depo kurali: "bakiye saklanmaz, defterden turetilir" — istemcide
// toplam almak iki yerde iki farkli rakam demektir. BURADA GECERLI
// DEGIL, cunku bu satirlar HENUZ DEFTERDE YOK: kullanicinin o an yazdigi,
// kaydedilmemis girdilerdir. Toplami gostermemek ise brief'in acik
// sarti disinda, kullaniciyi 30 satiri elle toplamaya birakmak olurdu.
// Kaydedildikten SONRA gosterilen her rakam yine sunucudan gelir.

import { useId, type ReactNode } from "react";

import { Dugme } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";

/** Her satirin tasidigi ortak alanlar; sayfalar kendi alanlarini ekler. */
export interface SatirTabani {
  /** Yalniz cizim icin KARARLI anahtar — sunucuya GITMEZ. */
  _k: string;
  tutar: string;
}

/** Yeni satir kimligi. `crypto.randomUUID` her tarayicida yok (eski
 *  Safari); sayac + zaman yeterince kararli ve yalniz `key` icin. */
let _sayac = 0;
export function yeniSatirAnahtari(): string {
  _sayac += 1;
  return `s${_sayac}`;
}

export function SatirTablosu<T extends SatirTabani>({
  satirlar,
  onDegisti,
  bosSatir,
  basliklar,
  hucreler,
}: {
  satirlar: T[];
  onDegisti: (yeni: T[]) => void;
  /** Yeni satirin baslangic degeri. */
  bosSatir: () => T;
  /** Kolon basliklari (tutar ve sil BURADA cizilir, verilmez). */
  basliklar: string[];
  /** Satira ozel hucreler — tutar ve sil hucresi HARIC. */
  hucreler: (satir: T, guncelle: (yama: Partial<T>) => void) => ReactNode[];
}) {
  const t = useT();
  const tabloId = useId();

  function guncelle(k: string, yama: Partial<T>) {
    onDegisti(satirlar.map((s) => (s._k === k ? { ...s, ...yama } : s)));
  }

  /**
   * Tutar hucresi.
   *
   * `guncelle`den AYRI ve tur donusumu YOK: yayilma (`...s`) zaten `T`yi
   * koruyor, yani `as Partial<T>` gereksizdi. Donusumu kaldirmak ayni
   * zamanda `sabit-metin` taramasini da rahatlatti — o tarama ucludeki
   * her tanimlayiciyi cevrilmemis metin adayi sayiyor ve genelde HAKLI;
   * gereksiz bir donusum icin kilidi gevsetmek yanlis takas olurdu.
   */
  function tutarYaz(k: string, deger: string) {
    onDegisti(satirlar.map((s) => (s._k === k ? { ...s, tutar: deger } : s)));
  }

  function sil(k: string) {
    // SON SATIR SILINEBILIR ve yerine bos bir satir gelir: tablo tamamen
    // bosalirsa kullanici "+ Yeni Satır"i bulmak zorunda kalirdi ve
    // ekranda yapacak bir sey gormezdi.
    const kalan = satirlar.filter((s) => s._k !== k);
    onDegisti(kalan.length ? kalan : [bosSatir()]);
  }

  const toplamKurus = satirlar.reduce(
    (n, s) => n + (tlToKurus(s.tutar) ?? 0),
    0,
  );

  return (
    <div className="space-y-2">
      <div className="overflow-x-auto" role="region" tabIndex={0} aria-labelledby={tabloId}>
        <table className="w-full min-w-[40rem] border-collapse">
          <caption id={tabloId} className="sr-only">
            {t("finansYeniSatir")}
          </caption>
          <thead>
            <tr>
              {[...basliklar, t("finansAlanTutar"), ""].map((b, i) => (
                <th
                  key={i}
                  scope="col"
                  className="px-1 pb-1 text-start"
                  style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                >
                  {b}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {satirlar.map((s) => (
              <tr key={s._k}>
                {hucreler(s, (yama) => guncelle(s._k, yama)).map((h, i) => (
                  <td key={i} className="p-1 align-top">
                    {h}
                  </td>
                ))}
                <td className="p-1 align-top">
                  <input
                    value={s.tutar}
                    onChange={(e) => tutarYaz(s._k, e.target.value)}
                    inputMode="decimal"
                    aria-label={t("finansAlanTutar")}
                    className="odak-ic h-10 w-28 px-2 text-end tabular-nums outline-none"
                    style={{
                      borderRadius: "var(--yz-radius-btn)",
                      borderWidth: "var(--yz-border-w)",
                      borderStyle: "solid",
                      borderColor: "var(--yz-border)",
                      background: "var(--yz-surface-1)",
                      color: "var(--yz-text)",
                    }}
                  />
                </td>
                <td className="p-1 align-top">
                  <button
                    type="button"
                    onClick={() => sil(s._k)}
                    aria-label={t("finansSatirSil")}
                    title={t("finansSatirSil")}
                    className="odak-ic flex h-10 w-10 items-center justify-center rounded-lg"
                    style={{ color: "var(--yz-danger-ink)" }}
                  >
                    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true"
                      fill="none" stroke="currentColor" strokeWidth="1.75"
                      strokeLinecap="round" strokeLinejoin="round">
                      <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13M10 11v6M14 11v6" />
                    </svg>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-2">
        <Dugme
          tur="ikincil"
          boy="kucuk"
          onClick={() => onDegisti([...satirlar, bosSatir()])}
        >
          {t("finansYeniSatir")}
        </Dugme>
        <span
          className="flex flex-wrap gap-4"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
        >
          <span>{t("finansToplamKayit", { n: satirlar.length })}</span>
          <span className="tabular-nums">
            {t("finansToplamTutar", { tutar: kurusToTL(toplamKurus) })}
          </span>
        </span>
      </div>
    </div>
  );
}
