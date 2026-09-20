"use client";

// (P244 §2) TESIS DEGISTIRME — PAYLASILAN MANTIK.
//
// `KullaniciMenusu` icinde yaziliydi; site karti kenar cubugunun dibine
// tasininca ayni mantigin IKINCI bir kopyasi gerekecekti. Kopya yerine
// kanca: cizim iki yerde olabilir, KARAR tek yerde kalir.

import { useState } from "react";

import { useT } from "@/lib/i18n/kullan";

/** Bir kisinin TEK bir tesisteki uyeligi. */
export type TesisUyeligi = {
  tenant_id: string;
  slug: string;
  ad: string;
  rol: string;
};

export function useTesisGecis() {
  const t = useT();
  const [bekliyor, setBekliyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  /**
   * (P203 §2) Tesis degistir.
   *
   * BASARIDA TAM SAYFA YENILEME (`location.assign`), `router.replace`
   * DEGIL: jeton degisti ve rol degismis OLABILIR. Next'in istemci
   * onbellegi eski tesisin verisini ve eski role gore cizilmis kabugu
   * tutuyor; yumusak gecis, YENI tesiste ESKI menuyu gostermek olurdu.
   * Kok (`/`) hedeflenir — middleware yeni role gore dogru baslangici
   * secer (sakin Aidatim'a, yonetici Pano'ya).
   */
  async function gec(tenantId: string) {
    setBekliyor(true);
    setHata(null);
    try {
      const r = await fetch("/api/me/tesis-degistir", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tenant_id: tenantId }),
      });
      if (!r.ok) {
        const d = (await r.json().catch(() => null)) as
          | { error?: { message?: string } }
          | null;
        setHata(d?.error?.message ?? t("ortakHataOlustu"));
        return;
      }
      window.location.assign("/");
    } catch {
      setHata(t("ortakSunucuyaUlasilamadi"));
    } finally {
      setBekliyor(false);
    }
  }

  return { gec, bekliyor, hata };
}
