"use client";

/**
 * (P251 §8) DEVRIYE — TEK SAYFA, UC SEKME: Takip · NFC noktalari · Planlar.
 *
 * Uc ayri menu satiriydi (NFC noktalari, Devriye planlari) ve takip
 * raporu (`/reports/patrols`) menude hic yoktu. Mobilde ise ucu tek
 * ekrandaydi (Devriye takibi + iki etiketli giris). Ayni is, ayni yer:
 * iki yuzeyde de "Devriye".
 *
 * SEKME ADRESTE: eski adresler dogru sekmeyi acar (`?sekme=noktalar`).
 */
import { usePathname, useRouter } from "next/navigation";

import Noktalar from "@/components/devriye/noktalar";
import Planlar from "@/components/devriye/planlar";
import Takip from "@/components/devriye/takip";
import { GomuluSayfa, SayfaBasligi, Sekmeler } from "@/components/ui";
import { DEVRIYE_SEKMELERI, type DevriyeSekmesi } from "@/lib/devriye-sekmeleri";
import { useT } from "@/lib/i18n/kullan";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

const DEVRIYE_YOLU = "/devriye";

export default function DevriyePage() {
  const t = useT();
  const router = useRouter();
  const yol = usePathname();
  const [sekme, setSekme] = useSorguSecimi<DevriyeSekmesi>("sekme", DEVRIYE_SEKMELERI, "takip");

  function degis(id: string) {
    setSekme(id as DevriyeSekmesi);
    router.replace(`${yol ?? DEVRIYE_YOLU}?sekme=${id}`, { scroll: false });
  }

  return (
    <div>
      <SayfaBasligi baslik={t("kabukDevriye")} aciklama={t("devriyeAlt")} />
      <Sekmeler
        aktifId={sekme}
        onDegis={degis}
        sekmeler={[
          { id: "takip", baslik: t("devriyeSekmeTakip"), icerik: <GomuluSayfa><Takip /></GomuluSayfa> },
          { id: "noktalar", baslik: t("devriyeSekmeNoktalar"), icerik: <GomuluSayfa><Noktalar /></GomuluSayfa> },
          { id: "planlar", baslik: t("devriyeSekmePlanlar"), icerik: <GomuluSayfa><Planlar /></GomuluSayfa> },
        ]}
      />
    </div>
  );
}
