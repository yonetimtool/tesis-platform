"use client";

// (P133.2) PANO — "tint blok" dili.
//
// P132 token katmanini indirmisti ama urun P132 oncesiyle AYNI goruunuyordu:
// token'lar dogruydu, degismeyen sey gorsel DILDI. Bu sayfa o dili tasir.
//
// SIRA (Kerem'in onayindan birebir):
//   a) selamlama + durumu duz cumleyle ozetleyen TEK cumle
//   b) KAHRAMAN tint blok: suren devriye (yoksa siradaki, o da yoksa
//      dostca bos durum — spinner degil, "veri yok" degil)
//   c) en cok 4 IKINCIL tint blok
//   d) tesis blogu: harita BLOK GENISLIGINI doldurur + ad + NFC sayisi
//
// SERT SINIR — 1 kahraman + 4 ikincil. Renk SINYAL kalmali; alti tintli
// ekran gurultudur. Sinir yorumla degil TESTLE tutulur
// (`pano-tint-blok.dom.test.ts`).
//
// KILCAL IZGARA TABLO YOK: ayrim dolgu ve bosluktan gelir, 0.5px cizgiden
// degil. Alarmlar da tablo degil, acilir GRUP satirlaridir.
//
// GIDIS-DONUS SAYISI DEGISMEDI: yine uc istek (canli pano, tesis ayarlari,
// kameralar). Yeni bloklarin verisi (`aidat_tahsilat_orani`,
// `nfc_nokta_sayisi`) AYNI yanita bindirildi — dorduncu bir istek acmak,
// yeniden tasarimin bedeli olurdu.
import { useState } from "react";
import { useMemo } from "react";
import useSWR from "swr";

import { BinaSahnesiYukleyici } from "@/components/3d/sahne-yukleyici";
import { IskeletKpi, Kpi } from "@/components/ui";

import { KameraSeridi } from "@/components/KameraSeridi";
import { SiteHarita } from "@/components/SiteHarita";
import {
  BolumBasligi,
  BosDurum,
  Chip,
  HataDurumu,
  KahramanBlok,
  Kart,
  SayfaBasligi,
  TintBlok,
  Yukleniyor,
  type Vurgu,
} from "@/components/tasarim";
import { BILDIRIM_TIP, enumAdi } from "@/lib/enum-adlari";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useI18n, useT } from "@/lib/i18n/kullan";
import type {
  AktifTur,
  AlarmGrubu,
  BlockList,
  DashboardLive,
  Kamera,
  KameraListResponse,
  TenantSettings,
} from "@/lib/types";

function Ikon({ d }: { d: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={d} />
    </svg>
  );
}

const YOL = {
  tur: "M4 18l5-7 5 4 6-9",
  onay: "M20 6L9 17l-5-5",
  saat: "M12 7.5V12l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
  zil: "M6 9a6 6 0 1 1 12 0c0 4 1.5 5 2 6H4c.5-1 2-2 2-6ZM10 20a2 2 0 0 0 4 0",
  para: "M3 6h18v12H3zM12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5Z",
};

/** Alarm ONEMI -> vurgu kimligi (renk token'da, anlam burada). */
const ONEM_VURGU: Record<string, Vurgu> = {
  yuksek: "red",
  orta: "orange",
  dusuk: "blue",
};

