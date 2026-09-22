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

/**
 * (P245) IKONLAR — serit alti finans ekraninda AYNI yerden gelsin.
 *
 * OLCULEN KUSUR: bu serit ikonsuz cizilirken `/finans`, `/dues` ve
 * guvenlik ekranlarindaki seritler ikonluydu. Ayni bilesen ailesi iki
 * farkli gorunumdeydi; referansta (ui2) her kartin solunda ikon var.
 */
const IKON_PARA =
  "M12 3v18M16 7.5C16 6 14.2 5 12 5S8 6 8 7.5 9.8 10 12 10s4 1 4 2.5S14.2 15 12 15s-4-1-4-2.5";
const IKON_BORC =
  "M12 9v4m0 4h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z";
const IKON_KASA = "M3 6h18v12H3zM3 10h18M7 14h4";
const IKON_FATURA = "M8 3h8a2 2 0 0 1 2 2v16l-3-2-3 2-3-2-3 2V5a2 2 0 0 1 2-2ZM9 8h6M9 12h6";
const IKON_SAAT = "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 7v5l3 2";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}
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
export type FinansOzetTuru =
  | "tahsilat"
  | "gider"
  | "gelir"
  | "borclandirma"
  // (P245) VIRMAN / IADE / ACILIS — TEK KART, ve bu bilincli.
  //
  // Referansta (ui2) bu uc ekranin ustunde de sayi serisi var; ornegin
  // odeme iadesinde "12 Bekleyen / 8 Onaylanan / 3 Reddedilen". BIZDE
  // O DURUMLAR YOK: uc de TEK DEFTERE (P192) yazilan hareket tipleri ve
  // iade icin bir onay akisi tanimli degil. Uc sayi uydurmak yerine,
  // ucunun de GERCEKTEN yanitladigi soru gosteriliyor:
  //   virman — para kasalar arasinda tasinir, TOPLAM DEGISMEMELI
  //   acilis — acilis fisleri toplami DOGRUDAN kurar
  //   iade   — iade kasadan CIKAR
  // Yani kasa toplami bu uc ekranda da islemin sonucudur.
  | "kasa";

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
      ikon={<Ikon yol={IKON_KASA} />}
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
        ikon={<Ikon yol={IKON_PARA} />}
      />,
      <OzetKarti
        key="acik"
        etiket={t("finansOzetAcikBorc")}
        ikon={<Ikon yol={IKON_BORC} />}
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
        ikon={<Ikon yol={IKON_SAAT} />}
        durum={
          (kasa?.bekleyen_cikis_toplam_kurus ?? 0) > 0 ? "uyari" : "olumlu"
        }
        altBilgi={t("finansOzetOnayBekleyenAlt")}
      />,
    ],
    gelir: [kasaToplam],
    kasa: [kasaToplam],
    borclandirma: [
      <OzetKarti
        key="borclandirilan"
        etiket={t("finansOzetBorclandirilanAy")}
        deger={kurusToTL(ozet.borclandirilan_ay_kurus)}
        durum="bilgi"
        ikon={<Ikon yol={IKON_FATURA} />}
      />,
      <OzetKarti
        key="acik"
        etiket={t("finansOzetAcikBorc")}
        ikon={<Ikon yol={IKON_BORC} />}
        deger={kurusToTL(ozet.acik_borc_kurus)}
        durum={ozet.acik_borc_kurus > 0 ? "uyari" : "olumlu"}
        href="/finans/borclular"
      />,
    ],
  }[tur];

  return <OzetSeridi>{kartlar}</OzetSeridi>;
}
