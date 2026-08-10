"use client";

import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";

import { btnPrimary } from "@/components/form";
import {
  BAGIMLILIKLAR,
  hedefBaglantisi,
  type BagimlilikKodu,
} from "@/lib/bagimliliklar";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 7.4) BAGIMLILIK UYARISI — TEK bilesen, tum ekranlar.
 *
 * Brief: "Bir sey eklemek icin baska bir yerde tanimlama gerekiyorsa:
 * uyari cumlesi + ILGILI ALANA YONLENDIRME dugmesi, islem bitince geri
 * donus. TEK bilesen olarak kur, tum ekranlarda kullan."
 *
 * BUGUN NE OLUYOR (olculdu, `docs/envanter.md` §0.4): kullanici ya BOS
 * BIR ACILIR LISTE goruyor ya da anlamadigi bir **422** aliyor. Ikisi de
 * "eksik olan ne" ve "nereye gitmeliyim" sorularini YANITLAMIYOR.
 *
 * `eksik` KARARI CAGIRANDA, BURADA DEGIL: ekranlarin cogu bagli oldugu
 * listeyi ZATEN cekiyor (kasa listesi, kategori listesi...). Bilesen
 * kendi sorgusunu atsaydi ayni veriyi ikinci kez indirirdi. Bilesen
 * `eksik=false` iken HICBIR SEY cizmez — cagri yerinde `{... && <.../>}`
 * yazmak zorunda kalmamak icin.
 *
 * DONUS ADRESI BURADA URETILIR: kullanicinin BULUNDUGU yol + sorgu,
 * hedefe `?donus=` olarak eklenir. `DonusCubugu` (korumali duzende, TEK
 * yerde) onu okur ve geri donus seridini cizer. Her ekrana ayri bir "geri
 * don" dugmesi koymak, ayni davranisi onlarca yerde tekrar etmek olurdu.
 */
export function BagimlilikUyarisi({
  kod,
  eksik,
}: {
  kod: BagimlilikKodu;
  eksik: boolean;
}) {
  const t = useT();
  const pathname = usePathname();
  const sorgu = useSearchParams();

  if (!eksik) return null;

  const b = BAGIMLILIKLAR[kod];
  const suAn = sorgu?.toString() ? `${pathname}?${sorgu}` : pathname;

  return (
    // `role="status"`: bu bir HATA DEGIL, bir YONLENDIRME. `alert` olsaydi
    // ekran okuyucu kullanicinin isini keserdi; oysa mesaj "once sunu yap"
    // diyor, "bir sey bozuldu" demiyor.
    <div
      role="status"
      className="flex flex-wrap items-center justify-between gap-3 rounded-kart border border-accent-orange/30 bg-accent-orange/10 p-3"
    >
      <p className="min-w-0 text-sm text-metin-body">{t(b.mesaj)}</p>
      <Link
        href={hedefBaglantisi(b, suAn)}
        className={`${btnPrimary} shrink-0`}
      >
        {t(b.eylem)}
      </Link>
    </div>
  );
}
