"use client";

import { useState, type ReactNode } from "react";
import useSWR from "swr";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;

import {
  Kart,
  Secim,
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  useOnay,
} from "@/components/ui";
import { Liste } from "@/components/Liste";
import { TelefonAlani, telefonHataMetni } from "@/components/TelefonAlani";
import { Modal, ModalEylemler } from "@/components/Modal";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, kurusToTLSade, tlToKurus } from "@/lib/money";
import { sayiCoz } from "@/lib/sayi";
import { telefonGiris, telefonNormalle } from "@/lib/telefon";
import { useSorguSecimi } from "@/lib/sorgu-secimi";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * P27 "Tanimlar" — dokuz kayit defteri TEK sayfada, sekmeli.
 *
 * NEDEN TEK SAYFA: bunlarin hepsi site KURULUM adimidir ve kullanici art
 * arda doldurur; menuye dokuz ayri giris koymak, kabugu tanimlarla
 * doldurup gunluk kullanilan sayfalari (aidat, talepler) asagi iterdi.
 *
 * NEDEN VERI-SURUCULU: dokuz defter icin dokuz form bileseni yazmak ayni
 * kodu dokuz kez kopyalamak olurdu. Her defter bir ALAN TANIMI listesiyle
 * anlatilir; tablo ve form bundan uretilir.
 */

// (P166 §9) `telefon` AYRI BIR TIP. Once `metin`di ve personel/firma
// defterlerinde kullanici sinirsiz rakam yazabiliyordu — Kerem'in
// bildirdigi kusur buydu. Tip olunca bicimleme, uzunluk siniri, klavye
// ve hata metni ORTAK BILESENDEN gelir; defter tanimina tek kelime
// yazmak yetiyor.
type AlanTip =
  | "metin"
  | "telefon"
  | "sayi"
  | "kurus"
  | "tarih"
  | "bool"
  | "secim"
  | "referans";

interface Alan {
  ad: string;
  /** METIN DEGIL ANAHTAR (tur 17/22 kilitleri): etiket cizim aninda aktif
   *  dilde cozulur; sabit Turkce dil degisiminde oldugu gibi kalirdi. */
  etiket: SozlukAnahtari;
  tip: AlanTip;
  zorunlu?: boolean;
  secenekler?: string[];
  /** Listede sutun olarak gosterilsin mi (hepsi gosterilirse tablo tasar). */
  sutun?: boolean;

  // --------------------------- referans (P111) ----------------------------
  /** `referans` tipi icin: secenekleri yukleyecek BFF ucu. */
  kaynakUcu?: string;
  /** Secenek ETIKETI olarak okunacak alan (`no`, `ad`...). */
  etiketAlani?: string;
  /** TABLODA gosterilecek alan, formdakinden FARKLI olabilir: form
   *  `unit_id` (kimlik) tutar, tablo sunucunun cozdugu `unit_no`yu
   *  gosterir — tabloda ham UUID okumak kullaniciya hicbir sey anlatmaz. */
  sutunAlani?: string;
  /** YALNIZ olusturmada duzenlenebilir. Bolum sayacinin dairesi PATCH
   *  govdesinde YOKTUR; gondermek sessizce yok sayilirdi ve kullanici
   *  daireyi degistirdigini sanirdi. */
  sadeceOlustur?: boolean;
}

interface Defter {
  kaynak: string;
  baslikAnahtari: SozlukAnahtari;
  alanlar: Alan[];
  /** Deftere OZEL ek eylem (P111: toplu sayac uretimi). Tablonun ustunde
   *  cizilir; is bitince [yenile] cagrilir. Bu kanca sayesinde
   *  `DefterGorunumu` tek bir kaynagin adini bile bilmez. */
  ekEylem?: (yenile: () => void) => ReactNode;
}

