/**
 * Yönetiyor logosu — Nav header'daki ikon + kelime isareti.
 *
 * =========================================================================
 * (P162) YENI MARKA ISARETI
 * =========================================================================
 * Isaret `docs/design-refs/yonetiyor_logo.png` ile degistirildi (altigen
 * cerceve + insanlar + govde). Eski `yonetio-master.png` KALDIRILDI;
 * "eski logoyu birakma" brief'in acik istegi.
 *
 * Varlik hazirligi `tools/png-arac.py` ile yapildi: ham dosyanin beyaz
 * zemini saydamlastirildi ve kenar paylari kirpildi. Ayni kaynak
 * favicon'a (`app/icon.png`), Apple ikonuna ve mobil master'a da isledi —
 * yani tek kaynak, dort cikti.
 *
 * Favicon bu dosyadan GELMEZ: `app/icon.png` ayri, bagimsiz bir statik
 * dosyadir (Next onu kendisi bulup hash'li <link rel="icon"> enjekte eder).
 *
 * =========================================================================
 * (P166 §6.2) KOYU TEMADA GORUNURLUK — AYRI VARYANT
 * =========================================================================
 * OLCULDU: `yonetio-logo.png`in opak piksellerinin ORTALAMASI RGB
 * (27, 65, 124) — koyu lacivert. Koyu temanin zemini de koyu; isaret
 * pratikte zeminde KAYBOLUYORDU. Kelime isareti (`dark:text-white`)
 * gorunuyor, ISARET gorunmuyordu — yani logo yarim cikiyordu.
 *
 * COZUM VARDI AMA BAGLI DEGILDI: `yonetio-logo-acik.png` (ters/reverse
 * varyant, ortalama RGB (190, 201, 218)) depoda P162'den beri duruyor ve
 * HICBIR YERDE kullanilmiyordu. Yeni bir varlik uretmek yerine o baglandi.
 *
 * IKISI DE CIZILIR, BIRI GIZLENIR (`dark:` sinifi). Neden JavaScript'le
 * tema okuyup TEK gorsel cizmedik: tema `.dark` sinifiyla SUNUCUDA
 * belirlenmis oluyor; istemcide okumak ilk karede YANLIS logoyu gosterir
 * ve kullanici bir "sicrama" gorurdu. Ikinci gorsel ~26 kB ve `priority`
 * degil — ilk boyayi gecikmez.
 *
 * BUYUDU: varsayilan 28 -> 34. Brief: "logo daha buyuk ve gorunur olsun".
 */

import Image from "next/image";

/** Ikon + kelime isareti. Kelime navy (acik) / beyaz (koyu) — .dark uzerinden. */
export function YonetioLogo({ size = 34 }: { size?: number }) {
  return (
    <span className="flex items-center gap-2">
      {/* ACIK TEMA: koyu lacivert isaret. */}
      <Image
        src="/yonetio-logo.png"
        alt="Yönetiyor"
        width={size}
        height={size}
        priority
        className="shrink-0 dark:hidden"
      />
      {/* KOYU TEMA: ters (acik murekkep) varyant. `alt` BOS ve
          `aria-hidden`: ayni logonun ikinci kopyasi, ekran okuyucuya iki
          kez "Yönetiyor" demek olurdu. */}
      <Image
        src="/yonetio-logo-acik.png"
        alt=""
        aria-hidden="true"
        width={size}
        height={size}
        className="hidden shrink-0 dark:block"
      />
      <span className="text-xl font-semibold tracking-tight text-[#0E3C91] dark:text-white">
        yönetiyor
      </span>
    </span>
  );
}