/** Bir pencere SU AN suruyor mu? */
function suruyor(tur: AktifTur, simdi: number): boolean {
  return (
    tur.durum === "bekliyor" &&
    Date.parse(tur.pencere_baslangic) <= simdi &&
    simdi < Date.parse(tur.pencere_bitis)
  );
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const KPI_KRITIK = "kritik" as const;
const KPI_OLUMLU = "olumlu" as const;
const KPI_UYARI = "uyari" as const;
/** Tahsilat orani bu esigin altinda UYARI halkasi. */
const TAHSILAT_ESIGI = 80;
const DURUM_NORMAL = "normal" as const;
const DURUM_CEVRIMDISI = "cevrimdisi" as const;

export default function DashboardPage() {
  const t = useT();
  const { dil } = useI18n();
  // `Intl` nesnesi her cizimde yeniden kurulmaz.
  const yuzde = useMemo(() => {
    const b = new Intl.NumberFormat(dil, {
      style: "percent",
      maximumFractionDigits: 0,
    });
    return (n: number) => b.format(n / 100);
  }, [dil]);
  const { data, error, isLoading } = useSWR<DashboardLive>(
    "/api/dashboard/live",
    jsonFetcher,
    { refreshInterval: 15000, revalidateOnFocus: true },
  );
  const { data: tesis } = useSWR<TenantSettings>("/api/tenant/settings", jsonFetcher, {
    revalidateOnFocus: false,
  });
  const { data: kameraYanit } = useSWR<KameraListResponse>(
    "/api/cameras?limit=50&offset=0",
    jsonFetcher,
    { revalidateOnFocus: false },
  );

  const turlar = data?.aktif_turlar ?? [];
  const gruplar = data?.alarm_gruplari ?? [];
  // `useMemo`: `?? []` her cizimde YENI bir dizi uretir ve asagidaki
  // `useMemo`nun bagimliligini her karede degistirirdi (lint yakaladi).
  const kameralar: Kamera[] = useMemo(
    () => kameraYanit?.items ?? [],
    [kameraYanit],
  );

  // (P160 / Asama 5) SAHNE VERISI — UYDURMA DEGIL, GERCEK UCLARDAN.
  //
  // Brief'in tartismasiz kurali: "VERIYE BAGLI olacak, dekor degil".
  // Bloklar `/api/blocks`tan (kat ve daire sayisiyla), isaretciler ise
  // ZATEN CEKILEN kamera listesinden geliyor — sahne icin ek istek
  // ATILMIYOR. Kamera cevrimdisiysa isaretci gri olur.
  const { data: blokYanit } = useSWR<BlockList>("/api/blocks", jsonFetcher, {
    revalidateOnFocus: false,
  });
  const sahneBloklari = useMemo(
    () =>
      (blokYanit?.items ?? []).map((b) => ({
        id: b.id,
        ad: b.ad,
        kat: b.kat_sayisi ?? 1,
        daire: b.unit_sayisi,
      })),
    [blokYanit],
  );
  const sahneIsaretcileri = useMemo(
    () =>
      kameralar.slice(0, 12).map((k) => ({
        id: k.id,
        ad: k.ad,
        // DURUM VERIDEN: cevrimdisi kamera GRI isaretci (brief'in ornegi).
        durum: k.aktif === false ? DURUM_CEVRIMDISI : DURUM_NORMAL,
      })),
    [kameralar],
  );

  const tamamlanan = turlar.filter((x) => x.durum === "tamamlandi").length;
  const gecikmeSayisi = gruplar.reduce((n, g) => n + g.sayi, 0);

  // KAHRAMAN: once SUREN tur; yoksa SIRADAKI bekleyen; o da yoksa bos durum.
  const simdi = data ? Date.parse(data.generated_at) : Date.now();
  const suren = turlar.find((x) => suruyor(x, simdi)) ?? null;
  const siradaki =
    suren ??
    turlar
      .filter((x) => x.durum === "bekliyor" && Date.parse(x.pencere_baslangic) > simdi)
      .sort((a, b) => Date.parse(a.pencere_baslangic) - Date.parse(b.pencere_baslangic))[0] ??
    null;

  // --- (a) DURUM CUMLESI: sabit varyant YAZILMAZ, yan cumlelerden kurulur.
  //
  // Boylece sayaclar 0 olunca da dogru kalir: uymayan yan cumle listeye
  // GIRMEZ, hepsi bosalirsa "olagan disi bir sey yok" cumlesi cikar.
  // Ayirici de sozlukten gelir (Arapca "،" kullanir).
  const yanCumleler: string[] = [];
  yanCumleler.push(suren ? t("pano2DevriyeSuruyor") : t("pano2DevriyeYok"));
  if (gecikmeSayisi > 0) yanCumleler.push(t("pano2Gecikme", { sayi: gecikmeSayisi }));
  if (tamamlanan > 0) yanCumleler.push(t("pano2Tamamlanan", { sayi: tamamlanan }));
  const ozet =
    yanCumleler.length === 1 && !suren && gecikmeSayisi === 0 && tamamlanan === 0
      ? t("pano2Sakin")
      : `${yanCumleler.join(t("pano2Ayirici"))}.`;

  return (
    <div className="space-y-bolum">
      <SayfaBasligi
        baslik={t("pano2Selam")}
        aciklama={data ? ozet : undefined}
      />

      {/* Hata KUTUSU canli bolgedir: pano 15 sn'de bir yenilenir. */}
      {error ? <HataDurumu mesaj={error.message} /> : null}

      {/* --- (b) KAHRAMAN BLOK ---------------------------------------- */}
      {isLoading && !data ? (
        <Yukleniyor satir={3} />
      ) : siradaki ? (
        <KahramanBlok
          vurgu={suren ? "blue" : "purple"}
          ikon={<Ikon d={YOL.tur} />}
          ustBaslik={suren ? t("pano2HeroUst") : t("pano2HeroSiradakiUst")}
          baslik={siradaki.patrol_plan_ad ?? siradaki.patrol_plan_id.slice(0, 8)}
          altSatirlar={[
            t("pano2HeroIlerleme", {
              okutulan: siradaki.okutulan_checkpoint_sayisi ?? 0,
              beklenen: siradaki.beklenen_checkpoint_sayisi ?? 0,
            }),
            suren
              ? t("pano2HeroSonAn", { zaman: formatDateTime(siradaki.pencere_bitis) })
              : t("pano2HeroBaslangic", {
                  zaman: formatDateTime(siradaki.pencere_baslangic),
                }),
          ]}
          ilerleme={{
            simdi: siradaki.okutulan_checkpoint_sayisi ?? 0,
            toplam: siradaki.beklenen_checkpoint_sayisi ?? 0,
          }}
          href="/patrol-plans"
        />
      ) : (
        <BosDurum
          baslik={t("pano2HeroBosBaslik")}
          aciklama={t("pano2HeroBosAlt")}
        />
      )}

      {/* --- (c) KPI HALKALARI ---------------------------------------
          (P160) P133'un "tint blok"lari METALIK HALKAYA gecti: renk artik
          DOLGU degil, halkanin cizgisi (durum sinyali). Sayilar 0'dan
          hedefe sayarak gelir; hareket azaltmada dogrudan yazilir. */}
      {isLoading && !data ? (
        <IskeletKpi adet={4} />
      ) : (
        <div className="flex flex-wrap justify-center gap-8 sm:justify-start">
          <Kpi
            deger={gecikmeSayisi}
            etiket={t("pano2BlokGecikme")}
            durum={gecikmeSayisi ? KPI_KRITIK : KPI_OLUMLU}
            href="/notifications"
          />
          <Kpi
            deger={turlar.length}
            etiket={t("pano2BlokTur")}
            durum="bilgi"
            href="/patrol-plans"
          />
          <Kpi
            deger={tamamlanan}
            etiket={t("pano2BlokTamamlanan")}
            durum="olumlu"
            href="/reports/patrols"
          />
          {/* MALI HALKA YALNIZ YETKI VARSA: sunucu tahsilat oranini
              guvenlik rollerine `null` doner. "0%" cizmek, veriyi
              sizdirmadan YANLIS bilgi vermek olurdu — halka hic cizilmez. */}
          {data?.aidat_tahsilat_orani != null && (
            <Kpi
              deger={data.aidat_tahsilat_orani}
              // BIRIM YERI DILE BAGLI: tr "%78", en "78%". `Intl` bunu
              // aktif dile gore kendisi koyar; elle yazmak yedi dilden
              // altisinda yanlis olurdu.
              bicimle={yuzde}
              etiket={t("pano2BlokTahsilat")}
              durum={data.aidat_tahsilat_orani >= TAHSILAT_ESIGI ? KPI_OLUMLU : KPI_UYARI}
              href="/finans"
            />
          )}
        </div>
      )}

      {/* --- ALARMLAR (gruplu) + (d) TESIS BLOGU ---------------------
          YENIDEN AKAN IZGARA, sabit iki sutun DEGIL: eski duzen sagda
          haritanin altinda ekranin ucte birini bos birakiyordu. Burada
          sutunlar icerige gore doluyor. */}
      <div className="grid gap-bolum lg:grid-cols-5">
        <section className="lg:col-span-3">
          <BolumBasligi baslik={t("panelSonAlarmlar")} href="/notifications" />
          {isLoading && !data ? (
            <Yukleniyor satir={3} />
          ) : gruplar.length === 0 ? (
            <BosDurum baslik={t("pano2AlarmYokBaslik")} />
          ) : (
            <div className="space-y-2">
              {gruplar.map((g) => (
                <AlarmGrubuSatiri key={`${g.tip}-${g.patrol_plan_id ?? "-"}`} grup={g} />
              ))}
            </div>
          )}
        </section>

        <section className="lg:col-span-2">
          <BolumBasligi baslik={t("pano2TesisBaslik")} />
          <Kart className="overflow-hidden">
            {/* (P160 / Asama 5) 3D SAHNE — harita yerine izometrik maket.
                Bloklar GERCEK veriden (kat/daire sayisi) cizilir; model
                dosyasi yok, yer tutucu geometri kullanilir (brief).
                Paket TEMBEL yuklenir: ana pakete girmez. */}
            <BinaSahnesiYukleyici
              bloklar={sahneBloklari}
              isaretciler={sahneIsaretcileri}
              yukseklik="260px"
            />
            {/* Harita KALDIRILMADI: konum bilgisi hâlâ degerli ve 3D
                sahne onun yerine gecmiyor, YANINA geliyor. */}
            <SiteHarita
              lat={tesis?.konum_lat}
              lon={tesis?.konum_lon}
              ad={tesis?.konum_ad ?? tesis?.ad}
              chromsuz
            />
            <div className="border-t border-yuzey-divider p-kart">
              <p className="text-kartbaslik text-metin-heading">
                {tesis?.ad ?? "—"}
              </p>
              <p className="mt-0.5 text-satiralt leading-[1.6] text-metin-muted">
                {t("pano2TesisNfc", { sayi: data?.nfc_nokta_sayisi ?? 0 })}
              </p>
            </div>
          </Kart>
        </section>
      </div>

      <KameraSeridi kameralar={kameralar} />
    </div>
  );
}

/**
 * Alarm GRUBU satiri — tek satir, olaylara acilir.
 *
 * Eskiden pano alti neredeyse AYNI satiri yan yana ciziyordu; sebep veri
 * modelinde (bir planin alti penceresi alti bildirim uretir). Sunucu artik
 * gruplu donuyor, burasi da tek satir cizip AYRINTIYI istege birakiyor.
 */
function AlarmGrubuSatiri({ grup }: { grup: AlarmGrubu }) {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const vurgu = ONEM_VURGU[grup.onem] ?? "orange";
  const tekOlay = grup.sayi === 1;

  return (
    <Kart>
      <button
        type="button"
        onClick={() => setAcik((x) => !x)}
        aria-expanded={acik}
        // Tek olayli grup acilmaz: acilinca gosterecegi tek satir zaten
        // ustte yaziyor olurdu.
        disabled={tekOlay}
        aria-label={acik ? t("pano2AlarmKapat") : t("pano2AlarmAc")}
        className="odak-ic flex w-full items-center gap-3 p-kart text-start disabled:cursor-default"
      >
        <span className="min-w-0 flex-1">
          <span className="block truncate text-kartbaslik text-metin-heading">
            {grup.patrol_plan_ad ?? enumAdi(t, BILDIRIM_TIP, grup.tip)}
          </span>
          <span className="mt-0.5 block truncate text-satiralt leading-[1.6] text-metin-muted">
            {grup.mesaj}
          </span>
        </span>
        <span className="flex shrink-0 items-center gap-2">
          <Chip vurgu={vurgu}>{t("pano2AlarmSayi", { sayi: grup.sayi })}</Chip>
          <span className="text-satiralt text-metin-muted">
            {formatDateTime(grup.en_son)}
          </span>
        </span>
      </button>
      {acik && (
        <ul className="border-t border-yuzey-divider px-kart py-2">
          {grup.olaylar.map((o, i) => (
            <li
              key={`${o.patrol_window_id ?? i}`}
              className="py-1 text-satiralt leading-[1.6] text-metin-muted"
            >
              {formatDateTime(o.olusma_zamani)}
            </li>
          ))}
        </ul>
      )}
    </Kart>
  );
}