const DEFTERLER: Defter[] = [
  {
    kaynak: "kasalar",
    baslikAnahtari: "tanimKasalar",
    alanlar: [
      { ad: "kod", etiket: "tanimAlanKod", tip: "metin", zorunlu: true, sutun: true },
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "acilis_tarihi", etiket: "tanimAlanAcilisTarihi", tip: "tarih" },
      { ad: "acilis_bakiye_kurus", etiket: "tanimAlanAcilisBakiye", tip: "kurus", sutun: true },
      { ad: "banka_mi", etiket: "tanimAlanBankaMi", tip: "bool", sutun: true },
      { ad: "iban", etiket: "tanimAlanIban", tip: "metin" },
      { ad: "banka_adi", etiket: "tanimAlanBankaAdi", tip: "metin" },
      { ad: "sube", etiket: "tanimAlanSube", tip: "metin" },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "gelir-gider-gruplari",
    baslikAnahtari: "tanimGelirGiderGruplari",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool", sutun: true },
    ],
  },
  {
    kaynak: "gelir-gider-tanimlari",
    baslikAnahtari: "tanimGelirGiderTanimlari",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      {
        ad: "tip",
        etiket: "tanimAlanTip",
        tip: "secim",
        zorunlu: true,
        secenekler: ["gelir", "gider", "her_ikisi"],
        sutun: true,
      },
      {
        // GELIR kaleminde dagitim OLMAZ (sunucu 422) — alt metin bunu soyler.
        ad: "dagitim_sekli",
        etiket: "tanimAlanDagitim",
        tip: "secim",
        secenekler: ["bagimsiz_bolumlere_esit", "tipe_gore"],
        sutun: true,
      },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "firmalar",
    baslikAnahtari: "tanimFirmalar",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "vergi_no", etiket: "tanimAlanVergiNo", tip: "metin", sutun: true },
      { ad: "vergi_dairesi", etiket: "tanimAlanVergiDairesi", tip: "metin" },
      { ad: "telefon", etiket: "tanimAlanTelefon", tip: "metin", sutun: true },
      { ad: "email", etiket: "tanimAlanEposta", tip: "metin" },
      { ad: "yetkili_ad", etiket: "tanimAlanYetkili", tip: "metin" },
      { ad: "acilis_bakiye_kurus", etiket: "tanimAlanAcilisBakiye", tip: "kurus" },
      {
        ad: "acilis_bakiye_yon",
        etiket: "tanimAlanBakiyeYonu",
        tip: "secim",
        secenekler: ["borc", "alacak"],
      },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    // (P166 §8.3) GOREV KATEGORILERI — web'de ilk kez.
    //
    // Kurulum sihirbazinin "Gorev alanlari" adimi buraya bakar. Once
    // `/tasks`e yolluyordu ve orada kategori OLUSTURULAMIYORDU: kullanici
    // "once bir kategori atamalisiniz" uyarisiyla karsilasip yapacak bir
    // sey bulamiyordu. Sihirbazdaki tek gercek CIKMAZ buydu.
    kaynak: "gorev-kategorileri",
    baslikAnahtari: "tanimGorevKategorileri",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      // AKTIF alani ONEMLI: silme SOFT-DELETE'tir (gorev gecmisi
      // kategoriye referans verir). Pasiflestirileni GERI ALMANIN baska
      // yolu yok — bu kutu olmasa "yanlislikla sildim" geri alinamazdi.
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool", sutun: true },
    ],
  },
  {
    kaynak: "personel-kayitlari",
    baslikAnahtari: "tanimPersonel",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "gorev", etiket: "tanimAlanGorev", tip: "metin", sutun: true },
      { ad: "tc", etiket: "tanimAlanTc", tip: "metin" },
      { ad: "telefon", etiket: "tanimAlanTelefon", tip: "telefon", sutun: true },
      { ad: "giris_tarihi", etiket: "tanimAlanGirisTarihi", tip: "tarih" },
      { ad: "cikis_tarihi", etiket: "tanimAlanCikisTarihi", tip: "tarih" },
      { ad: "maas_kurus", etiket: "tanimAlanMaas", tip: "kurus" },
      // (P203 §5) SAATLIK ucret — fazla mesai hesabi icin. BOS
      // BIRAKILABILIR: o zaman aylikatan turetilir (`maas / 225`;
      // 30 gun x 7,5 saat). Zorunlu kilmak, ayligi girmis yoneticiye
      // ayni bilgiyi ikinci kez sordurmakti.
      { ad: "saatlik_ucret_kurus", etiket: "tanimAlanSaatlikUcret", tip: "kurus" },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "arac-kayitlari",
    baslikAnahtari: "tanimAraclar",
    alanlar: [
      { ad: "plaka", etiket: "tanimAlanPlaka", tip: "metin", zorunlu: true, sutun: true },
      { ad: "marka", etiket: "tanimAlanMarka", tip: "metin", sutun: true },
      { ad: "model", etiket: "tanimAlanModel", tip: "metin", sutun: true },
      { ad: "renk", etiket: "tanimAlanRenk", tip: "metin" },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    kaynak: "sayaclar-ana",
    baslikAnahtari: "tanimSayaclar",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      {
        ad: "tip",
        etiket: "tanimAlanTip",
        tip: "secim",
        secenekler: ["su", "elektrik", "dogalgaz", "isi", "diger"],
        sutun: true,
      },
      { ad: "tesisat_no", etiket: "tanimAlanTesisatNo", tip: "metin" },
      { ad: "ortak_alan_yuzde", etiket: "tanimAlanOrtakAlanYuzde", tip: "sayi", sutun: true },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool" },
    ],
  },
  {
    // (P111) BOLUM SAYACLARI — daire basina sayac. Bu defter, sayfanin
    // veri-suruculu mimarisine yapilan ILK gercek genisletmedir: alanlarin
    // ikisi baska bir uctan secenek yukleyen REFERANS alanlaridir.
    kaynak: "sayaclar-bolum",
    baslikAnahtari: "tanimSayaclarBolum",
    alanlar: [
      {
        ad: "unit_id",
        etiket: "tanimAlanDaire",
        tip: "referans",
        zorunlu: true,
        sutun: true,
        kaynakUcu: "/api/units?limit=200&aktif=true",
        etiketAlani: "no",
        sutunAlani: "unit_no",
        // Sunucu PATCH govdesinde daire DEGISTIRILEMEZ (bkz. Alan.sadeceOlustur).
        sadeceOlustur: true,
      },
      {
        ad: "ana_sayac_id",
        etiket: "tanimAlanAnaSayac",
        tip: "referans",
        sutun: true,
        kaynakUcu: "/api/tanimlar/sayaclar-ana?limit=200",
        etiketAlani: "ad",
        sutunAlani: "ana_sayac_ad",
      },
      { ad: "tesisat_no", etiket: "tanimAlanTesisatNo", tip: "metin", sutun: true },
      { ad: "ilk_okuma", etiket: "tanimAlanIlkOkuma", tip: "sayi" },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool", sutun: true },
    ],
    ekEylem: (yenile) => <OtomatikSayacUretimi onBitti={yenile} />,
  },
  // (P154 / Asama 7.1+7.2) DAIRE TIPLERI — brief'in "Bagimsiz bolum
  // tanimlari -> Daire Tipleri, ayni sayfa WEB'e" maddesi. Uc (P26) vardi,
  // panelde ekrani yoktu.
  //
  // `varsayilan_aidat_kurus` NULL "tanimsiz" demektir, 0 DEGIL — 0 gecerli
  // bir tutardir (muaf daire). `kurus` alan tipi bos girisi null olarak
  // gonderir, bu ayrimi korur.
  {
    kaynak: "unit-tipleri",
    baslikAnahtari: "tanimDaireTipleri",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "varsayilan_aidat_kurus", etiket: "tanimAlanVarsayilanAidat", tip: "kurus", sutun: true },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool", sutun: true },
    ],
  },
  // GRUP ve TIP AYRI KAVRAMLAR (P26): grup bolumun NE OLDUGU (Daire /
  // Villa / Dukkan), tip buyukluk/duzen (1+0, 2+1) + varsayilan aidat.
  // Tek deftere sikistirmak her grup x tip kombinasyonunu ayri satira
  // zorlardi.
  {
    kaynak: "unit-gruplari",
    baslikAnahtari: "tanimDaireGruplari",
    alanlar: [
      { ad: "ad", etiket: "tanimAlanAd", tip: "metin", zorunlu: true, sutun: true },
      { ad: "aktif", etiket: "tanimAlanAktif", tip: "bool", sutun: true },
    ],
  },
];

