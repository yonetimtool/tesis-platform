import type { Metadata } from "next";

import { HukukiBelge } from "@/components/HukukiBelge";
import { CEREZ_BOLUMLERI, CEREZ_EKSIK_NOTU, KVKK_AYDINLATMA } from "@/lib/hukuki";

export const metadata: Metadata = {
  title: "Çerez Politikası — Yönetiyor",
  description:
    "Yönetiyor’da hangi çerezlerin kullanıldığı ve kullanılmadığı.",
};

/**
 * Musteakil bir cerez politikasi belgesi HENUZ YOK (bkz. lib/hukuki.ts).
 * Sayfa var olan bolumu gosterir ve eksikligi ACIKCA soyler; metin
 * uydurulmaz.
 */
export default function Sayfa() {
  return (
    <HukukiBelge
      baslik="Çerez Politikası"
      guncelleme={KVKK_AYDINLATMA.guncelleme}
      not={CEREZ_EKSIK_NOTU}
      bolumler={CEREZ_BOLUMLERI}
    />
  );
}
