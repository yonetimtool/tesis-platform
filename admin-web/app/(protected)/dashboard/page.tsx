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
import Link from "next/link";
import useSWR from "swr";

import { BinaSahnesiYukleyici } from "@/components/3d/sahne-yukleyici";
import type { SahneBlogu, SahneSecimi } from "@/components/3d/bina-sahnesi";
import { Dugme, IskeletKpi, Kpi } from "@/components/ui";

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
  BuildingMap,
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
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_KAMERA = "kamera" as const;
const TUR_ALARM = "alarm" as const;
const DAIRE_NORMAL = "normal" as const;
const DAIRE_ALARM = "alarm" as const;
const BOS_SECIM: SahneSecimi = { blokId: null, kat: null, daireId: null };
const SECILI_TUR = "birincil" as const;
const SECILMEMIS_TUR = "ikincil" as const;

/**
 * (P161) SAHNE SECIM PANELI — maketteki secimin METIN KARSILIGI.
 *
 * SAHNE TEK BASINA YETMEZ: bir pencerenin rengi "acik sikayet var"
 * demeyi beceremez, klavye kullanicisi zaten tuvale tiklayamaz. Panel
 * hem acilimi surer (blok -> kat -> daire) hem de sahnenin tasidigi
 * bilgiyi okunur halde verir. Yani sahne olmadan da CALISIR.
 */
