"use client";

// (P167 Asama 2) OZET — eski "Canli Panel"in yerine.
//
// =====================================================================
// SAYFA ARTIK BOLUMLERDEN OLUSUYOR VE SIRASI KULLANICININ
// =====================================================================
// P133/P160'ta sayfa sabit bir siralamaydi (kahraman blok -> KPI ->
// alarmlar -> harita -> 3D -> kamera). Brief §2.5 bunu tersine ceviriyor:
// "Tum bolumler yonetici tarafindan gizlenebilir/gosterilebilir ve
// siralanabilir olacak."
//
// Bolum listesi `lib/pano-tercihi.ts`te TEK KAYNAK: hem cizim hem
// duzenleme modu hem sunucuya yazilan govde oradan okur. Uc yerde elle
// tekrar edilseydi, yeni bir bolum eklendiginde biri unutulur ve o bolum
// ya cizilmez ya da duzenleme modunda gorunmezdi.
//
// TERCIH SUNUCUDA (`/me/pano-tercihi`), `localStorage`ta DEGIL — gerekce
// `lib/pano-tercihi.ts` basliginda.
//
// =====================================================================
// (§2.4) HARITA KALDIRILDI
// =====================================================================
// `SiteHarita` bu sayfanin TEK cagri yeriydi; brief "Ozet'te olmayacak"
// dedigi icin cagri kalkti. Bilesen dosyasi SILINMEDI: tesis konumu bir
// gun kendi ekranini bulacak ve calisan bir bileseni silip yeniden
// yazmak, kaldirilan seyi geri getirmenin en pahali yolu olurdu. Bugun
// hicbir yerden cagrilmiyor ve bu raporda ACIKCA yazili.
//
// 3D maket §2.4'un istedigi gibi SAG UST tarafta: varsayilan sirada
// `finans` ve `maket` yan yana iki YARIM bolum, yani maket widget
// seridinin hemen altinda sag sutunda duruyor.
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import useSWR from "swr";

import { BinaSahnesiYukleyici } from "@/components/3d/sahne-yukleyici";
import { DevriyeGorunumu } from "@/components/DevriyeGorunumu";
import type { SahneBlogu, SahneSecimi } from "@/components/3d/bina-sahnesi";
import { Dugme, IskeletKpi, Kpi } from "@/components/ui";
import { PanoFinansOzeti } from "@/components/pano/finans-ozeti";
import { PanoTakvim } from "@/components/pano/takvim";
import { WidgetSeridi, type WidgetAdayi } from "@/components/pano/widget-seridi";
import { SayfaEylemleri } from "@/components/SayfaEylemleri";
import { useToast } from "@/components/Toast";
import { KameraSeridi } from "@/components/KameraSeridi";
import {
  BolumBasligi,
  BosDurum,
  Chip,
  HataDurumu,
  KahramanBlok,
  Kart,
  SayfaBasligi,
  Yukleniyor,
  type Vurgu,
} from "@/components/tasarim";
import { apiSend } from "@/lib/client";
import { BILDIRIM_TIP, enumAdi } from "@/lib/enum-adlari";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useI18n, useT } from "@/lib/i18n/kullan";
import { menuGruplari, ogeBaglantisi } from "@/lib/menu";
import {
  bolumleriCoz,
  tercihGovdesi,
  widgetlariCoz,
  type CozulmusBolum,
  type PanoTercihi,
} from "@/lib/pano-tercihi";
import { useRol } from "@/lib/rol-kullan";
import type {
  AktifTur,
  AlarmGrubu,
  BlockList,
  BuildingMap,
  DashboardLive,
  Kamera,
  KameraListResponse,
} from "@/lib/types";