type Kayit = Record<string, unknown>;

// (P56) UCUNCU PARA AYRISTIRICISI KALDIRILDI. Eskisi soyleydi:
//   metin.replace(",", ".") -> Number -> Math.round(n * 100)
// `1.250` girdisinde `Number("1.250")` = **1,25** verir: kullanici bin iki
// yuz elli lira yazip **1,25 TL** kaydediyordu — sessiz, BIN KATLIK bir
// hata, hem de her daireye yazilan aidat tutarinda. `5.000,00` gibi
// panelin KENDI gosterdigi bicim ise `Number("5.000.00")` -> NaN olurdu.
// Artik tek kural: `lib/money.ts` (bkz. P50).
function liraya(kurus: unknown): string {
  if (typeof kurus !== "number") return "";
  return kurusToTLSade(kurus);
}

/** HTML `type`/`inputMode` — UCLU DEGIL TABLO: sabit-metin tarayicisi
 *  (tur 47) ucludaki her dizgiyi cevrilmemis metin sanar ve `date`/`text`
 *  gibi teknik degerler icin de uyarir. Tabloya cevirmek hem taramayi
 *  memnun eder hem de tip eklendiginde derleyicinin burayi gostermesini
 *  saglar (`Record<AlanTip, ...>` eksik anahtari yakalar). */