function SahneSecimPaneli({
  secim,
  bloklar,
  onSecim,
  onKapat,
}: {
  secim: SahneSecimi;
  bloklar: SahneBlogu[];
  onSecim: (s: SahneSecimi) => void;
  onKapat: () => void;
}) {
  const t = useT();
  const blok = bloklar.find((b) => b.id === secim.blokId) ?? null;

  if (!blok) {
    return (
      <Kart className="p-kart">
        <p className="text-satiralt leading-[1.6] text-metin-muted">
          {t("sahneSecimIpucu")}
        </p>
      </Kart>
    );
  }

  const katlar = [...new Set(blok.daireler.map((d) => d.kat))].sort((a, b) => a - b);
  const katDaireleri = blok.daireler
    .filter((d) => d.kat === secim.kat)
    .sort((a, b) => a.sira - b.sira);
  const daire = blok.daireler.find((d) => d.id === secim.daireId) ?? null;
  const katAdi = (k: number) => (k === 0 ? t("sahneZeminKat") : t("sahneKatAdi", { n: k }));

  return (
    <Kart className="space-y-3 p-kart">
      <div className="flex items-start justify-between gap-2">
        <div>
          <p className="text-kartbaslik text-metin-heading">{blok.ad}</p>
          <p className="mt-0.5 text-satiralt text-metin-muted">
            {t("sahneBlokOzeti", { kat: katlar.length, daire: blok.daireler.length })}
          </p>
        </div>
        <button
          type="button"
          onClick={onKapat}
          className="shrink-0 text-satiralt underline text-metin-muted"
        >
          {t("sahneSecimTemizle")}
        </button>
      </div>

      <div>
        <p className="text-satiralt font-medium text-metin-heading">{t("sahneKatBaslik")}</p>
        <div className="mt-1.5 flex flex-wrap gap-1.5">
          {katlar.map((k) => (
            <Dugme
              key={k}
              boy="kucuk"
              tur={secim.kat === k ? SECILI_TUR : SECILMEMIS_TUR}
              aria-pressed={secim.kat === k}
              onClick={() =>
                onSecim({ blokId: blok.id, kat: secim.kat === k ? null : k, daireId: null })
              }
            >
              {katAdi(k)}
            </Dugme>
          ))}
        </div>
      </div>

      {secim.kat !== null && (
        <div>
          <p className="text-satiralt font-medium text-metin-heading">
            {t("sahneDaireBaslik")}
          </p>
          <div className="mt-1.5 flex flex-wrap gap-1.5">
            {katDaireleri.map((d) => (
              <Dugme
                key={d.id}
                boy="kucuk"
                tur={secim.daireId === d.id ? SECILI_TUR : SECILMEMIS_TUR}
                aria-pressed={secim.daireId === d.id}
                onClick={() =>
                  onSecim({
                    blokId: blok.id,
                    kat: d.kat,
                    daireId: secim.daireId === d.id ? null : d.id,
                  })
                }
              >
                {d.no}
              </Dugme>
            ))}
          </div>
        </div>
      )}

      {daire && (
        <div className="border-t border-yuzey-divider pt-3">
          <p className="text-satiralt text-metin-muted">
            {t("sahneDaireOzeti", { no: daire.no, kat: katAdi(daire.kat) })}
          </p>
          <p className="mt-1 text-satiralt text-metin-heading">
            {daire.durum === DAIRE_ALARM ? t("sahneDaireAlarm") : t("sahneDaireNormal")}
          </p>

          {/* (P162 §8.2) SECILI DAIREDEN ILGILI HER YERE.
              Maketten bir daire secmek tek basina bir sey yapmiyordu:
              kullanici daireyi buluyor, sonra menuden ilgili ekrani elle
              ariyordu. Baglantilar kaydin KIMLIGINI tasiyor — hedef
              ekranlar sorgu parametresiyle suzuluyor. */}
          <p className="mt-3 text-satiralt font-medium text-metin-heading">
            {t("sahneEylemler")}
          </p>
          <div className="mt-1.5 flex flex-wrap gap-1.5">
            {[
              { anahtar: "sahneEylemDaire" as const, yol: `/units?daire=${daire.id}` },
              { anahtar: "sahneEylemSakin" as const, yol: `/users?daire=${daire.id}` },
              { anahtar: "sahneEylemSikayet" as const, yol: `/complaints?daire=${daire.id}` },
              { anahtar: "sahneEylemAidat" as const, yol: `/dues?daire=${daire.id}` },
              { anahtar: "sahneEylemGorev" as const, yol: `/tasks?daire=${daire.id}` },
              { anahtar: "sahneEylemDemirbas" as const, yol: `/assets?daire=${daire.id}` },
            ].map((e) => (
              <Link
                key={e.anahtar}
                href={e.yol}
                className="odak-ic rounded-btn px-2 py-1 text-satiralt underline"
                style={{ color: "var(--yz-accent-ink)" }}
              >
                {t(e.anahtar)}
              </Link>
            ))}
          </div>
        </div>
      )}
    </Kart>
  );
}

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
  // Secim SAHNE ile PANEL arasinda paylasilir: ikisi de ayni durumu
  // surer, biri digerinin kopyasini tutmaz.
  const [secim, setSecim] = useState<SahneSecimi>(BOS_SECIM);
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
  // `useMemo`: `?? []` her cizimde YENI dizi uretir ve etiket
  // `useMemo`sunun bagimliligini her karede degistirirdi (lint yakaladi).
  const gruplar: AlarmGrubu[] = useMemo(() => data?.alarm_gruplari ?? [], [data]);
  // `useMemo`: `?? []` her cizimde YENI bir dizi uretir ve asagidaki
  // `useMemo`nun bagimliligini her karede degistirirdi (lint yakaladi).
  const kameralar: Kamera[] = useMemo(
    () => kameraYanit?.items ?? [],
    [kameraYanit],
  );

  // (P161) SAHNE VERISI — UYDURMA DEGIL, GERCEK UCLARDAN.
  //
  // Brief'in tartismasiz kurali: "VERIYE BAGLI olacak, dekor degil".
  // P160'ta sahne yalniz `/api/blocks`i (kat + daire SAYISI) okuyordu;
  // sayiyla kutu buyutmek DAIRE cizmek degildi. Artik yapiyi
  // `/unit-complaints/building-map` veriyor: blok -> kat -> daire, her
  // dairenin kimligi ve numarasiyla. Uc ZATEN VARDI ve rol-farkindadir
  // (sayim/renk yalnizca yonetime dolu doner) — sozlesme degismedi.
  //
  // IKI UC BIRLESTIRILIYOR: `/blocks` blogun RESMI listesidir (dairesi
  // girilmemis blok da orada), `building-map` ise dairelerin yerlesimi.
  // Yalniz birine bakmak, ya bos bloklari ya da blok kaydi olmayan
  // daireleri sahneden dusururdu.
  const { data: blokYanit } = useSWR<BlockList>("/api/blocks", jsonFetcher, {
    revalidateOnFocus: false,
  });
  const { data: binaHaritasi } = useSWR<BuildingMap>("/api/building-map", jsonFetcher, {
    revalidateOnFocus: false,
  });

  const sahneBloklari = useMemo(() => {
    const haritada = new Map((binaHaritasi?.bloklar ?? []).map((b) => [b.blok, b]));
    const daireleriCikar = (ad: string) =>
      (haritada.get(ad)?.katlar ?? []).flatMap((k) =>
        k.units.map((u, i) => ({
          id: u.unit_id,
          no: u.unit_no,
          kat: k.kat,
          sira: u.sira ?? i,
          // DURUM YALNIZ VERININ TASIDIGI KADAR. `complaint_count` acik
          // sikayet sayisidir ve sunucu bunu yonetim disindaki rollere
          // `null` doner — o zaman renk de yoktur, uydurulmaz.
          durum: (u.complaint_count ?? 0) > 0 ? DAIRE_ALARM : DAIRE_NORMAL,
        })),
      );

    const resmi = (blokYanit?.items ?? []).map((b) => ({
      id: b.ad,
      ad: b.ad,
      daireler: daireleriCikar(b.ad),
    }));
    // Blok KAYDI olmayan ama dairesi olan adlar (zayif metin bagi) da
    // sahneye girer — yoksa o daireler gorunmez olurdu.
    const resmiAdlar = new Set(resmi.map((b) => b.ad));
    const artiklar = (binaHaritasi?.bloklar ?? [])
      .filter((b) => !resmiAdlar.has(b.blok))
      .map((b) => ({ id: b.blok, ad: b.blok, daireler: daireleriCikar(b.blok) }));
    return [...resmi, ...artiklar];
  }, [blokYanit, binaHaritasi]);

  // ETIKETLER: ZATEN CEKILEN listelerden — sahne icin ek istek ATILMIYOR.
  const sahneIsaretcileri = useMemo(
    () => [
      ...gruplar.slice(0, 4).map((g) => ({
        id: `alarm-${g.tip}-${g.patrol_plan_id ?? "-"}`,
        ad: enumAdi(t, BILDIRIM_TIP, g.tip),
        tur: TUR_ALARM,
      })),
      ...kameralar.slice(0, 8).map((k) => ({
        id: k.id,
        ad: k.ad,
        tur: TUR_KAMERA,
        // Cevrimdisi kameranin noktasi SOLUKLASIR (brief'in ornegi).
        sonuk: k.aktif === false,
      })),
    ],
    [gruplar, kameralar, t],
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
          {/* HARITA ARTIK AYRI KART (brief): 3D sahne kendi tam genislikte
              bolumune tasindi, harita onun altinda ezilmiyor. */}
          <Kart className="overflow-hidden">
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

      {/* --- (e) SITE MAKETI — TAM GENISLIK -------------------------------
          Brief: "3D sahneye panoda sag sutunun tamamini ya da tam genislik
          bir bolum ver". 260 px'lik bir kutunun icinde blok->kat->daire
          acilimi YAPILAMIYORDU: secili kata yaklasan kamera icin yer yoktu.
          Paket TEMBEL yuklenir; ana pakete girmez. */}
      <section>
        <BolumBasligi baslik={t("sahneSiteBaslik")} />
        <div className="grid gap-bolum lg:grid-cols-4">
          <Kart className="overflow-hidden lg:col-span-3">
            <BinaSahnesiYukleyici
              bloklar={sahneBloklari}
              isaretciler={sahneIsaretcileri}
              secim={secim}
              onSecim={setSecim}
              yukseklik="clamp(320px, 46vh, 520px)"
            />
          </Kart>
          <SahneSecimPaneli
            secim={secim}
            bloklar={sahneBloklari}
            onSecim={setSecim}
            onKapat={() => setSecim(BOS_SECIM)}
          />
        </div>
      </section>

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
