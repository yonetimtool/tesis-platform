"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { btnGhost } from "@/components/form";
import { DONUS_PARAM, gecerliDonus } from "@/lib/bagimliliklar";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 7.4) "ISIN BITINCE GERI DON" seridi.
 *
 * Brief'in ucuncu sarti: "...islem bitince geri donus."
 *
 * NEDEN KORUMALI DUZENDE, HER SAYFADA AYRI DEGIL: bagimlilik uyarisi
 * dokuz farkli hedefe yollayabiliyor ve o hedeflerin her birine bir "geri
 * don" dugmesi koymak ayni davranisi dokuz kez yazmak olurdu. Serit
 * duzende TEK KEZ cizilir; `?donus=` tasiyan HER sayfada kendiliginden
 * gorunur, tasimayan hicbir sayfada gorunmez.
 *
 * NEDEN `history.back()` DEGIL: kullanici hedef ekranda birkac adim
 * gezinir (defter sekmesi degistirir, modal acar, kaydeder). `back()` onu
 * isini bitirdigi yere DEGIL bir onceki karesine gonderirdi. Adres
 * sorguda tasindigi icin bu gezinmelerden ETKILENMEZ.
 *
 * ADRES DOGRULANIR (`gecerliDonus`): `?donus=https://baska-site` yazan
 * biri panelden disari yonlendiren bir dugme uretebilirdi. Yalniz
 * uygulama ici yollar kabul edilir.
 */
export function DonusCubugu() {
  const t = useT();
  const sorgu = useSearchParams();
  const hedef = gecerliDonus(sorgu?.get(DONUS_PARAM) ?? null);

  if (!hedef) return null;

  return (
    <div
      role="status"
      className="mb-3 flex flex-wrap items-center justify-between gap-3 rounded-kart border border-accent-blue/30 bg-accent-blue/10 p-3"
    >
      <p className="min-w-0 text-sm text-metin-body">{t("donusAciklama")}</p>
      <Link href={hedef} className={`${btnGhost} shrink-0`}>
        {t("donusDugme")}
      </Link>
    </div>
  );
}