const GIRIS_TIPI: Record<AlanTip, string> = {
  metin: "text",
  telefon: "tel",
  sayi: "text",
  kurus: "text",
  tarih: "date",
  bool: "checkbox",
  secim: "text",
  referans: "text",
};
const GIRIS_MODU: Partial<Record<AlanTip, "decimal">> = {
  sayi: "decimal",
  kurus: "decimal",
};
function girisTipi(tip: AlanTip): string {
  return GIRIS_TIPI[tip];
}
// Donus tipi CIKARIMLA gelir: acik anotasyon bir dizgi sabiti icerirdi ve
// sabit-metin taramasi onu da cevrilmemis metin sayardi.
function girisModu(tip: AlanTip) {
  return GIRIS_MODU[tip];
}

/**
 * (P111) REFERANS SECICI — secenekleri baska bir uctan yukler.
 *
 * NEDEN AYRI BILESEN: her referans alani KENDI `useSWR`ini kurar. Ust
 * bilesende alanlar uzerinde donguyle kanca cagirmak, sekme degisince
 * kanca SAYISINI degistirirdi (React'in kanca sirasi kurali).
 *
 * YUKLENEMEYEN LISTE SESSIZ KALMAZ: secici devre disi kalir ve durum
 * metni yazar — bos bir acilir liste, kullaniciya "hic daire yok" der ki
 * bu yanlistir.
 */
/** Secenek etiketi icin VARSAYILAN alan. JSX icinde `?? "ad"` yazmak,
 *  sabit-metin taramasinin (tur 47) her dizgiyi cevrilmemis metin
 *  saymasi demekti; teknik bir alan adi cevrilmez. */
const REFERANS_VARSAYILAN_ETIKET = "ad";

function ReferansSecici({
  alan,
  deger,
  devre,
  onDegis,
}: {
  alan: Alan;
  deger: string;
  devre: boolean;
  onDegis: (v: string) => void;
}) {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Kayit[] }>(
    alan.kaynakUcu ?? null,
    jsonFetcher,
  );
  const secenekler = data?.items ?? [];
  return (
    <Secim
      aria-label={t(alan.etiket)}
      disabled={devre || isLoading || error !== undefined}
      value={deger}
      onChange={(e) => onDegis(e.target.value)}
    >
      <option value="">
        {isLoading
          ? t("ortakYukleniyor")
          : error
            ? t("tanimReferansYuklenemedi")
            : "—"}
      </option>
      {secenekler.map((s) => (
        <option key={String(s.id)} value={String(s.id)}>
          {String(s[alan.etiketAlani ?? REFERANS_VARSAYILAN_ETIKET] ?? s.id)}
        </option>
      ))}
    </Secim>
  );
}

/**
 * (P111) TOPLU SAYAC URETIMI — bir ana sayac icin TUM aktif dairelere
 * bolum sayaci acar.
 *
 * NEDEN VAR: 200 daireli bir sitede sayaclari tek tek acmak gercekci
 * degil. Uc YENIDEN CALISTIRILABILIR — zaten sayaci olan daireler
 * ATLANIR; sonuc metni kac tane acildigini VE kac tanesinin atlandigini
 * ayri ayri soyler, yoksa kullanici ikinci tiklamada "hicbir sey olmadi"
 * sanirdi.
 */
function OtomatikSayacUretimi({ onBitti }: { onBitti: () => void }) {
  const t = useT();
  const toast = useToast();
  const { data } = useSWR<{ items: Kayit[] }>(
    "/api/tanimlar/sayaclar-ana?limit=200",
    jsonFetcher,
  );
  const [anaId, setAnaId] = useState("");
  const [calisiyor, setCalisiyor] = useState(false);
  const anaSayaclar = data?.items ?? [];

  async function uret() {
    if (!anaId) return;
    setCalisiyor(true);
    try {
      const sonuc = (await apiSend("/api/tanimlar/sayaclar-bolum-otomatik", "POST", {
        ana_sayac_id: anaId,
      })) as { olusturulan?: number; atlanan?: number };
      toast.success(
        t("tanimSayacUretimSonuc", {
          olusturulan: String(sonuc?.olusturulan ?? 0),
          atlanan: String(sonuc?.atlanan ?? 0),
        }),
      );
      onBitti();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : String(e));
    } finally {
      setCalisiyor(false);
    }
  }

  return (
    <Kart>
      <p className="mb-2" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
        {t("tanimSayacUretimBaslik")}
      </p>
      <div className="flex flex-wrap items-end gap-2">
        <AlanSarmal etiket={t("tanimAlanAnaSayac")}>
          {(b) => (
          <Secim
            {...b}
            value={anaId}
            onChange={(e) => setAnaId(e.target.value)}
          >
            <option value="">—</option>
            {anaSayaclar.map((s) => (
              <option key={String(s.id)} value={String(s.id)}>
                {String(s.ad ?? s.id)}
              </option>
            ))}
          </Secim>
          )}
        </AlanSarmal>
        <Dugme
          type="button"
          tur="birincil"
          disabled={!anaId || calisiyor}
          onClick={() => void uret()}
        >
          {calisiyor ? t("ortakKaydediliyor") : t("tanimSayacUret")}
        </Dugme>
      </div>
      <p className="mt-2" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("tanimSayacUretimNotu")}
      </p>
    </Kart>
  );
}

