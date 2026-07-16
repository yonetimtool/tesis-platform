/**
 * Yönetio logosu — Nav header'daki ikon + kelime isareti.
 *
 * TAM MASTER kullanilir (mavi→teal gradyan zemin + uc bina + insanlar + yay),
 * basitlestirilmis turev DEGIL. Mobil app-bar'i da tam master'a gecti
 * (94f488e); panel geride kalmisti — iki yuzey artik AYNI isareti gosteriyor,
 * marka tek gorunum.
 *
 * Asset: `public/yonetio-master.png` = mobildeki
 * `mobile/assets/branding/icon_master.png` ile ayni dosya. Master degisirse
 * IKISI birden guncellenmeli.
 *
 * Favicon bu dosyadan GELMEZ: `app/icon.svg` ayri, bagimsiz bir statik dosyadir
 * (Next onu kendisi bulup hash'li <link rel="icon"> enjekte eder).
 */

import Image from "next/image";

/** Ikon + kelime isareti. Kelime navy (acik) / beyaz (koyu) — .dark uzerinden. */
export function YonetioLogo({ size = 28 }: { size?: number }) {
  return (
    <span className="flex items-center gap-2">
      <Image
        src="/yonetio-master.png"
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
