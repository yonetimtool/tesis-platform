"use client";

import { useSearchParams } from "next/navigation";

import { DugmeBaglantisi } from "@/components/ui";
import { DONUS_PARAM, gecerliDonus } from "@/lib/bagimliliklar";
import { useT } from "@/lib/i18n/kullan";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const BOY_KUCUK = "kucuk" as const;

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
      <p className="min-w-0 text-sm" style={{ color: "var(--yz-text)" }}>
        {t("donusAciklama")}
      </p>
      <DugmeBaglantisi href={hedef} boy={BOY_KUCUK} className="shrink-0">
        {t("donusDugme")}
      </DugmeBaglantisi>
    </div>
  );
}