function Ikon({ d }: { d: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-[18px] w-[18px]"
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
};

/** Alarm ONEMI -> vurgu kimligi (renk token'da, anlam burada). */
const ONEM_VURGU: Record<string, Vurgu> = {
  yuksek: "red",
  orta: "orange",
  dusuk: "blue",
};

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_KAMERA = "kamera" as const;
const TUR_ALARM = "alarm" as const;
const DAIRE_NORMAL = "normal" as const;
const DAIRE_ALARM = "alarm" as const;
const BOS_SECIM: SahneSecimi = { blokId: null, kat: null, daireId: null };
const SECILI_TUR = "birincil" as const;
const SECILMEMIS_TUR = "ikincil" as const;
/** Bolum gorunurlugunu cevirirken kart etiketi (duzenleme modu). */
const ETIKET_DIV = "div" as const;
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const VURGU_SUREN = "blue" as const;
const VURGU_SIRADAKI = "purple" as const;
const KPI_KRITIK = "kritik" as const;
const KPI_OLUMLU = "olumlu" as const;
const KPI_UYARI = "uyari" as const;
const KPI_BILGI = "bilgi" as const;
/** Tahsilat orani bu esigin altinda UYARI halkasi. */
const TAHSILAT_ESIGI = 80;

/** Bir pencere SU AN suruyor mu? */
function suruyor(tur: AktifTur, simdi: number): boolean {
  return (
    tur.durum === "bekliyor" &&
    Date.parse(tur.pencere_baslangic) <= simdi &&
    simdi < Date.parse(tur.pencere_bitis)
  );
}

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
  const toast = useToast();
  const rol = useRol(null);

  // BIRIM YERI DILE BAGLI: tr "%78", en "78%". `Intl` bunu aktif dile gore
  // kendisi koyar; elle yazmak yedi dilden altisinda yanlis olurdu.
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
  const [duzenlemede, setDuzenlemede] = useState(false);

  const { data, error, isLoading } = useSWR<DashboardLive>(
    "/api/dashboard/live",
    jsonFetcher,
    { refreshInterval: 15000, revalidateOnFocus: true },
  );
  const { data: kameraYanit } = useSWR<KameraListResponse>(
    "/api/cameras?limit=50&offset=0",
    jsonFetcher,
    { revalidateOnFocus: false },
  );

  // ---------------------------------------------------------------- duzen
  const { data: tercih, mutate: tercihTazele } = useSWR<PanoTercihi>(
    "/api/me/pano-tercihi",
    jsonFetcher,
    { revalidateOnFocus: false },
  );

  // WIDGET ADAYLARI MENUDEN: brief'in "yetkili oldugu sekmelerle sinirli"
  // sarti, `menuGruplari` ile AYNI kaynaktan gelir. Ikinci bir yetki
  // listesi yazsaydik, bir sayfanin rol kapisi degistiginde biri
  // guncellenip oteki unutulurdu.
  const adaylar: WidgetAdayi[] = useMemo(() => {
    return menuGruplari("tesis", rol).flatMap((g) =>
      g.ogeler.map((o) => ({
        rota: ogeBaglantisi(o),
        etiket: t(o.anahtar),
        bolum: t(g.anahtar),
        ikon: <Ikon d={YOL.tur} />,
      })),
    );
  }, [rol, t]);

  const izinliRotalar = useMemo(() => adaylar.map((a) => a.rota), [adaylar]);

  // VARSAYILAN KISAYOLLAR: yoneticinin gunluk baktigi ilk alti ekran.
  // Sunucuda TUTULMAZ — orada hesaplamak, ayni karari menuden sonra
  // ikinci bir yerde daha vermek olurdu (bkz. `/me/pano-tercihi` notu).
  const varsayilanWidget = useMemo(
    () => ["/dues", "/finans", "/tasks", "/complaints", "/units", "/olaylar"],
    [],
  );

  const [widgetlar, setWidgetlar] = useState<string[] | null>(null);
  const [bolumler, setBolumler] = useState<CozulmusBolum[] | null>(null);

  // SUNUCUDAN GELEN KAYIT DURUMA BIR KEZ yuklenir; kullanici duzenlerken
  // SWR tazelemesi yazdigini EZMESIN (profil formundaki desenin aynisi).
  useEffect(() => {
    if (tercih === undefined) return;
    setWidgetlar(widgetlariCoz(tercih, izinliRotalar, varsayilanWidget));
    setBolumler(bolumleriCoz(tercih));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tercih === undefined]);

  const seciliWidgetlar = widgetlar ?? [];
  const cizilecekBolumler = bolumler ?? bolumleriCoz(tercih);

  async function duzeniKaydet(
    yeniWidget: readonly string[],
    yeniBolum: readonly CozulmusBolum[],
  ) {
    try {
      await apiSend(
        "/api/me/pano-tercihi",
        "PUT",
        tercihGovdesi(yeniWidget, yeniBolum),
      );
      void tercihTazele();
    } catch {
      // KAYDEDILEMEDIGINI SOYLE: sessizce yutmak, kullanicinin duzeni
      // kaydettigini sanip ertesi gun eski panoyu bulmasi demekti.
      toast.error(t("panoKaydedilemedi"));
    }
  }

  function widgetDegisti(yeni: string[]) {
    setWidgetlar(yeni);
    void duzeniKaydet(yeni, cizilecekBolumler);
  }

  function bolumTasi(i: number, yon: -1 | 1) {
    const j = i + yon;
    if (j < 0 || j >= cizilecekBolumler.length) return;
    const yeni = [...cizilecekBolumler];
    [yeni[i], yeni[j]] = [yeni[j], yeni[i]];
    setBolumler(yeni);
    void duzeniKaydet(seciliWidgetlar, yeni);
  }

  function bolumCevir(i: number) {
    const yeni = cizilecekBolumler.map((b, k) =>
      k === i ? { ...b, gizli: !b.gizli } : b,
    );
    setBolumler(yeni);
    void duzeniKaydet(seciliWidgetlar, yeni);
  }

  function varsayilanaDon() {
    const yeniBolum = bolumleriCoz(undefined);
    const yeniWidget = widgetlariCoz(undefined, izinliRotalar, varsayilanWidget);
    setBolumler(yeniBolum);
    setWidgetlar(yeniWidget);
    void duzeniKaydet(yeniWidget, yeniBolum);
    toast.success(t("panoKaydedildi"));
  }

  // ---------------------------------------------------------------- veri
  const gruplar: AlarmGrubu[] = useMemo(() => data?.alarm_gruplari ?? [], [data]);
  const kameralar: Kamera[] = useMemo(
    () => kameraYanit?.items ?? [],
    [kameraYanit],
  );

  // (P161) SAHNE VERISI — UYDURMA DEGIL, GERCEK UCLARDAN. Iki uc
  // birlestiriliyor: `/blocks` blogun RESMI listesidir (dairesi girilmemis
  // blok da orada), `building-map` ise dairelerin yerlesimi. Yalniz birine
  // bakmak, ya bos bloklari ya da blok kaydi olmayan daireleri sahneden
  // dusururdu.
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
          // DURUM YALNIZ VERININ TASIDIGI KADAR: `complaint_count` sunucu
          // tarafindan yonetim disi rollere `null` doner — o zaman renk de
          // yoktur, uydurulmaz.
          durum: (u.complaint_count ?? 0) > 0 ? DAIRE_ALARM : DAIRE_NORMAL,
        })),
      );

    const resmi = (blokYanit?.items ?? []).map((b) => ({
      id: b.ad,
      ad: b.ad,
      daireler: daireleriCikar(b.ad),
    }));
    const resmiAdlar = new Set(resmi.map((b) => b.ad));
    const artiklar = (binaHaritasi?.bloklar ?? [])
      .filter((b) => !resmiAdlar.has(b.blok))
      .map((b) => ({ id: b.blok, ad: b.blok, daireler: daireleriCikar(b.blok) }));
    return [...resmi, ...artiklar];
  }, [blokYanit, binaHaritasi]);

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
        sonuk: k.aktif === false,
      })),
    ],
    [gruplar, kameralar, t],
  );

  const tamamlanan = (data?.aktif_turlar ?? []).filter(
    (x) => x.durum === "tamamlandi",
  ).length;
  const gecikmeSayisi = gruplar.reduce((n, g) => n + g.sayi, 0);

  // KAHRAMAN: once SUREN tur; yoksa SIRADAKI bekleyen; o da yoksa bos durum.
  const turlar = data?.aktif_turlar ?? [];
  const simdi = data ? Date.parse(data.generated_at) : Date.now();
  const suren = turlar.find((x) => suruyor(x, simdi)) ?? null;
  const siradaki =
    suren ??
    turlar
      .filter((x) => x.durum === "bekliyor" && Date.parse(x.pencere_baslangic) > simdi)
      .sort((a, b) => Date.parse(a.pencere_baslangic) - Date.parse(b.pencere_baslangic))[0] ??
    null;

  // ---------------------------------------------------------------- cizim
  /** Bir bolumun govdesi. Sira ve gorunurluk KARARI disarida. */
  function bolumGovdesi(id: CozulmusBolum["id"]) {
    switch (id) {
      case "widgetlar":
        return (
          <WidgetSeridi
            adaylar={adaylar}
            secili={seciliWidgetlar}
            duzenlemede={duzenlemede}
            onDegisti={widgetDegisti}
          />
        );
      case "finans":
        return <PanoFinansOzeti />;
      case "maket":
        return (
          <div className="space-y-3">
            <Kart className="overflow-hidden">
              <BinaSahnesiYukleyici
                bloklar={sahneBloklari}
                isaretciler={sahneIsaretcileri}
                secim={secim}
                onSecim={setSecim}
                yukseklik="clamp(280px, 38vh, 440px)"
              />
            </Kart>
            <SahneSecimPaneli
              secim={secim}
              bloklar={sahneBloklari}
              onSecim={setSecim}
              onKapat={() => setSecim(BOS_SECIM)}
            />
          </div>
        );
      case "takvim":
        return <PanoTakvim />;
      case "devriye":
        // KAHRAMAN BLOK KORUNDU (bkz. `lib/pano-tercihi.ts`): brief'in
        // bolum listesinde yok ama GENEL KISITLAR "mevcut islev
        // kaybolmayacak" diyor. Artik oteki bolumlerle ayni kurala tabi.
        return isLoading && !data ? (
          <Yukleniyor satir={3} />
        ) : siradaki ? (
          // (P181 7.3) Düz cümle yerine GÖRSEL devriye bileşeni: ilerleme
          // halkası + tamamlanan/kalan nokta + son okutma zamanı.
          <DevriyeGorunumu tur={siradaki} suren={Boolean(suren)} />
        ) : (
          <BosDurum
            baslik={t("pano2HeroBosBaslik")}
            aciklama={t("pano2HeroBosAlt")}
          />
        );
      case "kpi":
        // (P160) KPI HALKALARI — SERT SINIR: en cok DORT.
        // Renk bir DURUM sinyalidir; besinci halka onu gurultuye cevirir.
        // Sinir yorumla degil TESTLE tutulur (`pano-tint-blok.dom`).
        return isLoading && !data ? (
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
              durum={KPI_BILGI}
              href="/patrol-plans"
            />
            <Kpi
              deger={tamamlanan}
              etiket={t("pano2BlokTamamlanan")}
              durum={KPI_OLUMLU}
              href="/reports/patrols"
            />
            {/* MALI HALKA YALNIZ YETKI VARSA: sunucu tahsilat oranini
                guvenlik rollerine `null` doner. "0%" cizmek, veriyi
                sizdirmadan YANLIS bilgi vermek olurdu. */}
            {data?.aidat_tahsilat_orani != null && (
              <Kpi
                deger={data.aidat_tahsilat_orani}
                bicimle={yuzde}
                etiket={t("pano2BlokTahsilat")}
                durum={
                  data.aidat_tahsilat_orani >= TAHSILAT_ESIGI
                    ? KPI_OLUMLU
                    : KPI_UYARI
                }
                href="/finans"
              />
            )}
          </div>
        );
      case "kameralar":
        return <KameraSeridi kameralar={kameralar} />;
      case "alarmlar":
        return isLoading && !data ? (
          <Yukleniyor satir={3} />
        ) : gruplar.length === 0 ? (
          <BosDurum baslik={t("pano2AlarmYokBaslik")} />
        ) : (
          <div className="space-y-2">
            {gruplar.map((g) => (
              <AlarmGrubuSatiri key={`${g.tip}-${g.patrol_plan_id ?? "-"}`} grup={g} />
            ))}
          </div>
        );
    }
  }

  /** Bolum baslik satiri + (duzenleme modunda) sira/gizle dugmeleri. */
  function bolumBasligi(b: CozulmusBolum, i: number) {
    // KENDI BASLIGINI CIZEN BOLUM: cerceve baslik EKLEMEZ. Aksi halde
    // kamera seridi bos oldugunda geriye bos bir "Kameralar" basligi
    // kalirdi — P132.4b'nin kaldirdigi tam olarak o.
    if (!duzenlemede) {
      return b.kendiBasligi ? null : <BolumBasligi baslik={t(b.anahtar)} />;
    }
    return (
      <div className="mb-2 flex flex-wrap items-center gap-2">
        <span style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t(b.anahtar)}
        </span>
        <Dugme tur="ikincil" boy="kucuk" onClick={() => bolumTasi(i, -1)}>
          {t("panoYukariTasi")}
        </Dugme>
        <Dugme tur="ikincil" boy="kucuk" onClick={() => bolumTasi(i, 1)}>
          {t("panoAsagiTasi")}
        </Dugme>
        <Dugme
          tur={b.gizli ? SECILI_TUR : SECILMEMIS_TUR}
          boy="kucuk"
          onClick={() => bolumCevir(i)}
        >
          {b.gizli ? t("panoBolumGoster") : t("panoBolumGizle")}
        </Dugme>
      </div>
    );
  }

  // YAN YANA CIZIM: ardisik iki YARIM bolum tek satiri paylasir. Duzen
  // TEK BOYUTLU bir liste olarak kaliyor — surukle-birak iki eksende
  // olsaydi hem kod hem klavye erisimi kat kat karmasiklasirdi.
  const satirlar: CozulmusBolum[][] = [];
  const gorunurler = duzenlemede
    ? cizilecekBolumler
    : cizilecekBolumler.filter((b) => !b.gizli);
  for (let i = 0; i < gorunurler.length; i++) {
    const b = gorunurler[i];
    const sonraki = gorunurler[i + 1];
    if (b.genislik === "yarim" && sonraki?.genislik === "yarim") {
      satirlar.push([b, sonraki]);
      i++;
    } else {
      satirlar.push([b]);
    }
  }

  return (
    <div className="space-y-bolum">
      <SayfaBasligi baslik={t("kabukOzet")} />

      {/* (P168 §1.3) DUZENLEME EYLEMLERI UST BARDA — bildirim ikonunun
          SOLUNDA. Kabuk bos bir yuva aciyor, sayfa kendi dugmesini oraya
          portal'liyor: kabuk hangi dugmenin gelecegini bilmiyor.
          "Varsayilana don" yalniz DUZENLEME KIPINDE cizilir; her zaman
          durursa, kazara tiklanabilecek yikici bir dugme ust barda
          surekli asili kalirdi. */}
      <SayfaEylemleri>
        {duzenlemede && (
          <Dugme tur="ikincil" boy="kucuk" onClick={varsayilanaDon}>
            {t("panoVarsayilanaDon")}
          </Dugme>
        )}
        <Dugme
          tur={duzenlemede ? SECILI_TUR : SECILMEMIS_TUR}
          boy="kucuk"
          onClick={() => setDuzenlemede((x) => !x)}
        >
          {duzenlemede ? t("panoDuzenlemeBitir") : t("panoDuzenle")}
        </Dugme>
      </SayfaEylemleri>

      {/* Hata KUTUSU canli bolgedir: pano 15 sn'de bir yenilenir. */}
      {error ? <HataDurumu mesaj={error.message} /> : null}

      {gorunurler.length === 0 ? (
        <BosDurum baslik={t("panoTumBolumlerGizli")} />
      ) : (
        satirlar.map((satir, si) => (
          <div
            key={satir.map((b) => b.id).join("-")}
            className={
              satir.length === 2 ? "grid gap-bolum lg:grid-cols-2" : undefined
            }
          >
            {satir.map((b) => (
              <section
                key={b.id}
                // GIZLI BOLUM DUZENLEME MODUNDA SOLUK CIZILIR, DOM'dan
                // silinmez: kullanici neyi geri acacagini gormeli.
                style={{ opacity: b.gizli ? 0.45 : 1 }}
              >
                {bolumBasligi(
                  b,
                  cizilecekBolumler.findIndex((x) => x.id === b.id),
                )}
                {bolumGovdesi(b.id)}
              </section>
            ))}
            {/* Tek yarim bolum kalirsa satirin ikinci hucresi bos kalir;
                `si` yalniz `key` benzersizligi icin okunuyor. */}
            {satir.length === 1 && si < 0 && <span />}
          </div>
        ))
      )}

    </div>
  );
}

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