function formDegeri(alan: Alan, kayit: Kayit | null): string | boolean {
  const ham = kayit?.[alan.ad];
  if (alan.tip === "bool") return ham === undefined ? true : Boolean(ham);
  if (alan.tip === "kurus") return liraya(ham);
  return ham === null || ham === undefined ? "" : String(ham);
}

/** Defter adlari — menudeki `?defter=` baglantilarinin gecerli kumesi. */
const DEFTER_ADLARI = DEFTERLER.map((d) => d.kaynak);

/**
 * (P167 §1.6) "AYARLAR" SEKMESI DE ADRESE TASINDI.
 *
 * Bu sekme bir defter degil (muhasebe ayarlari formu) ve secimi YEREL bir
 * `useState`te duruyordu. Sonucu: menudeki Tanimlar bolumu on bir deftere
 * dogrudan baglanabiliyor ama Ayarlar'a baglanamiyordu — sayfanin
 * menuden ACILAMAYAN tek bolumu oydu.
 *
 * Kavram uydurulmadi: ayni `defter` sorgusuna, defter OLMAYAN tek bir
 * deger eklendi. Boylece secim tek bir yerden (adresten) okunur ve
 * "hangisi gecerli" sorusu iki duruma bolunmez.
 */
const AYARLAR_ADI = "ayarlar";
const SEKME_ADLARI = [...DEFTER_ADLARI, AYARLAR_ADI];

export default function TanimlarPage() {
  const t = useT();
  // (P154 / Asama 7.1) Menudeki TANIMLAR bolumu her deftere DOGRUDAN
  // baglaniyor (`?defter=kasalar`). Sekme adresten okunmasaydi baglanti
  // dogru sayfayi acar ama HEP ilk defteri gosterirdi.
  const [defterAdi, setDefterAdi] = useSorguSecimi(
    "defter",
    SEKME_ADLARI,
    SEKME_ADLARI[0],
  );
  // -1 "Ayarlar" sekmesi (defter degil) — artik o da ADRESTEN okunuyor.
  const ayarlarda = defterAdi === AYARLAR_ADI;
  const sekme = ayarlarda ? -1 : DEFTERLER.findIndex((d) => d.kaynak === defterAdi);
  const defter = DEFTERLER[sekme];
  const setSekme = (i: number) => {
    setDefterAdi(i === -1 ? AYARLAR_ADI : DEFTERLER[i].kaynak);
  };
  return (
    <div className="space-y-4">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kabukTanimlar")}
      </h1>
      <div className="flex flex-wrap gap-2">
        {DEFTERLER.map((d, i) => (
          <Dugme
            key={d.kaynak}
            boy="kucuk"
            tur={i === sekme ? TUR_BIRINCIL : TUR_IKINCIL}
            /* (P160) `aria-pressed`: acik defter eskiden yalniz RENKLE
               belliydi ve ekran okuyucu hangisinin acik oldugunu
               soylemiyordu. */
            aria-pressed={i === sekme}
            onClick={() => setSekme(i)}
          >
            {t(d.baslikAnahtari)}
          </Dugme>
        ))}
        <Dugme
          boy="kucuk"
          tur={sekme === -1 ? TUR_BIRINCIL : TUR_IKINCIL}
          aria-pressed={sekme === -1}
          onClick={() => setSekme(-1)}
        >
          {t("tanimAyarlar")}
        </Dugme>
      </div>
      {sekme === -1 ? <Ayarlar /> : <DefterGorunumu key={defter.kaynak} defter={defter} />}
    </div>
  );
}

