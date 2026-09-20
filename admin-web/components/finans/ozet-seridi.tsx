"use client";

// (P244 §7) FINANS OZET SERIDI — `HareketSayfasi`nin ozet yuvasi icin.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Yedi finans sayfasi TEK bir kabugu paylasiyor (`HareketSayfasi`) ve o
// kabuk yalnizca BASLIK + TABLO ciziyordu. Sonuc: gider, gelir, tahsilat,
// borclandirma, virman, iade ve acilis ekranlari bastan sona AYNI
// gorunuyordu — referansta ise her birinin ustunde kendi sayilari var.
//
// ===========================================================================
// SAYILAR SUNUCUDAN, ISTEMCIDE HESAPLANMAZ
// ===========================================================================
// `/finans/ozet` ve `/finans/kasa-bakiyeleri` bu sayilari ZATEN veriyor ve
// `/finans` sayfasi onlari kullaniyor. Gorunen sayfadaki hareketlerden
// toplam almak iki yerde iki farkli rakam demekti — `/finans` sayfasinin
// dosya basinda yazili kurali bu.
//
// YENI UC ACILMADI: ikisi de beyaz listede ve SWR onbellegi paylasiliyor.
import useSWR from "swr";

import { OzetKarti, OzetSeridi } from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL } from "@/lib/money";

interface Ozet {
  borclandirilan_ay_kurus: number;
  tahsil_edilen_ay_kurus: number;
  acik_borc_kurus: number;
  kasa_toplam_kurus: number;
  icra_acik_dosya: number;
}
interface KasaOzet {
  genel_toplam_kurus: number;
  bekleyen_cikis_toplam_kurus: number;
}

/** Hangi sayfada hangi kartlar — karar BURADA, tek yerde. */
export type FinansOzetTuru = "tahsilat" | "gider" | "gelir" | "borclandirma";

export function FinansOzetSeridi({ tur }: { tur: FinansOzetTuru }) {
  const t = useT();
  const { data: ozet } = useSWR<Ozet>("/api/panel/finans-ozet", jsonFetcher);
  const { data: kasa } = useSWR<KasaOzet>(
    "/api/panel/kasa-bakiyeleri",
    jsonFetcher,
  );

  // VERI GELMEDEN SERIT CIZILMEZ: "₺0,00" gostermek, para olmadigini
  // SOYLEMEKTIR — oysa bilinen tek sey henuz okunmadigi.
  if (!ozet) return null;

  const kasaToplam = (
    <OzetKarti
      key="kasa"
      etiket={t("finansOzetKasa")}
      deger={kurusToTL(ozet.kasa_toplam_kurus)}
      durum="notr"
      altBilgi={
        kasa && kasa.bekleyen_cikis_toplam_kurus > 0
          ? t("finansOzetBekleyenCikis", {
              tutar: kurusToTL(kasa.bekleyen_cikis_toplam_kurus),
            })
          : undefined
      }
    />
  );

  const kartlar = {
    tahsilat: [
      <OzetKarti
        key="tahsil"
        etiket={t("finansOzetTahsilAy")}
        deger={kurusToTL(ozet.tahsil_edilen_ay_kurus)}
        durum="olumlu"
      />,
      <OzetKarti
        key="acik"
        etiket={t("finansOzetAcikBorc")}
        deger={kurusToTL(ozet.acik_borc_kurus)}
        // SIFIR BORC IYI HABERDIR; borc varsa UYARI — ama renk tek
        // tasiyici degil, etiket zaten "Açık borç" diyor.
        durum={ozet.acik_borc_kurus > 0 ? "uyari" : "olumlu"}
        href="/finans/borclular"
      />,
      kasaToplam,
    ],
    gider: [
      kasaToplam,
      <OzetKarti
        key="bekleyen"
        etiket={t("finansOzetOnayBekleyen")}
        deger={kurusToTL(kasa?.bekleyen_cikis_toplam_kurus ?? 0)}
        durum={
          (kasa?.bekleyen_cikis_toplam_kurus ?? 0) > 0 ? "uyari" : "olumlu"
        }
        altBilgi={t("finansOzetOnayBekleyenAlt")}
      />,
    ],
    gelir: [kasaToplam],
    borclandirma: [
      <OzetKarti
        key="borclandirilan"
        etiket={t("finansOzetBorclandirilanAy")}
        deger={kurusToTL(ozet.borclandirilan_ay_kurus)}
        durum="bilgi"
      />,
      <OzetKarti
        key="acik"
        etiket={t("finansOzetAcikBorc")}
        deger={kurusToTL(ozet.acik_borc_kurus)}
        durum={ozet.acik_borc_kurus > 0 ? "uyari" : "olumlu"}
        href="/finans/borclular"
      />,
    ],
  }[tur];

  return <OzetSeridi>{kartlar}</OzetSeridi>;
}
