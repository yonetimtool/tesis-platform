"use client";

// (P167 §4.3) GIDERLERIM — ayri sayfa, satir tabanli giris.
//
// Sayfa INCE: liste kabugu `HareketSayfasi`da, form `HareketModali`nda.
// Burada kalan tek sey SAYFAYA OZEL karar — hangi tip, hangi ek sutun,
// hangi rapor kodu.

import { useState } from "react";

import { Dugme } from "@/components/ui";
import { HareketModali } from "@/components/finans/hareket-modali";
import { HareketSayfasi } from "@/components/finans/hareket-sayfasi";
import { useT } from "@/lib/i18n/kullan";

const TIP = "gider";

export default function GiderlerPage() {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const [yenile, setYenile] = useState(0);

  return (
    <HareketSayfasi
      baslikAnahtari="kabukGiderler"
      tip={TIP}
      raporKodu="finansal_hareketler"
      yenile={yenile}
      araclar={
        <Dugme tur="birincil" boy="kucuk" onClick={() => setAcik(true)}>
          {t("finansYeni")}
        </Dugme>
      }
      cocuk={
        <HareketModali
          acik={acik}
          tip={TIP}
          baslikAnahtari="kabukGiderler"
          onKapat={() => setAcik(false)}
          onKaydedildi={() => setYenile((n) => n + 1)}
        />
      }
    />
  );
}