function DefterGorunumu({ defter }: { defter: Defter }) {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Kayit[] }>(
    `/api/tanimlar/${defter.kaynak}?limit=200`,
    jsonFetcher,
  );
  const [acik, setAcik] = useState(false);
  const [duzenlenen, setDuzenlenen] = useState<Kayit | null>(null);
  const [form, setForm] = useState<Record<string, string | boolean>>({});
  const [formHata, setFormHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  function ac(kayit: Kayit | null) {
    setDuzenlenen(kayit);
    const yeni: Record<string, string | boolean> = {};
    for (const a of defter.alanlar) yeni[a.ad] = formDegeri(a, kayit);
    setForm(yeni);
    setFormHata(null);
    setAcik(true);
  }

  async function kaydet() {
    const govde: Record<string, unknown> = {};
    for (const a of defter.alanlar) {
      // (P111) DUZENLEMEDE gonderilmez: sunucu bu alani PATCH govdesinde
      // KABUL ETMEZ ve pydantic fazlaligi SESSIZCE yok sayar — kullanici
      // daireyi tasidigini sanip kaydederdi.
      if (a.sadeceOlustur && duzenlenen) continue;
      const v = form[a.ad];
      if (a.tip === "bool") {
        govde[a.ad] = Boolean(v);
        continue;
      }
      const metin = String(v ?? "").trim();
      if (metin === "") {
        if (a.zorunlu) {
          setFormHata(t("tanimZorunluAlan", { alan: t(a.etiket) }));
          return;
        }
        // BOS = "deger yok": null gonderilir, "" degil — sunucu bicim
        // dogrulamasi bos metni gecersiz sayardi.
        govde[a.ad] = null;
        continue;
      }
      // GECERSIZ GIRDI ISTEK ATMADAN DURDURULUR. Eskiden `Number("abc")`
      // NaN uretiyor, `JSON.stringify` onu **null**a ceviriyordu: sunucu
      // "alani temizle" diye anliyordu ve kullanici degeri sildigini
      // hic bilmiyordu.
      if (a.tip === "kurus") {
        const kurus = tlToKurus(metin);
        if (kurus === null) {
          setFormHata(t("tanimTutarGecersiz", { alan: t(a.etiket) }));
          return;
        }
        govde[a.ad] = kurus;
      } else if (a.tip === "sayi") {
        const sonuc = sayiCoz(metin);
        if (sonuc.tur !== "sayi") {
          setFormHata(t("tanimSayiGecersiz", { alan: t(a.etiket) }));
          return;
        }
        govde[a.ad] = sonuc.deger;
      } else if (a.tip === "telefon") {
        // (P166 §9) GECERSIZ NUMARA ISTEK ATMADAN DURDURULUR. Sunucu
        // `max_length=30` disinda bir sey denetlemiyor: gecersiz numara
        // SESSIZCE kaydolur ve ancak SMS gitmeyince fark edilirdi.
        const telHata = telefonHataMetni(metin, Boolean(a.zorunlu), t);
        if (telHata) {
          setFormHata(telHata);
          return;
        }
        // E.164 GONDERILIR — kullanici/tesis kayitlariyla AYNI bicim.
        // Ayni numaranin iki farkli yazimla iki kayit uretmesi, telefonu
        // bir esleme anahtari olarak kullanan her yeri bozardi.
        govde[a.ad] = telefonNormalle(metin);
      } else govde[a.ad] = metin;
    }
    setKaydediyor(true);
    setFormHata(null);
    const yol = duzenlenen
      ? `/api/tanimlar/${defter.kaynak}/${String(duzenlenen.id)}`
      : `/api/tanimlar/${defter.kaynak}`;
    // `apiSend` HATA FIRLATIR (donen nesnede bayrak yok) — sunucunun
    // katalog metni `ApiHatasi.message`tedir ve forma yazilir.
    try {
      await apiSend(yol, duzenlenen ? "PATCH" : "POST", govde);
    } catch (e) {
      setKaydediyor(false);
      setFormHata(e instanceof Error ? e.message : String(e));
      return;
    }
    setKaydediyor(false);
    setAcik(false);
    toast.success(t("ortakKaydet"));
    void mutate();
  }

  async function sil(kayit: Kayit) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("tanimSilOnay"), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/tanimlar/${defter.kaynak}/${String(kayit.id)}`, "DELETE");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : String(e));
      return;
    }
    void mutate();
  }

  const sutunlar = defter.alanlar.filter((a) => a.sutun);
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-3">
      <div className="flex justify-end">
        <Dugme type="button" tur="birincil" onClick={() => ac(null)}>
          {t("tanimYeniKayit")}
        </Dugme>
      </div>
      {defter.ekEylem?.(() => void mutate())}
      {/* (P60) `String(error)` "Error: " onekini de yazardi. */}
      {error instanceof Error ? <HataDurumu mesaj={error.message} /> : null}
      {isLoading ? <p>{t("ortakYukleniyor")}</p> : null}
      {/* (P61) `!error` SART: yukleme dustugunde de liste bostur ve sayfa
          "Kayit yok" derdi — ustundeki hata kutusuyla celiserek. */}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <BosDurum baslik={t("tanimKayitYok")} />
      ) : null}
      {/* (P154 / Asama 6.2) ORTAK LISTE. Elle yazilmis `<table>` kalkti;
          siralama, kolon suzgeci, sayfa basina kayit ve sayfalama artik
          BEDAVA geliyor. Dokuz defterin dokuzu da ayni davranisi aliyor —
          onceki hâlde her biri kendi tablosunu ciziyordu ve hicbirinde
          sayfalama yoktu (`/tanimlar` 200 daireli bir tesiste tek sayfada
          200 satir cizerdi). */}
      {kayitlar.length > 0 ? (
        <Liste<Kayit>
          kolonlar={sutunlar.map((a) => ({
            anahtar: a.ad,
            baslik: t(a.etiket),
            hizala: a.tip === "kurus" ? ("end" as const) : undefined,
            // SIRALAMA/SUZGEC ham degeri: gorunen metin degil. `kurus`
            // alaninda gorunen "5.000,00 ₺"dir ve ona gore siralamak
            // METIN siralamasi olurdu (1.000 > 900).
            deger: (k: Kayit) =>
              a.tip === "kurus"
                ? Number(k[a.ad] ?? 0)
                : a.tip === "referans"
                  ? String(k[a.sutunAlani ?? a.ad] ?? "")
                  : a.tip === "bool"
                    ? (k[a.ad] ? "1" : "0")
                    : String(k[a.ad] ?? ""),
            suzgec: a.tip === "metin",
            ciz: (k: Kayit) =>
              a.tip === "bool"
                ? k[a.ad]
                  ? "✓"
                  : "—"
                : a.tip === "referans"
                  ? String(k[a.sutunAlani ?? a.ad] ?? "—")
                  : a.tip === "kurus"
                    ? // (P47) TABLODA `kurusToTL`, FORMDA `liraya` — ikisi
                      // AYNI DEGILDIR. Tabloda `liraya` kullanmak, Turkce'de
                      // BINLIK ayirici olan noktayi ondalik yerine koymak
                      // demekti: `5000.00` okuyan kullanici bes yuz bin
                      // sanabilirdi.
                      kurusToTL(Number(k[a.ad] ?? 0))
                    : a.tip === "telefon"
                      ? // (P166 §9) TABLODA DA BOSLUKLU: depoda E.164
                        // (`+905431992904`) durur, insan onu okuyamaz.
                        telefonGiris(String(k[a.ad] ?? "")) || "—"
                      : String(k[a.ad] ?? "—"),
          }))}
          satirlar={kayitlar}
          kimlik={(k) => String(k.id)}
          eylemler={(k) => (
            <span className="whitespace-nowrap">
              <Dugme type="button" boy="kucuk" onClick={() => ac(k)}>
                {t("ortakDuzenle")}
              </Dugme>{" "}
              <Dugme type="button" tur="tehlike" boy="kucuk" onClick={() => void sil(k)}>
                {t("ortakSil")}
              </Dugme>
            </span>
          )}
        />
      ) : null}

      {/* (P154 / Asama 6.1) ORTAK MODAL. Onceden form SAYFANIN USTUNDE
          bir panel aciyordu: ESC yoktu, dis tik yoktu, odak tuzagi yoktu
          ve kaydedilmemis degisiklikle kapatmak SESSIZCE veriyi atardi.
          Ucu de artik bilesende. */}
      <Modal
        baslik={duzenlenen ? t("ortakDuzenle") : t("tanimYeniKayit")}
        acik={acik}
        kapat={() => setAcik(false)}
        // KIRLI: yeni kayitta herhangi bir alan doldurulduysa, duzenlemede
        // formun acilis degerinden sapildiysa.
        kirli={kaydediyor ? false : Object.values(form).some((v) => v !== "" && v !== false)}
        altBilgi={
          <ModalEylemler
            iptal={() => setAcik(false)}
            kaydet={() => void kaydet()}
            kaydediyor={kaydediyor}
          />
        }
      >
        <HataDurumu mesaj={formHata} />
        <div className="grid gap-3 sm:grid-cols-2">
          {defter.alanlar.map((a) =>
            // (P166 §9) TELEFON KENDI SARMALINI TASIR: hata metni, ipucu
            // ve `aria-describedby` bagi bilesenin icinde kurulur. Disina
            // ikinci bir `AlanSarmal` koymak, ic ice iki etiket demekti.
            a.tip === "telefon" ? (
              <TelefonAlani
                key={a.ad}
                etiket={t(a.etiket)}
                zorunlu={Boolean(a.zorunlu)}
                deger={String(form[a.ad] ?? "")}
                onDegisti={(v) => setForm({ ...form, [a.ad]: v })}
              />
            ) : (
            <AlanSarmal key={a.ad} etiket={t(a.etiket)}>
              {() =>
                a.tip === "bool" ? (
                <input
                  type="checkbox"
                  checked={Boolean(form[a.ad])}
                  onChange={(e) => setForm({ ...form, [a.ad]: e.target.checked })}
                />
              ) : a.tip === "referans" ? (
                <ReferansSecici
                  alan={a}
                  deger={String(form[a.ad] ?? "")}
                  // Duzenlemede DEGISTIRILEMEZ olan alan pasif cizilir:
                  // gizlemek, kullanicinin hangi daire oldugunu
                  // gorememesi demekti.
                  devre={Boolean(a.sadeceOlustur && duzenlenen)}
                  onDegis={(v) => setForm({ ...form, [a.ad]: v })}
                />
              ) : a.tip === "secim" ? (
                // (P63) ACIK `aria-label`: referans dali araya girince
                // `Field` sarmalayicisi pencereden cikti ve etiket
                // kanitlanamaz oldu. Acik ad her hâlukârda dogru.
                <Secim
                  aria-label={t(a.etiket)}
                  value={String(form[a.ad] ?? "")}
                  onChange={(e) => setForm({ ...form, [a.ad]: e.target.value })}
                >
                  <option value="">—</option>
                  {(a.secenekler ?? []).map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </Secim>
              ) : (
                <Alan
                  aria-label={t(a.etiket)}
                  type={girisTipi(a.tip)}
                  inputMode={girisModu(a.tip)}
                  value={String(form[a.ad] ?? "")}
                  onChange={(e) => setForm({ ...form, [a.ad]: e.target.value })}
                />
              )
              }
            </AlanSarmal>
            ),
          )}
        </div>
      </Modal>
      {diyalog}
    </div>
  );
}

function Ayarlar() {
  const t = useT();
  const toast = useToast();
  const { data, mutate } = useSWR<{
    evrak_seri: string;
    evrak_sira: number;
    para_birimi: string;
  }>("/api/muhasebe-ayarlari", jsonFetcher);
  const [form, setForm] = useState<Record<string, string>>({});
  const [hata, setHata] = useState<string | null>(null);

  const seri = form.evrak_seri ?? data?.evrak_seri ?? "";
  const sira = form.evrak_sira ?? String(data?.evrak_sira ?? "");
  const para = form.para_birimi ?? data?.para_birimi ?? "";

  async function kaydet() {
    try {
      await apiSend("/api/muhasebe-ayarlari", "PATCH", {
        evrak_seri: seri,
        evrak_sira: Number(sira),
        para_birimi: para,
      });
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
      return;
    }
    setHata(null);
    toast.success(t("ortakKaydet"));
    void mutate();
  }

  return (
    <Kart>
      <HataDurumu mesaj={hata} />
      <div className="grid gap-3 sm:grid-cols-3">
        <AlanSarmal etiket={t("tanimAlanEvrakSeri")}>
  {(b) => (
    <Alan {...b} value={seri}
            onChange={(e) => setForm({ ...form, evrak_seri: e.target.value.toUpperCase() })} />
  )}
</AlanSarmal>
        <AlanSarmal etiket={t("tanimAlanEvrakSira")}>
  {(b) => (
    <Alan {...b} inputMode="numeric"
            value={sira}
            onChange={(e) => setForm({ ...form, evrak_sira: e.target.value })} />
  )}
</AlanSarmal>
        <AlanSarmal etiket={t("tanimAlanParaBirimi")}>
  {(b) => (
    <Alan {...b} value={para}
            onChange={(e) => setForm({ ...form, para_birimi: e.target.value.toUpperCase() })} />
  )}
</AlanSarmal>
      </div>
      {/* Para biriminin YALNIZ gosterim oldugu ekranda YAZAR: aksi halde
          kullanici kur cevirisi bekler ve sessizce yanlis toplam okur. */}
      <p className="mt-2" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("tanimParaBirimiNotu")}</p>
      <div className="mt-3">
        <Dugme type="button" tur="birincil" onClick={() => void kaydet()}>
          {t("ortakKaydet")}
        </Dugme>
      </div>
    </Kart>
  );
}
