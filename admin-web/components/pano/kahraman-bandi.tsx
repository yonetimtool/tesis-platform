"use client";

// (P244 §5) KAHRAMAN BANDI — ozet sayfasinin karsilama satiri.
//
// ===========================================================================
// NEDEN VAR
// ===========================================================================
// Referansta (`ui5.png`) sayfanin ustunde fotografli bir bant duruyor:
// "Günaydın, Furkan" + site adi + tarih + hava. Bizde sayfa dogrudan
// baslikla basliyordu.
//
// Bu yalnizca sus degil: bant UC soruyu birden yanitliyor — kimim, hangi
// sitedeyim, bugun ne gun. Ucu de bugun ayri ayri aranmasi gereken
// bilgilerdi (ad hesap menusunde, site adi kenar cubugunda, tarih hicbir
// yerde).
//
// ===========================================================================
// NEDEN BIR "BOLUM" DEGIL
// ===========================================================================
// Ozet sayfasinin bolumleri gizlenebilir ve siralanabilir (P167 §2.5).
// Bant bunlardan biri DEGIL: sayfa BASLIGIN karsiligi. Gizlenebilir bir
// karsilama satiri, "bu sayfa neresi" sorusunu gizlenebilir yapardi.
//
// ===========================================================================
// FOTOGRAF YOK — VE BU BILINCLI
// ===========================================================================
// Referansta bandin zemini site fotografi. Bizde tesisin fotografi diye
// bir alan YOK (ne `tenant` semasinda ne bir yuklemede). Uydurma bir stok
// gorsel koymak, urunu gercek olmayan bir seyle sushemekti — P244'un
// kacindigi "mockup" tam olarak bu. Zemin yerine marka gradyani
// kullaniliyor; tesis gorseli bir gun eklenirse bant onu tasir.
import useSWR from "swr";

import { jsonFetcher } from "@/lib/fetcher";
import { useI18n } from "@/lib/i18n/kullan";
import type { HavaDurumu } from "@/lib/types";

type Kimlik = { ad?: string };
type TesisAyari = { ad?: string };

/** Hava durumu kimligi -> sozluk anahtari (metin cizimde cozulur). */
const HAVA_ANAHTARI = {
  acik: "havaAcik",
  parcali: "havaParcali",
  kapali: "havaKapali",
  sis: "havaSis",
  yagmur: "havaYagmur",
  kar: "havaKar",
  firtina: "havaFirtina",
} as const;

/**
 * Saate gore selamlama.
 *
 * ESIKLER TURKCE KONUSMA ALISKANLIGINA GORE: sabah 05-11, gunaydin
 * degil "iyi gunler" 11-18, aksam 18-22, gece 22-05. Ingilizce'deki
 * "good afternoon" karsiligi Turkce'de gunluk kullanimda yok; dort
 * kademe yerine bu dordu secildi ve her dil kendi anahtarini cevirir.
 */
function selamAnahtari(saat: number) {
  if (saat >= 5 && saat < 11) return "panoSelamSabah" as const;
  if (saat >= 11 && saat < 18) return "panoSelamGunduz" as const;
  if (saat >= 18 && saat < 22) return "panoSelamAksam" as const;
  return "panoSelamGece" as const;
}

function TakvimIkonu() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
      <rect x="3.5" y="5" width="17" height="16" rx="2" />
      <path d="M3.5 10h17M8 3v4M16 3v4" />
    </svg>
  );
}

function HavaIkonu() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor"
      strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6L17 7M7 17l-1.4 1.4" />
    </svg>
  );
}

export function KahramanBandi({ tarih }: { tarih?: Date }) {
  // DIL DE GEREKLI: tarih `toLocaleDateString` ile AKTIF DILDE bicimlenir.
  // Elle bicimlemek, yedi dilin ay adlarini elle yazmak olurdu.
  const { t, dil } = useI18n();
  const { data: kimlik } = useSWR<Kimlik>("/api/me", jsonFetcher);
  const { data: tesis } = useSWR<TesisAyari>("/api/tenant/settings", jsonFetcher);
  // HAVA HATASI YUTULUR: uc konum ayarlanmamissa 503 doner ve bu bir
  // KUSUR DEGIL, bir durum. `shouldRetryOnError` kapali — 503 kalici bir
  // yapilandirma eksikligiyse her 5 saniyede yeniden denemek bosuna.
  const { data: hava } = useSWR<HavaDurumu>("/api/weather", jsonFetcher, {
    shouldRetryOnError: false,
    revalidateOnFocus: false,
  });

  const simdi = tarih ?? new Date();
  const ad = kimlik?.ad?.split(" ")[0] ?? null;

  return (
    <section
      data-test="pano-kahraman"
      aria-label={t("panoKahramanBaslik")}
      className="mb-5 overflow-hidden px-5 py-6 sm:px-7 sm:py-7"
      style={{
        borderRadius: "var(--yz-radius-card)",
        // MARKA GRADYANI: lacivert kenar cubuguyla ayni aileden, iceriden
        // aydinlanan bir yuzey. Uzerindeki metin BEYAZ ve en acik durakta
        // bile AA'yi tutuyor (olculdu: #2f4a6b uzerinde 8.0).
        background:
          "linear-gradient(120deg, var(--yz-bg-sidebar) 0%, #24405f 55%, #2f4a6b 100%)",
        color: "var(--yz-sidebar-text)",
      }}
    >
      <h1
        style={{
          fontSize: "var(--yz-fs-h1)",
          fontWeight: 600,
          lineHeight: "var(--yz-lh-tight)",
        }}
      >
        {/* AD GELMEDEN ADSIZ SELAM: ad henuz yuklenmemisken selamin
            sonunu virgulde birakmak yarim bir cumle olurdu; onun yerine
            adsiz ama TAM bir cumle kurulur. */}
        {ad ? t(selamAnahtari(simdi.getHours()), { ad }) : t("panoSelamAdsiz")}
      </h1>
      {tesis?.ad ? (
        <p className="mt-1" style={{ fontSize: "var(--yz-fs-body)", opacity: 0.9 }}>
          {t("panoKahramanTesis", { tesis: tesis.ad })}
        </p>
      ) : null}
      <div
        className="mt-3 flex flex-wrap items-center gap-x-5 gap-y-2"
        style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-sidebar-text-2)" }}
      >
        <span className="inline-flex items-center gap-1.5">
          <TakvimIkonu />
          {/* TARIH AKTIF DILDE: `toLocaleDateString` sozlukten gelen dil
              koduyla cagrilir; elle bicimlemek yedi dili elle yazmakti. */}
          {simdi.toLocaleDateString(dil, {
            day: "numeric",
            month: "long",
            year: "numeric",
            weekday: "long",
          })}
        </span>
        {hava ? (
          <span className="inline-flex items-center gap-1.5" data-test="pano-hava">
            <HavaIkonu />
            {t("panoHava", {
              derece: Math.round(hava.sicaklik_c),
              durum: t(HAVA_ANAHTARI[hava.durum]),
            })}
          </span>
        ) : null}
      </div>
    </section>
  );
}
