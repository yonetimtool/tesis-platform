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
import { useEffect, useMemo, useState, type DragEvent, type KeyboardEvent } from "react";
import Link from "next/link";
import useSWR from "swr";

import {
  BinaSahnesiYukleyici,
  useSahneOrtami,
} from "@/components/3d/sahne-yukleyici";
import { durumRenkleri } from "@/components/3d/site-palet";
import { DevriyeGorunumu } from "@/components/DevriyeGorunumu";
import type { SahneBlogu, SahneSecimi } from "@/components/3d/bina-sahnesi";
import {
  BolumBasligi,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletKpi,
  IskeletMetin,
  Kart,
  Kpi,
  OzetKarti,
  OzetSeridi,
  Rozet,
  SayfaBasligi,
  type RozetDurumu,
} from "@/components/ui";
import { KahramanBandi } from "@/components/pano/kahraman-bandi";
import { PanoFinansOzeti } from "@/components/pano/finans-ozeti";
import { PanoTakvim } from "@/components/pano/takvim";
import { WidgetSeridi, type WidgetAdayi } from "@/components/pano/widget-seridi";
import { SayfaEylemleri } from "@/components/SayfaEylemleri";
import { useToast } from "@/components/Toast";
import { KameraSeridi } from "@/components/KameraSeridi";
import { apiSend } from "@/lib/client";
import { BILDIRIM_TIP, enumAdi } from "@/lib/enum-adlari";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useI18n, useT } from "@/lib/i18n/kullan";
import { menuGruplari, ogeBaglantisi } from "@/lib/menu";
import {
  bolumleriCoz,
  bolumOkTasi,
  bolumSurukleBirak,
  satirlariCoz,
  tercihGovdesi,
  varsayilanSatirlar,
  widgetlariCoz,
  type BolumYon,
  type CozulmusBolum,
  type CozulmusSatir,
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

/**
 * Alarm ONEMI -> rozet durumu (renk token'da, anlam burada).
 *
 * (P244 §4) DEGERLER RENK ADI OLMAKTAN CIKTI: eski dilde `"red"` /
 * `"orange"` yaziyordu, yani anlam RENGIN ADINDA sakliydi. Yeni katmanda
 * ad ANLAM tasir ve ayni sozluk `Rozet`, `IkonKutu`, `OzetKarti`da
 * gecerlidir.
 */
const ONEM_VURGU: Record<string, RozetDurumu> = {
  yuksek: "kritik",
  orta: "uyari",
  dusuk: "bilgi",
};

// (P244 §5) OZET KARTI IKONLARI — tek cizim dili, tek boyut.
// Yollar SABIT DEGISKENDE: uclude dize yazmak `sabit-metin` taramasini
// (hakli olarak) tetikler ve o tarama CSS/SVG ile cumleyi ayirt edemez.
const IKON_UYARI = "M12 4 3 19h18L12 4ZM12 10v4M12 17h.01";
const IKON_TUR = "M12 3a9 9 0 1 0 9 9M12 3v9l6 3";
const IKON_BINA = "M4 20V6a1 1 0 0 1 1-1h7a1 1 0 0 1 1 1v14M13 20V10h6a1 1 0 0 1 1 1v9M3 20h18";
const IKON_PARA = "M12 3v18M16 7.5C16 6 14.2 5 12 5S8 6 8 7.5 9.8 10 12 10s4 1 4 2.5S14.2 15 12 15s-4-1-4-2.5";
const IKON_TALEP = "M5 5h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H9l-4 4v-4H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z";

function OzetIkonu({ yol }: { yol: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-5 w-5"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={yol} />
    </svg>
  );
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DAIRE_NORMAL = "normal" as const;
const DAIRE_ALARM = "alarm" as const;
const BOS_SECIM: SahneSecimi = { blokId: null, kat: null, daireId: null };

/**
 * (P244 §5) MAKET EFSANESI — YALNIZ BU SAYFADA GERCEKTEN CIZILEN durumlar.
 *
 * OLCULDU: `DaireDurumu` dort deger tasiyor (`normal`/`borclu`/`alarm`/
 * `pasif`) ama BU SAYFA yalniz ikisini uretiyor — daire `complaint_count`
 * > 0 ise `alarm`, degilse `normal` (bkz. `sahneBloklari`). Dort durumlu
 * bir efsane, hicbir zaman cizilmeyecek iki renk ilan ederdi.
 *
 * RENKLER SAHNENIN PALETINDEN OKUNUR, burada yeniden TANIMLANMAZ: iki
 * yerde iki hex tutmak, tema degisince efsanenin maketi YANLIS anlatmasi
 * demekti.
 */
const MAKET_EFSANESI = [
  { anahtar: "maketDurumNormal" as const, durum: DAIRE_NORMAL },
  { anahtar: "maketDurumAlarm" as const, durum: DAIRE_ALARM },
];

const SECILI_TUR = "birincil" as const;
const SECILMEMIS_TUR = "ikincil" as const;

// (P181 7.1) Satır sütun sayısı → Tailwind ızgara sınıfı. Sınıflar SABİT
// (JIT dinamik `grid-cols-${n}` üretemez); mobilde tek sütun, geniş ekranda açılır.
const SUTUN_SINIF: Record<number, string> = {
  1: "",
  2: "grid gap-bolum lg:grid-cols-2",
  3: "grid gap-bolum md:grid-cols-2 lg:grid-cols-3",
  4: "grid gap-bolum md:grid-cols-2 lg:grid-cols-4",
};
// (P184 §11) SURUKLE-BIRAK hedef isareti. Onceki SOLUK KESIK cerceve yerine
// bir bolumun ONUNE kalin accent EKLEME CIZGISI cizilir (nereye dusecegi net).
// Modul sabiti: style icinde ternary metin birakmak sabit-metin tarayicisini
// (tur 47) tetikler.
const EKLEME_CIZGISI = {
  outline: "0",
  boxShadow: "-6px 0 0 -2px var(--yz-accent-edge)",
} as const;
// (P182 §4) Klavye ok tuslari -> bolum tasima yonu. Lookup tablosu (ternary
// degil) ki BolumYon degerleri sabit-metin tarayicisina "gorunen metin" gibi
// gelmesin.
const OK_YON: Record<string, BolumYon | undefined> = {
  ArrowLeft: "sol",
  ArrowRight: "sag",
  ArrowUp: "yukari",
  ArrowDown: "asagi",
};
/** Bolum gorunurlugunu cevirirken kart etiketi (duzenleme modu). */
const ETIKET_DIV = "div" as const;
// (P184 §11) OZEL BIRAK HEDEFLERI — bolum kimlikleriyle carpismaz ("bolum:"
// onekli olmadiklari ve gercek bolum idlerinden ayri oldugu icin).
const HEDEF_TEPSI = "__tepsi__" as const;
const HEDEF_TUVAL = "__tuval__" as const;
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
  // (P182 §4 / P184 §11) SURUKLE-BIRAK: `surukleId` tutulan bolum; `birakVurgu`
  // uzerine gelinen birakma hedefi (gorsel isaret). Kimlikle calisir (bolum id
  // benzersiz); ozel hedefler: `TEPSI` (gizli tepsisi), `TUVAL` (gorunur alan).
  // Kayit yalniz BIRAKMADA olur (her dragover'da degil).
  const [surukleId, setSurukleId] = useState<string | null>(null);
  const [birakVurgu, setBirakVurgu] = useState<string | null>(null);
  // (P184 §11) ANLIK "Kaydedildi" isareti: kayit tuttugunda kisa sure gorunur,
  // sonra kendiliginden solar. Ayri bir "Kaydet" adimi olmadigi icin kullanici
  // degisikligin gittigini boyle gorur (hata yolu yine toast).
  const [kaydedildiIsareti, setKaydedildiIsareti] = useState(false);

  // (P181 Bölüm 10.5) YOKLAMA: 15 sn aralık YETERLİ. `revalidateOnFocus`
  // KAPALI — her sekmeye dönüşte ek bir istek, 15 sn'lik tazeliğe hiçbir şey
  // katmadan gereksiz tekrar üretir (odak/blur hızlı değişince patlama olur).
  // `refreshInterval` sekme GİZLİYKEN zaten durur (SWR varsayılanı
  // `refreshWhenHidden:false`) — "sayfa görünmezken yoklamayı durdur" sağlanır.
  const { data, error, isLoading } = useSWR<DashboardLive>(
    "/api/dashboard/live",
    jsonFetcher,
    { refreshInterval: 15000, revalidateOnFocus: false },
  );
  // (P213 §4) OZETTE YALNIZ "ANA EKRANDA GOSTER" ISARETLI KAMERALAR.
  //
  // Eskiden ilk 50 kamera cekilip ilk 4'u ciziliyordu — yani hangi
  // kameranin ozette gorunecegine ALFABETIK SIRA karar veriyordu.
  // Artik karar YONETICININ (`ana_ekranda` bayragi) ve sunucu sinirli
  // sayida kamerada aciyor (her kare bir ffmpeg sureci).
  //
  // Isaretli kamera yoksa liste BOS gelir ve serit HIC cizilmez.
  const { data: kameraYanit } = useSWR<KameraListResponse>(
    "/api/cameras?ana_ekranda=true&limit=10&offset=0",
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
  // (P222 §1) SIKAYET HARITASI ROZETI — MOBIL IZGARAYLA AYNI SAYI.
  //
  // Mobilde olculen kusur: izgara karosu `/unit-complaints?durum=acik`in
  // `meta.total` degerini okuyordu ve o LISTE ucu `sikayet_harita_saat`
  // penceresini UYGULAMAZ; karo "5 Acik" derken dokununca acilan harita
  // 0 gosterebiliyordu. Web'de o gune kadar rozet HIC YOKTU — yani ayni
  // kusur degil, EKSIK bir yuzey vardi. Ikisi de ayni uctan besleniyor.
  const { data: gorunurSikayet } = useSWR<{ acik_sayisi: number }>(
    "/api/unit-complaints/gorunur-sayi",
    jsonFetcher,
  );

  const adaylar: WidgetAdayi[] = useMemo(() => {
    return menuGruplari("tesis", rol).flatMap((g) =>
      g.ogeler.map((o) => {
        const rota = ogeBaglantisi(o);
        return {
          rota,
          etiket: t(o.anahtar),
          bolum: t(g.anahtar),
          ikon: <Ikon d={YOL.tur} />,
          // Rozet UYDURULMAZ: sayi elimizde yoksa (yukleniyor, hata,
          // yetkisiz) alan HIC KONMAZ ve serit rozetsiz cizilir.
          ...(rota === "/schematic" && typeof gorunurSikayet?.acik_sayisi === "number"
            ? { rozet: gorunurSikayet.acik_sayisi }
            : {}),
        };
      }),
    );
  }, [rol, t, gorunurSikayet]);

  const izinliRotalar = useMemo(() => adaylar.map((a) => a.rota), [adaylar]);

  // VARSAYILAN KISAYOLLAR: yoneticinin gunluk baktigi ilk alti ekran.
  // Sunucuda TUTULMAZ — orada hesaplamak, ayni karari menuden sonra
  // ikinci bir yerde daha vermek olurdu (bkz. `/me/pano-tercihi` notu).
  // VARSAYILAN KISAYOLLAR: yoneticinin gunluk baktigi ilk alti ekran.
  // Sunucuda TUTULMAZ — orada hesaplamak, ayni karari menuden sonra
  // ikinci bir yerde daha vermek olurdu (bkz. `/me/pano-tercihi` notu).
  //
  // (P222 §1) `/schematic` BILEREK EKLENMEDI: `WIDGET_SINIRI` 6 ve yedinci
  // giris sessizce `/olaylar`i dusururdu. Hangi kisayolun varsayilandan
  // cikacagi bir URUN KARARIDIR, yan etki olarak verilmez. Sikayet rozeti
  // `/schematic` widget'ini SECEN kullanicida gorunur.
  const varsayilanWidget = useMemo(
    () => ["/dues", "/finans", "/tasks", "/complaints", "/units", "/olaylar"],
    [],
  );

  const [widgetlar, setWidgetlar] = useState<string[] | null>(null);
  // (P181 7.1/7.2) YERLEŞİM SATIR BAZLI: her satır 1-4 sütun + opsiyonel banner.
  const [satirlarState, setSatirlar] = useState<CozulmusSatir[] | null>(null);

  // SUNUCUDAN GELEN KAYIT DURUMA BIR KEZ yuklenir; kullanici duzenlerken
  // SWR tazelemesi yazdigini EZMESIN (profil formundaki desenin aynisi).
  useEffect(() => {
    if (tercih === undefined) return;
    setWidgetlar(widgetlariCoz(tercih, izinliRotalar, varsayilanWidget));
    setSatirlar(satirlariCoz(tercih, bolumleriCoz(tercih)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tercih === undefined]);

  const seciliWidgetlar = widgetlar ?? [];
  const cizilenSatirlar = satirlarState ?? satirlariCoz(tercih, bolumleriCoz(tercih));
  const cizilecekBolumler = cizilenSatirlar.flatMap((s) => s.bolumler);

  async function duzeniKaydet(
    yeniWidget: readonly string[],
    yeniSatir: readonly CozulmusSatir[],
  ): Promise<boolean> {
    try {
      await apiSend(
        "/api/me/pano-tercihi",
        "PUT",
        tercihGovdesi(yeniWidget, yeniSatir.flatMap((s) => s.bolumler), yeniSatir),
      );
      void tercihTazele();
      // (P184 §11) ANLIK KAYIT ISARETI: kayit tuttu, kisa sure goster ve sol.
      setKaydedildiIsareti(true);
      window.setTimeout(() => setKaydedildiIsareti(false), 1800);
      return true;
    } catch {
      // KAYDEDILEMEDIGINI SOYLE: sessizce yutmak, kullanicinin duzeni
      // kaydettigini sanip ertesi gun eski panoyu bulmasi demekti. (P182 §2)
      // Donus `false` — cagiran BASARI mesajini ancak buradan `true` gelirse
      // gostersin (yoksa kayit patlarken "kaydedildi" yaziliyordu).
      toast.error(t("panoKaydedilemedi"));
      return false;
    }
  }

  function satirlariUygula(yeni: CozulmusSatir[]) {
    setSatirlar(yeni);
    void duzeniKaydet(seciliWidgetlar, yeni);
  }

  function widgetDegisti(yeni: string[]) {
    setWidgetlar(yeni);
    void duzeniKaydet(yeni, cizilenSatirlar);
  }

  // (P182 §4) KLAVYE ile bölüm taşıma (sürükle-bırak'ın erişilebilir eşi).
  // Mantık `bolumOkTasi`de (saf, test edilmiş); burada yalnız ok tuşu -> yön.
  function bolumKlavye(si: number, bi: number, e: KeyboardEvent) {
    const yon = OK_YON[e.key];
    if (!yon) return;
    e.preventDefault();
    satirlariUygula(bolumOkTasi(cizilenSatirlar, si, bi, yon));
  }
  // (P184 §11) Bir bolumun `gizli` bayragini kimlikle ayarlar. Bolum SATIRDA
  // KALIR (sira/konum korunur, tercihGovdesi ayni idler listesini yazar); tuval
  // gizli olmayanlari cizer, tepsi gizli olanlari. Boylece "gizle" tek yerde
  // durumu cevirir, ayri bir liste tutulmaz.
  function gizliAyarla(satirlar: readonly CozulmusSatir[], id: string, gizli: boolean) {
    return satirlar.map((s) => ({
      ...s,
      bolumler: s.bolumler.map((b) => (b.id === id ? { ...b, gizli } : b)),
    }));
  }
  // (P184 §11) SÜRÜKLE-BIRAK bırakma. TEK ETKILESIM: kullanici bir bolumu ya
  // baska bir bolumun ONUNE (yeniden sirala) ya GIZLI TEPSISINE (gizle) ya da
  // TUVALE (tepsiden geri getir) birakir. Tepsiden gelen bir bolum tuvale ya da
  // bir bolumun onune birakildiginda gizliligi de KALKAR — tek surukleyle hem
  // geri gelir hem yerine oturur.
  function bolumBirak(
    hedef:
      | { tip: "once"; id: string }
      | { tip: "tepsi" }
      | { tip: "tuval" },
  ) {
    const kaynak = surukleId;
    setSurukleId(null);
    setBirakVurgu(null);
    if (!kaynak) return;
    if (hedef.tip === "tepsi") {
      satirlariUygula(gizliAyarla(cizilenSatirlar, kaynak, true));
      return;
    }
    // "once" ve "tuval": bolum GORUNUR olur; ardindan yeniden siralanir.
    const gorunur = gizliAyarla(cizilenSatirlar, kaynak, false);
    if (hedef.tip === "once") {
      satirlariUygula(bolumSurukleBirak(gorunur, kaynak, hedef));
    } else {
      // Tuvale (bos alan/gorunur bolgeye) birakma = gizliligi kaldirmak yeterli;
      // bolum kayitli sirasinda gorunur hale gelir.
      satirlariUygula(gorunur);
    }
  }

  async function varsayilanaDon() {
    const yeniSatir = varsayilanSatirlar(bolumleriCoz(undefined));
    const yeniWidget = widgetlariCoz(undefined, izinliRotalar, varsayilanWidget);
    setSatirlar(yeniSatir);
    setWidgetlar(yeniWidget);
    // (P182 §2) BASARI mesaji YALNIZ kayit gercekten tuttuysa: eskiden
    // `void ...` + hemen `toast.success` kayit patlasa da "kaydedildi" diyordu.
    if (await duzeniKaydet(yeniWidget, yeniSatir)) {
      toast.success(t("panoKaydedildi"));
    }
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

  // (P184-ek duzeltme §2) 3D MAKET ISARETCILERI KALDIRILDI: kamera + kacirilan
  // devriye noktalari maketten cikarildi. Bilgi zaten kamera seridi, alarmlar
  // bolumu ve devriye gorunumunde var. `kameralar`/`gruplar` DURUYOR (o
  // widget'lar kullaniyor); yalniz maket ustundeki isaretci kumesi silindi.

  const tamamlanan = (data?.aktif_turlar ?? []).filter(
    (x) => x.durum === "tamamlandi",
  ).length;
  const gecikmeSayisi = gruplar.reduce((n, g) => n + g.sayi, 0);
  // (P244 §5) OZET KARTLARI ICIN TURETILEN SAYILAR.
  // HEPSI SAYFADA ZATEN CEKILEN kayitlardan geliyor — yeni uc YOK.
  const daireSayisi = (binaHaritasi?.bloklar ?? []).reduce(
    (n, b) => n + (b.katlar ?? []).reduce((m, k) => m + (k.units?.length ?? 0), 0),
    0,
  );
  const blokSayisi = (binaHaritasi?.bloklar ?? []).length;
  const acikTalep = gorunurSikayet?.acik_sayisi ?? null;
  // EFSANE RENKLERI SAHNEYLE AYNI KAYNAKTAN (bkz. `MAKET_EFSANESI`).
  const { koyu: sahneKoyu } = useSahneOrtami();
  const sahneRenkleri = durumRenkleri(sahneKoyu);

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
        // (P244 §5) SAHNE AYNEN KORUNDU — CERCEVESI YENILENDI.
        // Karar 6: "etkilesim aynen kalsin, cevresi yenilensin".
        // `BinaSahnesiYukleyici`, `sahneBloklari`, `secim` ve secim paneli
        // TEK SATIR degismedi; eklenen sey referanstaki cerceve: kart
        // basligi, aciklama ve durum efsanesi.
        return (
          <div className="space-y-3">
            <Kart className="overflow-hidden" dolgu={false}>
              <div
                className="border-b px-4 py-3"
                style={{
                  borderColor: "var(--yz-border)",
                  borderBottomWidth: "var(--yz-border-w)",
                }}
              >
                <p style={{ fontSize: "var(--yz-fs-h3)", fontWeight: 600, color: "var(--yz-text)" }}>
                  {t("panoBolumMaket")}
                </p>
                <p className="mt-0.5" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {t("panoMaketAlt")}
                </p>
              </div>
              <BinaSahnesiYukleyici
                bloklar={sahneBloklari}
                secim={secim}
                onSecim={setSecim}
                yukseklik="clamp(280px, 38vh, 440px)"
              />
              {/* EFSANE: referansta maketin altinda duran durum serisi.
                  RENK TEK TASIYICI DEGIL — her cipin yaninda ADI yaziyor. */}
              <div
                className="flex flex-wrap items-center gap-x-4 gap-y-1.5 border-t px-4 py-2.5"
                style={{
                  borderColor: "var(--yz-border)",
                  borderTopWidth: "var(--yz-border-w)",
                  fontSize: "var(--yz-fs-xs)",
                  color: "var(--yz-text-2)",
                }}
              >
                {MAKET_EFSANESI.map((e) => (
                  <span key={e.anahtar} className="inline-flex items-center gap-1.5">
                    <span
                      aria-hidden="true"
                      className="inline-block h-2 w-2 rounded-full"
                      style={{ background: sahneRenkleri[e.durum] }}
                    />
                    {t(e.anahtar)}
                  </span>
                ))}
              </div>
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
          <IskeletMetin satir={3} />
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
        // (P244 §5) HALKA -> OZET KARTI SERIDI.
        // -----------------------------------------------------------------
        // Halka (`Kpi`) 116 px'lik bir cemberdi ve YALNIZ bir sayi
        // tasiyordu. Referansin karti ayni yerde daha cok sey soyluyor:
        // etiket, buyuk sayi ve BIR ALT SATIR baglam ("12 dairede borç
        // var" gibi). Olculen sikayet "sayfalar bos gorunuyor"du; ayni
        // alanda uc kat bilgi tasimak bunun dogrudan karsiligi.
        //
        // SERT SINIR KALKTI, YERINE OLCU GELDI: eski kural "en cok dort
        // halka"ydi cunku renkli cemberler besincide gurultuye
        // donusuyordu. Kart dili renkle degil TIPOGRAFIYLE calisir;
        // serit `auto-fit` ile dizilir ve kac kart olursa olsun ayni
        // ritmi korur.
        //
        // VERI KAYNAGI DEGISMEDI: hicbir yeni uc cagrilmiyor, sayfada
        // ZATEN cekilen kayitlar kullaniliyor.
        return isLoading && !data ? (
          <IskeletKpi adet={4} />
        ) : (
          <OzetSeridi>
            <OzetKarti
              etiket={t("pano2BlokGecikme")}
              deger={String(gecikmeSayisi)}
              durum={gecikmeSayisi ? "kritik" : "olumlu"}
              ikon={<OzetIkonu yol={IKON_UYARI} />}
              altBilgi={gecikmeSayisi ? t("panoKpiGecikmeAlt") : t("panoKpiGecikmeYok")}
              href="/notifications"
            />
            <OzetKarti
              etiket={t("pano2BlokTur")}
              deger={String(turlar.length)}
              durum="bilgi"
              ikon={<OzetIkonu yol={IKON_TUR} />}
              altBilgi={t("panoKpiTurAlt", { n: tamamlanan })}
              href="/patrol-plans"
            />
            {daireSayisi > 0 && (
              <OzetKarti
                etiket={t("panoKpiDaire")}
                deger={String(daireSayisi)}
                durum="notr"
                ikon={<OzetIkonu yol={IKON_BINA} />}
                altBilgi={t("panoKpiDaireAlt", { n: blokSayisi })}
                href="/units"
              />
            )}
            {/* MALI KART YALNIZ YETKI VARSA: sunucu tahsilat oranini
                guvenlik rollerine `null` doner. "%0" cizmek, veriyi
                sizdirmadan YANLIS bilgi vermek olurdu. */}
            {data?.aidat_tahsilat_orani != null && (
              <OzetKarti
                etiket={t("pano2BlokTahsilat")}
                deger={yuzde(data.aidat_tahsilat_orani)}
                durum={
                  data.aidat_tahsilat_orani >= TAHSILAT_ESIGI ? "olumlu" : "uyari"
                }
                ikon={<OzetIkonu yol={IKON_PARA} />}
                href="/finans"
              />
            )}
            {acikTalep != null && (
              <OzetKarti
                etiket={t("panoKpiTalep")}
                deger={String(acikTalep)}
                durum={acikTalep > 0 ? "uyari" : "olumlu"}
                ikon={<OzetIkonu yol={IKON_TALEP} />}
                href="/complaints"
              />
            )}
          </OzetSeridi>
        );
      case "kameralar":
        return <KameraSeridi kameralar={kameralar} rol={rol} />;
      case "alarmlar":
        return isLoading && !data ? (
          <IskeletMetin satir={3} />
        ) : gruplar.length === 0 ? (
          <BosDurum baslik={t("pano2AlarmYokBaslik")} aciklama={t("pano2AlarmYokBaslikAlt")} />
        ) : (
          <div className="space-y-2">
            {gruplar.map((g) => (
              <AlarmGrubuSatiri key={`${g.tip}-${g.patrol_plan_id ?? "-"}`} grup={g} />
            ))}
          </div>
        );
    }
  }

  /** Bolum baslik satiri + (duzenleme modunda) SURUKLE tutamaci + gizle. */
  function bolumBasligi(b: CozulmusBolum, si: number, bi: number) {
    // KENDI BASLIGINI CIZEN BOLUM: cerceve baslik EKLEMEZ. Aksi halde
    // kamera seridi bos oldugunda geriye bos bir "Kameralar" basligi
    // kalirdi — P132.4b'nin kaldirdigi tam olarak o.
    if (!duzenlemede) {
      return b.kendiBasligi ? null : <BolumBasligi baslik={t(b.anahtar)} />;
    }
    // (P184 §11) SIRALAMA TEK ETKILESIM: SURUKLE tutamaci. Sutun/banner/tasima
    // dugmeleri ve gizle dugmesi KALDIRILDI (gizleme artik tepsiye surukleyerek).
    // Tutamac hem surukle hem ok tuslariyla calisir (erisilebilirlik). Baslik
    // token agirliginda (text-bolum/700) — bolumler arasi hiyerarsi netlesir.
    const tutuluyor = surukleId === b.id;
    return (
      <div className="mb-kart flex items-center gap-2">
        <button
          type="button"
          draggable
          onDragStart={() => setSurukleId(b.id)}
          onDragEnd={() => {
            setSurukleId(null);
            setBirakVurgu(null);
          }}
          onKeyDown={(e) => bolumKlavye(si, bi, e)}
          aria-label={t("panoTasiTut", { ad: t(b.anahtar) })}
          title={t("panoTasiTut", { ad: t(b.anahtar) })}
          className="odak-ic yz-dokunma-48 flex h-11 w-11 shrink-0 items-center justify-center rounded-btn border"
          style={{
            cursor: "grab",
            fontSize: "var(--yz-fs-h2)",
            color: "var(--yz-text-2)",
            borderColor: "var(--yz-border)",
            background: "var(--yz-surface-1)",
            opacity: tutuluyor ? 0.4 : 1,
          }}
        >
          ⠿
        </button>
        <span className="text-bolum text-metin-heading">{t(b.anahtar)}</span>
      </div>
    );
  }

  // (P184 §11) TUVAL = gorunur (gizli olmayan) bolumler. Duzenleme modunda da
  // yalniz gorunurler cizilir; GIZLILER TEPSIDE durur (asagida). Sira/konum
  // model icinde korunur — gizli bolum satirdan silinmez, yalniz tuvalden
  // suzulur.
  const gorunurSatirlar = cizilenSatirlar
    .map((s) => ({ ...s, bolumler: s.bolumler.filter((b) => !b.gizli) }))
    .filter((s) => s.bolumler.length > 0);
  // (P184 §11) GIZLI bolumler duz liste — tepside cizilir, tekrar tuvale
  // surukleyerek geri acilir. Satir icindeki orijinal (si,bi) konumu klavye
  // tasima icin tasinir.
  const gizliBolumler = cizilenSatirlar.flatMap((s, si) =>
    s.bolumler
      .map((b, bi) => ({ b, si, bi }))
      .filter((x) => x.b.gizli),
  );

  return (
    <div className="space-y-bolum">
      {/* (P244 §5) SAYFA BASLIGI YERINE KAHRAMAN BANDI.
          Baslik yalniz sayfanin ADINI tekrarliyordu ve baska bir sey
          soylemiyordu. Bant ayni yerde uc soruyu birden yanitliyor:
          kimim, hangi sitedeyim, bugun ne gun (ve hava).
          Bant bir BOLUM DEGIL: gizlenebilir bir karsilama satiri,
          sayfanin neresi oldugunu gizlenebilir yapardi. */}
      <KahramanBandi />

      {/* (P168 §1.3) DUZENLEME EYLEMLERI UST BARDA — bildirim ikonunun
          SOLUNDA. Kabuk bos bir yuva aciyor, sayfa kendi dugmesini oraya
          portal'liyor: kabuk hangi dugmenin gelecegini bilmiyor.
          "Varsayilana don" yalniz DUZENLEME KIPINDE cizilir; her zaman
          durursa, kazara tiklanabilecek yikici bir dugme ust barda
          surekli asili kalirdi. */}
      <SayfaEylemleri>
        {/* (P184 §11) ANLIK "Kaydedildi" isareti — ayri bir Kaydet adimi YOK,
            her degisiklik otomatik gider; bu cip kullaniciya gittigini soyler
            ve kendiliginden solar. Hata yolu ayri (toast). */}
        {kaydedildiIsareti && (
          <span
            aria-live="polite"
            className="inline-flex items-center gap-1 rounded-chip px-2 py-0.5 text-chip"
            style={{
              // (§11 düzeltme) `--yz-success-tint` tanımsızdı (tasarım-token
              // kilidi). Tanımlı yüzey + başarı-mürekkebi ile aynı his.
              background: "var(--yz-surface-2)",
              color: "var(--yz-success-ink)",
            }}
          >
            {t("panoKaydedildiKisa")}
          </span>
        )}
        {duzenlemede && (
          <Dugme tur="ikincil" boy="kucuk" onClick={() => void varsayilanaDon()}>
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

      {/* (P184 §11) DUZENLEME IPUCU — tek etkilesim (surukle) acikca anlatilir;
          onceki kalabalik kontrol cubugu yerine tek satirlik yonlendirme. */}
      {duzenlemede && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("panoDuzenleIpucu")}
        </p>
      )}

      {/* (P184 §11) TUVAL = gorunur bolumler. Duzenleme modunda tuvalin BOSTA
          KALAN alanina birakmak, tepsiden gelen bir bolumu geri getirir (gizli
          bayragini kaldirir). Normal modda hicbir surukle davranisi baglanmaz. */}
      {gorunurSatirlar.length === 0 && !duzenlemede ? (
        <BosDurum baslik={t("panoTumBolumlerGizli")} aciklama={t("panoTumBolumlerGizliAlt")} />
      ) : (
        <div
          className="space-y-bolum"
          {...(duzenlemede
            ? {
                onDragOver: (e: DragEvent) => {
                  e.preventDefault();
                  // Yalniz TUVALIN kendi bos alani (bir bolum degil): hedefi
                  // yalniz tuval hedefi degilse kaydirma, bolum onceligi kalsin.
                  if (e.target === e.currentTarget) setBirakVurgu(HEDEF_TUVAL);
                },
                onDrop: (e: DragEvent) => {
                  if (e.target !== e.currentTarget) return;
                  e.preventDefault();
                  bolumBirak({ tip: "tuval" });
                },
              }
            : {})}
        >
          {gorunurSatirlar.map((satir, si) => (
            <div key={si} className={SUTUN_SINIF[satir.sutun] ?? SUTUN_SINIF[1]}>
              {satir.bolumler.map((b, bi) => {
                // (P184 §11) Bu bolum SU AN birakma hedefi mi (ve tutulan
                // bolumun kendisi DEGIL mi)? Oyleyse ONUNE kalin accent ekleme
                // cizgisi cizilir — kesik soluk cerceve yerine net isaret.
                const hedefte =
                  duzenlemede && birakVurgu === b.id && surukleId !== b.id;
                return (
                  <section
                    key={b.id}
                    {...(duzenlemede
                      ? {
                          onDragOver: (e: DragEvent) => {
                            e.preventDefault();
                            e.stopPropagation();
                            setBirakVurgu(b.id);
                          },
                          onDragLeave: () =>
                            setBirakVurgu((v) => (v === b.id ? null : v)),
                          onDrop: (e: DragEvent) => {
                            e.preventDefault();
                            e.stopPropagation();
                            bolumBirak({ tip: "once", id: b.id });
                          },
                        }
                      : {})}
                    style={hedefte ? EKLEME_CIZGISI : undefined}
                  >
                    {bolumBasligi(b, si, bi)}
                    {bolumGovdesi(b.id)}
                  </section>
                );
              })}
            </div>
          ))}
        </div>
      )}

      {/* (P184 §11) GIZLI BOLUMLER TEPSISI — gizle/goster dugmelerinin yerine.
          Bir bolumu buraya surukleyince gizlenir; tepsideki bir bolumu tuvale
          geri surukleyince gorunur olur. YALNIZ duzenleme modunda cizilir. */}
      {duzenlemede && (
        <div
          onDragOver={(e) => {
            e.preventDefault();
            setBirakVurgu(HEDEF_TEPSI);
          }}
          onDragLeave={() =>
            setBirakVurgu((v) => (v === HEDEF_TEPSI ? null : v))
          }
          onDrop={(e) => {
            e.preventDefault();
            bolumBirak({ tip: "tepsi" });
          }}
          className="rounded-kart border-2 border-dashed p-kart"
          style={{
            borderColor:
              birakVurgu === HEDEF_TEPSI
                ? "var(--yz-accent-edge)"
                : "var(--yz-border)",
            background:
              birakVurgu === HEDEF_TEPSI
                ? "var(--yz-surface-2)"
                : "var(--yz-surface-1)",
          }}
        >
          <div className="mb-kart flex items-center gap-2">
            <span className="text-bolum text-metin-heading">
              {t("panoGizliBolumler")}
            </span>
          </div>
          {gizliBolumler.length === 0 ? (
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
              {t("panoGizliBolumYok")}
            </p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {gizliBolumler.map(({ b, si, bi }) => {
                const tutuluyor = surukleId === b.id;
                return (
                  <button
                    key={b.id}
                    type="button"
                    draggable
                    onDragStart={() => setSurukleId(b.id)}
                    onDragEnd={() => {
                      setSurukleId(null);
                      setBirakVurgu(null);
                    }}
                    onKeyDown={(e) => bolumKlavye(si, bi, e)}
                    aria-label={t("panoTasiTut", { ad: t(b.anahtar) })}
                    title={t("panoTasiTut", { ad: t(b.anahtar) })}
                    className="odak-ic yz-dokunma-48 inline-flex items-center gap-2 rounded-btn border px-kart py-2"
                    style={{
                      cursor: "grab",
                      borderColor: "var(--yz-border)",
                      background: "var(--yz-surface-2)",
                      color: "var(--yz-text-2)",
                      fontSize: "var(--yz-fs-sm)",
                      opacity: tutuluyor ? 0.4 : 1,
                    }}
                  >
                    <span aria-hidden="true">⠿</span>
                    {t(b.anahtar)}
                  </button>
                );
              })}
            </div>
          )}
        </div>
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
          <Rozet durum={vurgu}>{t("pano2AlarmSayi", { sayi: grup.sayi })}</Rozet>
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
