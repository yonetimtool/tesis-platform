/**
 * Yönetio logosu — Nav header'daki ikon + kelime isareti.
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
 * KELIME ISARETI METIN OLARAK KALIYOR: banner gorselindeki yazi ile
 * uygulamanin her yerindeki urun adi AYNI DEGIL (bkz. P162 raporu). Bu
 * bir URUN KARARIDIR ve kod tarafinda tek tarafli degistirilmedi; banner
 * yalnizca giris ekraninda, brief'in istedigi yerde kullaniliyor.
 *
 * Favicon bu dosyadan GELMEZ: `app/icon.png` ayri, bagimsiz bir statik
 * dosyadir (Next onu kendisi bulup hash'li <link rel="icon"> enjekte eder).
 */

import Image from "next/image";

/** Ikon + kelime isareti. Kelime navy (acik) / beyaz (koyu) — .dark uzerinden. */
export function YonetioLogo({ size = 28 }: { size?: number }) {
  return (
    <span className="flex items-center gap-2">
      <Image
        src="/yonetio-logo.png"
        alt="Yönetio"
        width={size}
        height={size}
        priority
        className="shrink-0"
      />
      <span className="text-lg font-semibold tracking-tight text-[#0E3C91] dark:text-white">
        yönetio
      </span>
    </span>
  );
}
