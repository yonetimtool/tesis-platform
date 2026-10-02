"use client";

/**
 * (P251 §8) MAAS KARTLARI — Finans grubunda.
 *
 * Eskiden Tanimlar › "Personel" adiyla duruyordu ve iki kusuru vardi:
 *  1. AD: mobilde "Personel" saha personeli HESABI demekti; ayni kelime
 *     iki ayri kaydi gosteriyordu.
 *  2. YER: kart bir giderin (maas, fazla mesai) tanimidir; Finans'in
 *     yaninda aranir.
 *
 * Defterin tanimi (alanlar, form, dogrulama) `components/tanimlar`ta tek
 * yerde kalir; bu sayfa onu cizer. Kart bir uygulama hesabina BAGLANIR
 * (istege bagli) ve fazla mesai ucreti bu bagdan okunur.
 */
import { useSearchParams } from "next/navigation";

import { MAAS_KARTI_DEFTERI, MenudeOlmayanDefter } from "@/components/tanimlar/tanimlar";
import { SayfaBasligi } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";

export default function MaasKartlariPage() {
  const t = useT();
  const kart = useSearchParams()?.get("kart") ?? null;
  return (
    <div>
      <SayfaBasligi baslik={t("finansMaasKartlari")} aciklama={t("maasKartiSayfaAlt")} />
      <MenudeOlmayanDefter kaynak={MAAS_KARTI_DEFTERI} acilacakId={kart} />
    </div>
  );
}
