"use client";

import { useId, useState } from "react";

import {
  DAIRE_ADIM,
  DAIRE_EN_AZ,
  DAIRE_EN_COK,
  DAIRE_VARSAYILAN,
  KDV_UYARISI,
  YILLIK_DAIRE_FIYATI_TL,
  sinirla,
  tutarBicimle,
  yillikTutar,
} from "@/config/fiyat";
import { TANITIM_UCRETSIZ } from "@/config/site";

/**
 * (P177 §3) FIYAT HESAPLAYICI.
 *
 * =========================================================================
 * IKI DENETIM, TEK DOGRULUK KAYNAGI
 * =========================================================================
 * Surgu ve sayisal kutu ayni `daire` durumunu yazar; ikisi de ondan
 * okur. Iki ayri durum tutulsaydi (yaygin hata) biri otekini gec
 * yakalar ve kullanici surgunun altinda farkli bir sayi gorurdu.
 *
 * =========================================================================
 * YAZARKEN SINIRLAMA YOK, DEGER SINIRLI
 * =========================================================================
 * Kutunun METNI ayri bir durumda (`ham`) tutuluyor. Sebebi olculebilir:
 * kullanici "50"yi silip "120" yazmak istediginde once alani bosaltir.
 * Metni dogrudan sayidan turetseydik, bos alan aninda "1"e sicrar ve
 * kullanici "1" ile "20"nin arasina yazmaya calisirdi.
 *
 * Yine de HESAP HER ZAMAN SINIRLI degerden yapilir: elle 9999 yazan
 * kullanici, surgunun uretemeyecegi bir tutar GORMEZ. Alan odagi
 * birakinca metin de sinirlanmis degere doner (`onBlur`).
 *
 * =========================================================================
 * ANLIK — SAYFA YENILEMESI YOK
 * =========================================================================
 * Form yok, gonderim yok. Hesap dogrudan `config/fiyat.ts`ten; fiyat
 * degisirse burasi degil ORASI degisir.
 */
export function FiyatHesaplayici() {
  const [daire, setDaire] = useState(DAIRE_VARSAYILAN);
  const [ham, setHam] = useState(String(DAIRE_VARSAYILAN));
  const surguId = useId();
  const kutuId = useId();

  function yaz(deger: string) {
    setHam(deger);
    const sayi = Number(deger);
    if (deger.trim() !== "" && Number.isFinite(sayi)) setDaire(sinirla(sayi));
  }

  function surguyeYaz(deger: string) {
    const sayi = sinirla(Number(deger));
    setDaire(sayi);
    setHam(String(sayi));
  }

  return (
    <div className="kart p-6 sm:p-8">
      <div className="grid gap-6 sm:grid-cols-[1fr_auto] sm:items-end">
        <div>
          <label className="alan-etiket" htmlFor={surguId}>
            Sitenizdeki daire sayısı
          </label>
          <input
            id={surguId}
            type="range"
            min={DAIRE_EN_AZ}
            max={DAIRE_EN_COK}
            step={DAIRE_ADIM}
            value={daire}
            onChange={(e) => surguyeYaz(e.target.value)}
            className="mt-2 w-full accent-mavi"
          />
          <p className="alan-yardim">
            {DAIRE_EN_AZ}–{DAIRE_EN_COK} daire arası
          </p>
        </div>

        <div className="sm:w-32">
          <label className="alan-etiket" htmlFor={kutuId}>
            Daire
          </label>
          <input
            id={kutuId}
            className="alan text-center text-[1.05rem] font-bold"
            type="number"
            inputMode="numeric"
            min={DAIRE_EN_AZ}
            max={DAIRE_EN_COK}
            step={DAIRE_ADIM}
            value={ham}
            onChange={(e) => yaz(e.target.value)}
            onBlur={() => setHam(String(daire))}
          />
        </div>
      </div>

      <hr className="my-7 border-cizgi" />

      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="etiket">Yıllık tutar</p>
          {/* `aria-live` YOK ve bilincli: deger surgu surukledikce her
              adimda degisiyor; canli bolge her adimi okuyup ekran
              okuyucuyu bogardi. Surgunun kendi degeri zaten duyurulur. */}
          <p className="mt-1.5 text-[clamp(2rem,5vw,3rem)] font-extrabold leading-none tracking-[-0.035em] text-lacivert">
            {tutarBicimle(yillikTutar(daire))}
          </p>
          <p className="mt-2 text-kucuk text-soluk">
            {sinirla(daire)} daire × {tutarBicimle(YILLIK_DAIRE_FIYATI_TL)} / yıl
          </p>
        </div>

        {TANITIM_UCRETSIZ ? (
          <p className="rounded-chip bg-yesilZemin px-4 py-2 text-kucuk font-bold text-yesil">
            Tanıtım döneminde ücretsiz
          </p>
        ) : null}
      </div>

      <p className="mt-5 text-kucuk font-semibold text-govde">{KDV_UYARISI}</p>
    </div>
  );
}
