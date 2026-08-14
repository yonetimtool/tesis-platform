"use client";

/**
 * (P160 / Asama 3) TARIH ARALIGI.
 *
 * =========================================================================
 * NEDEN OZEL BIR TAKVIM YAZILMADI
 * =========================================================================
 * Brief bir "DatePicker" istiyor. Depoda tarih girisi bugun `<input
 * type="date">` ile yapiliyor ve bu SECIM DOGRU: tarayicinin kendi
 * takvimi kullanicinin diline/takvimine gore acilir, klavyeyle gezilir,
 * ekran okuyucu tanir ve mobilde yerel secici cikar. Elle yazilan bir
 * takvim bunlarin hepsini YENIDEN uretmek zorundadir ve genelde eksik
 * uretir.
 *
 * EKSIK OLAN SEY TAKVIM DEGIL, ARALIKTI: rapor ekranlarinin hepsinde
 * "baslangic" ve "bitis" YAN YANA iki ayri alan olarak duruyor ve
 * HICBIRI ikisinin tutarli olup olmadigina bakmiyor. Bitisi baslangictan
 * once secen kullanici BOS bir rapor aliyor ve sebebini goremiyordu —
 * "kayit yok" diyen bir ekran, aslinda "aralik ters" diyor olmaliydi.
 *
 * Bu bilesen o boslugu kapatir: iki yerel alan + TEK bir tutarlilik
 * kurali.
 */
import { useT } from "@/lib/i18n/kullan";

import { Alan, AlanSarmal } from "./alan";

export type AralikTipi = "date" | "datetime-local";

export function TarihAraligi({
  baslangic,
  bitis,
  onBaslangic,
  onBitis,
  tip = "date",
  ipucu,
}: {
  baslangic: string;
  bitis: string;
  onBaslangic: (v: string) => void;
  onBitis: (v: string) => void;
  tip?: AralikTipi;
  ipucu?: string;
}) {
  const t = useT();
  // Dize karsilastirmasi YETERLI: hem `YYYY-MM-DD` hem
  // `YYYY-MM-DDTHH:mm` sozluk sirasinda kronolojiktir. `Date` kurmak
  // saat dilimi cevirisi getirirdi ve alanlar YEREL saattir.
  const ters = baslangic !== "" && bitis !== "" && bitis < baslangic;

  return (
    <div className="flex flex-wrap items-start gap-3">
      <div className="w-full sm:w-52">
        <AlanSarmal etiket={t("ortakBaslangic")} ipucu={ipucu}>
          {(b) => (
            <Alan
              {...b}
              type={tip}
              value={baslangic}
              onChange={(e) => onBaslangic(e.target.value)}
            />
          )}
        </AlanSarmal>
      </div>
      <div className="w-full sm:w-52">
        {/* HATA `AlanSarmal`A VERILIYOR, elle bir kutu cizilmiyor:
            sarmalayici zaten `aria-invalid` + `aria-describedby` +
            `role="alert"` ucunu birlikte kuruyor. Ikinci bir mekanizma
            yazmak, ayni isi iki yerde ve biri eksik yapmakti. */}
        <AlanSarmal
          etiket={t("ortakBitis")}
          ipucu={ipucu}
          hata={ters ? t("tarihAraligiTers") : undefined}
        >
          {(b) => (
            <Alan
              {...b}
              type={tip}
              value={bitis}
              onChange={(e) => onBitis(e.target.value)}
            />
          )}
        </AlanSarmal>
      </div>
    </div>
  );
}

/** Aralik tutarli mi — cagiran "Getir" dugmesini buna gore kapatir. */
export function aralikGecerli(baslangic: string, bitis: string): boolean {
  if (!baslangic || !bitis) return true;
  return bitis >= baslangic;
}
