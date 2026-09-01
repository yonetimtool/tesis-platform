"use client";

// (P167 §4.1) BORCLANDIRMALAR — tekil + toplu.
//
// =====================================================================
// NEDEN `HareketSayfasi` KABUGUNU KULLANMIYOR
// =====================================================================
// Oteki yedi sayfa `finansal_hareket` defterini listeliyor; borclandirma
// ise BASKA BIR TABLODA (`dues_assessment`). Ikisi ayni sey degil ve
// olmamali: tahakkuk bir BORC YAZMAKTIR, para hareketi degil — kasa
// bakiyesine dokunmaz. Ortak kabugu zorlamak, iki farkli varligi tek
// sutun kumesine sikistirmak olurdu.
//
// (P192 §6.3) DUZELTME ARTIK VAR: `POST /dues/assessments/{id}/ters-kayit`.
// Satir SILINMEZ — ters kayit yazilir ve cift, borc hesabinin disinda
// kalir. Onceden hicbir duzeltme yolu yoktu ve bu, eksik raporda yaziliydi.
//
// (P192 §3.1) GECIKME FAIZI de burada: hesaplanan bir sayi degil, YAZILAN
// bir borc kalemi.

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  Modal,
  Secim,
  HataDurumu,
  VeriTablosu,
  useOnay,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { DisaAktar } from "@/components/finans/hareket-sayfasi";
import {
  bugun,
  useDaireler,
  useGelirGiderTanimlari,
  useKisiler,
} from "@/components/finans/ortak";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";
import { kurusToTL, tlToKurus } from "@/lib/money";

interface Tahakkuk {
  id: string;
  unit_id: string;
  donem: string;
  tutar_kurus: number;
  son_odeme_tarihi: string | null;
  aciklama: string | null;
  gelir_gider_tanim_ad: string | null;
  hedef_ad: string | null;
  tarih: string | null;
  gecikme_kurus: number;
  /** Doluysa bu satirin KENDISI bir duzeltmedir. */
  ters_kayit_id: string | null;
  /** (P193 §3) Bu tahakkuk ters kayitla duzeltildi mi. */
  iptal_edildi: boolean;
}

const YOK_ISARETI = "—";

// (P192 §3.3) Dagitim yontemleri. HAM ENUM EKRANA CIKMAZ: her deger bir
// sozluk anahtarina eslenir.
const DAGITIMLAR = ["daire_basina", "esit", "arsa_payi", "metrekare"] as const;
type Dagitim = (typeof DAGITIMLAR)[number];
const DAGITIM_ETIKET: Record<Dagitim, SozlukAnahtari> = {
  daire_basina: "finansDagitimDaireBasina",
  esit: "finansDagitimEsit",
  arsa_payi: "finansDagitimArsaPayi",
  metrekare: "finansDagitimMetrekare",
};

// (P192 §3.2) Kalem tipleri. `faiz` LISTEDE YOK ve olmamali: faiz elle
// yazilmaz, `gecikme-faizi/isle` ucundan dogar — elle yazilabilseydi
// kaynak borcla bagi kurulmaz ve idempotency kirilirdi.
const KALEM_TIPLERI = ["aidat", "demirbas", "olaganustu", "sayac", "diger"] as const;
type KalemTipi = (typeof KALEM_TIPLERI)[number];
const KALEM_ETIKET: Record<KalemTipi, SozlukAnahtari> = {
  aidat: "finansKalemAidat",
  demirbas: "finansKalemDemirbas",
  olaganustu: "finansKalemOlaganustu",
  sayac: "finansKalemSayac",
  diger: "finansKalemDiger",
};

// Atlama nedenleri sunucudan KOD olarak gelir; ekranda METNE cevrilir.
const ATLAMA_ETIKET: Record<string, SozlukAnahtari> = {
  arsa_payi_girilmemis: "finansAtlamaArsaPayiYok",
  metrekare_girilmemis: "finansAtlamaMetrekareYok",
  tip_varsayilani_yok: "finansAtlamaTipVarsayilaniYok",
  tutar_cozulemedi: "finansAtlamaTutarYok",
  benzersizlik_carpismasi: "finansAtlamaCarpisma",
};

function atlamaMetni(t: (a: SozlukAnahtari) => string, neden: string): string {
  // Bilinmeyen bir kod icin GENEL metin doner; ham kodu ekrana basmak
  // kullaniciya anlamsiz bir dize gostermek olurdu.
  const anahtar = ATLAMA_ETIKET[neden];
  return anahtar ? t(anahtar) : t("finansAtlamaTutarYok");
}

interface TopluSatir {
  unit_id: string;
  unit_no: string;
  tutar_kurus: number | null;
  atlama_nedeni: string | null;
}

interface Atlanan {
  unit_id: string;
  unit_no: string | null;
  neden: string;
}

/** `YYYY-MM-DD` -> `YYYY-MM`. Donem tarihten TURETILIR (bkz. modal). */
function donemden(tarih: string): string {
  return tarih.slice(0, 7);
}

/** (P192 §3.1) GECIKME FAIZI KARTI.
 *
 * Faiz artik ekranda hesaplanan bir sayi degil, YAZILAN bir borc kalemi.
 * Kart uc soruyu yanitlar: uygulaniyor mu, oran ne, bu kosumda ne
 * yazilacak. "Isle" ONIZLEMEDEKI tutari yazar — onizleme ile isleme
 * sunucuda AYNI hesabi cagirir.
 */
function GecikmeFaiziKarti() {
  const t = useT();
  const toast = useToast();
  const [mesgul, setMesgul] = useState(false);
  const [yenile, setYenile] = useState(0);

  const { data: ayar, mutate: ayarTazele } = useSWR<{
    gecikme_aylik_yuzde: number; gecikme_uygula: boolean;
  }>(`/api/panel/gecikme-ayari?_=${yenile}`, jsonFetcher);
  const { data: onizleme, mutate: onizlemeTazele } = useSWR<{
    uygulaniyor: boolean; toplam_fark_kurus: number;
    items: { assessment_id: string }[];
  }>(`/api/panel/gecikme-faizi-onizleme?_=${yenile}`, jsonFetcher);

  async function ayarYaz(govde: Record<string, unknown>) {
    setMesgul(true);
    try {
      await apiSend("/api/panel/gecikme-ayari", "PATCH", govde);
      setYenile((n) => n + 1);
      await Promise.all([ayarTazele(), onizlemeTazele()]);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  async function isle() {
    setMesgul(true);
    try {
      const s = await apiSend<{ yazilan: number }>(
        "/api/panel/gecikme-faizi-isle", "POST", {});
      toast.success(t("finansGecikmeIslendi", { n: s.yazilan }));
      setYenile((n) => n + 1);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  // (P193 §3) `items?` — eksik bir alan TUM SAYFAYI dusurmemeli. Bu
  // kart sayfanin ustunde; burada atilan bir hata borclandirma
  // listesini de goturuyordu (test yazarken olculdu).
  const adet = onizleme?.items?.length ?? 0;
  return (
    <div
      className="rounded-lg p-3"
      style={{ background: "var(--yz-metal-2)", fontSize: "var(--yz-fs-sm)" }}
    >
      <div className="flex flex-wrap items-center gap-3">
        <strong>{t("finansGecikmeFaizi")}</strong>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={ayar?.gecikme_uygula ?? false}
            disabled={mesgul}
            onChange={(e) => void ayarYaz({ gecikme_uygula: e.target.checked })}
          />
          {t("finansGecikmeUygula")}
        </label>
        <label className="flex items-center gap-2">
          {t("finansGecikmeOran")}
          <Alan
            type="number"
            className="w-20"
            defaultValue={ayar?.gecikme_aylik_yuzde ?? 0}
            disabled={mesgul}
            onBlur={(e) =>
              void ayarYaz({ gecikme_aylik_yuzde: Number(e.target.value) })
            }
          />
        </label>
        <Dugme
          tur="ikincil"
          boy="kucuk"
          disabled={mesgul || adet === 0}
          onClick={() => void isle()}
        >
          {t("finansGecikmeIsle")}
        </Dugme>
      </div>
      <p className="mt-2" style={{ color: "var(--yz-text-2)" }}>
        {!onizleme?.uygulaniyor
          ? t("finansGecikmeKapali")
          : adet === 0
            ? t("finansGecikmeYok")
            : t("finansGecikmeIslenecek", {
                n: adet,
                tutar: kurusToTL(onizleme.toplam_fark_kurus),
              })}
      </p>
    </div>
  );
}

export default function BorclandirmalarPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const [tekil, setTekil] = useState(false);
  const [toplu, setToplu] = useState(false);
  const [yenile, setYenile] = useState(0);
  const [durum, setDurum] = useState<TabloDurumu>({
    sayfa: 1, boy: 25, siraKolon: null, siraYonu: "artan",
  });

  const { data, error, isLoading, mutate } = useSWR<{
    meta: { total: number };
    items: Tahakkuk[];
  }>(
    `/api/panel/dues-assessments?limit=${durum.boy}` +
      `&offset=${(durum.sayfa - 1) * durum.boy}&_=${yenile}`,
    jsonFetcher,
  );

  // (P193 §3 / rehber eksik 8) TAHAKKUKU DUZELT — TERS KAYIT.
  //
  // Uc P192'den beri var (`POST /dues/assessments/{id}/ters-kayit`) ve
  // calisiyor — olculdu. Eksik olan dugmeydi: yanlis yazilmis bir borcu
  // yonetici panelden duzeltemiyordu.
  //
  // "SIL" DEMEZ ve silmez: finansal kayit silinmez, ters bir satir
  // yazilir ve ikisi de defterde durur. Onay metni bunu soyler — aksi
  // hâlde kullanici listede iki satir gorunce yanlislik sanirdi.
  async function tersKayit(a: Tahakkuk) {
    const ok = await onayla({
      baslik: t("finansTersKayitBaslik"),
      mesaj: t("finansTersKayitOnay", {
        donem: a.donem,
        tutar: kurusToTL(a.tutar_kurus),
      }),
      onayMetni: t("finansTersKayitEt"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      await apiSend(
        `/api/panel/dues-assessments/${a.id}/ters-kayit`,
        "POST",
        {},
      );
      toast.success(t("finansTersKayitYapildi"));
      setYenile((n) => n + 1);
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const sutunlar: Kolon<Tahakkuk>[] = [
    { id: "tarih", baslik: t("finansSutunTarih"),
      hucre: (a) => a.tarih ?? YOK_ISARETI, deger: (a) => a.tarih ?? "" },
    { id: "donem", baslik: t("finansAlanDonem"),
      hucre: (a) => a.donem, deger: (a) => a.donem },
    { id: "kisi", baslik: t("finansSutunKisi"),
      hucre: (a) => a.hedef_ad ?? YOK_ISARETI },
    { id: "tur", baslik: t("finansSutunTur"),
      hucre: (a) => a.gelir_gider_tanim_ad ?? YOK_ISARETI },
    { id: "sonOdeme", baslik: t("finansAlanSonOdeme"),
      hucre: (a) => a.son_odeme_tarihi ?? YOK_ISARETI },
    { id: "tutar", baslik: t("finansSutunTutar"), sayisal: true,
      hucre: (a) => <span className="tabular-nums">{kurusToTL(a.tutar_kurus)}</span>,
      deger: (a) => a.tutar_kurus },
    { id: "aciklama", baslik: t("finansSutunAciklama"),
      hucre: (a) => a.aciklama ?? YOK_ISARETI },
    {
      id: "eylem",
      baslik: t("finansSutunEylem"),
      hucre: (a) => {
        // UC IKISINI DE REDDEDER: ters kaydin kendisi ters kayitlanamaz
        // (422), zaten duzeltilmis tahakkuk ikinci kez duzeltilemez
        // (409). Ikisinde de dugme CIZILMEZ; basilamayacak bir dugme
        // gostermek kullaniciya "sistem bozuk" dedirtir.
        if (a.ters_kayit_id !== null) {
          return <span style={{ color: "var(--yz-text-3)" }}>{t("finansTersKayitSatiri")}</span>;
        }
        if (a.iptal_edildi) {
          return <span style={{ color: "var(--yz-text-3)" }}>{t("finansTersKayitli")}</span>;
        }
        return (
          <Dugme tur="sessiz" boy="kucuk" onClick={() => void tersKayit(a)}>
            {t("finansTersKayitEt")}
          </Dugme>
        );
      },
    },
  ];

  return (
    <div className="space-y-4">
      {diyalog}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("finansBorclandirmalar")}
        </h1>
        <div className="flex flex-wrap items-center gap-2">
          <Dugme tur="birincil" boy="kucuk" onClick={() => setTekil(true)}>
            {t("finansYeni")}
          </Dugme>
          <Dugme tur="ikincil" boy="kucuk" onClick={() => setToplu(true)}>
            {t("finansTopluBorclandirma")}
          </Dugme>
          <DisaAktar kod="detayli_borc" />
        </div>
      </div>

      <GecikmeFaiziKarti />

      <VeriTablosu
        kolonlar={sutunlar}
        satirlar={data?.items ?? []}
        satirId={(a) => a.id}
        yukleniyor={isLoading}
        sunucuTarafli
        toplam={data?.meta.total ?? 0}
        durum={durum}
        onDurumDegisti={setDurum}
        bosBaslik={t("finansKayitYok")}
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
      />

      <TekilModal
        acik={tekil}
        onKapat={() => setTekil(false)}
        onKaydedildi={() => setYenile((n) => n + 1)}
      />
      <TopluModal
        acik={toplu}
        onKapat={() => setToplu(false)}
        onKaydedildi={() => setYenile((n) => n + 1)}
      />
    </div>
  );
}

function TekilModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const kisiler = useKisiler();
  const daireler = useDaireler();
  const tanimlar = useGelirGiderTanimlari();

  const [daireId, setDaireId] = useState("");
  const [tanimId, setTanimId] = useState("");
  const [tarih, setTarih] = useState(bugun());
  const [sonOdeme, setSonOdeme] = useState("");
  const [tutar, setTutar] = useState("");
  const [aciklama, setAciklama] = useState("");
  const [gecikme, setGecikme] = useState(true);
  const [makbuz, setMakbuz] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  async function kaydet() {
    if (!daireId) { setHata(t("finansDaireSec")); return; }
    const kurus = tlToKurus(tutar);
    if (!kurus || kurus <= 0) { setHata(t("finansTutarGerekli")); return; }
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/panel/dues-assessments", "POST", {
        unit_id: daireId,
        // DONEM TARIHTEN TURETILIR: brief'in modalinda "Donem" alani YOK
        // ama uc onu zorunlu tutuyor (`YYYY-MM`). Kullaniciya ikinci bir
        // tarih alani sordurmak yerine, girdigi tarihin ayini kullanmak
        // hem daha az is hem de dogru varsayim — bir Mart tahakkuku Mart
        // donemine yazilir.
        donem: donemden(tarih),
        tutar_kurus: kurus,
        son_odeme_tarihi: sonOdeme || null,
        aciklama: aciklama.trim() || null,
        gelir_gider_tanim_id: tanimId || null,
        tarih: tarih || null,
        gecikme_uygula: gecikme,
      });
      toast.success(t("finansKaydedildi"));
      setTutar(""); setAciklama("");
      onKaydedildi();
      onKapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <Modal
      acik={acik}
      baslik={t("finansBorclandirmalar")}
      onKapat={onKapat}
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          <Dugme tur="birincil" disabled={kaydediyor} onClick={() => void kaydet()}>
            {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </span>
      }
    >
      <div className="grid gap-3">
        {/* KISI ALANI SALT BILGI: tahakkuk DAIREYE yazilir, kisiye degil
            (uc `unit_id` istiyor). Hedef kisi daireden turetilir — o
            dairenin aktif sakini. Kisi sectirmek, daireyle celisen bir
            secim yapilmasina kapi acardi. */}
        <AlanSarmal etiket={t("finansSutunDaire")} zorunlu>
          {(b) => (
            <Secim {...b} value={daireId} onChange={(e) => setDaireId(e.target.value)}>
              <option value="">{t("finansDaireSec")}</option>
              {daireler.map((d) => <option key={d.id} value={d.id}>{d.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansSutunTur")} zorunlu>
          {(b) => (
            <Secim {...b} value={tanimId} onChange={(e) => setTanimId(e.target.value)}>
              <option value="">{t("finansTurSec")}</option>
              {tanimlar.map((g) => <option key={g.id} value={g.id}>{g.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("finansAlanTarih")} zorunlu>
            {(b) => <Alan {...b} type="date" value={tarih} onChange={(e) => setTarih(e.target.value)} />}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansAlanSonOdeme")}>
            {(b) => <Alan {...b} type="date" value={sonOdeme} onChange={(e) => setSonOdeme(e.target.value)} />}
          </AlanSarmal>
        </div>
        <AlanSarmal etiket={t("finansAlanTutar")} zorunlu>
          {(b) => <Alan {...b} value={tutar} inputMode="decimal" onChange={(e) => setTutar(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanAciklama")}>
          {(b) => <Alan {...b} value={aciklama} onChange={(e) => setAciklama(e.target.value)} />}
        </AlanSarmal>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={gecikme} onChange={(e) => setGecikme(e.target.checked)} />
          {t("finansAlanGecikme")}
        </label>
        {/* MAKBUZ KUTUSU: brief'in alani. Isaretlenirse kaydettikten sonra
            makbuz dokumu raporu acilir — ayri bir "makbuz" varligi
            UYDURULMADI, `makbuz_dokumu` raporu zaten o cikti. */}
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={makbuz} onChange={(e) => setMakbuz(e.target.checked)} />
          {t("finansAlanMakbuz")}
        </label>
        {makbuz && <DisaAktar kod="makbuz_dokumu" />}
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}

function TopluModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const tanimlar = useGelirGiderTanimlari();

  const [tanimId, setTanimId] = useState("");
  const [tarih, setTarih] = useState(bugun());
  const [sonOdeme, setSonOdeme] = useState("");
  const [tutar, setTutar] = useState("");
  const [aciklama, setAciklama] = useState("");
  // (P192 §3.3) Dagitim yontemi. `daire_basina` ESKI DAVRANIS ve
  // varsayilan; digerleri TOPLAMI dairelere boler (KMK md. 20 arsa payi).
  const [dagitim, setDagitim] = useState<Dagitim>("daire_basina");
  const [kalemTipi, setKalemTipi] = useState<KalemTipi>("aidat");
  const [onizleme, setOnizleme] = useState<{
    islenecek: number; atlanacak: number; toplam_kurus: number;
    satirlar?: TopluSatir[];
  } | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  function govde() {
    const kurus = tlToKurus(tutar);
    const ortak = {
      donem: donemden(tarih),
      gelir_gider_tanim_id: tanimId,
      son_odeme_tarihi: sonOdeme || null,
      tarih: tarih || null,
      aciklama: aciklama.trim() || null,
      kalem_tipi: kalemTipi,
      dagitim,
    };
    // AYNI ALAN IKI ANLAM TASIMAZ: `daire_basina` modunda girilen tutar
    // HER DAIREYE yazilir, oteki modlarda ise DAGITILACAK TOPLAMDIR. Tek
    // bir alan iki uca da gonderilseydi, mod degisince ayni sayi sessizce
    // baska bir sey ifade ederdi.
    if (dagitim === "daire_basina") {
      return {
        ...ortak,
        // TUTAR BOS BIRAKILABILIR: uc o zaman DAIRE TIPININ varsayilan
        // tutarini kullanir (P26). Sifir gondermek bunu bozardi.
        tutar_kurus: kurus && kurus > 0 ? kurus : null,
      };
    }
    return { ...ortak, toplam_tutar_kurus: kurus && kurus > 0 ? kurus : null };
  }

  // ONIZLEME ONCE, ISLEME SONRA — ve ikisi AYNI govdeyi kullanir (uc de
  // oyle tasarlanmis). "500 daireden 3'u tipsiz" bilgisi islemeden ONCE
  // gorulmeli; sonra fark edilirse eksik tahakkuk sessizce yayilir.
  async function onizle() {
    if (!tanimId) { setHata(t("finansTurSec")); return; }
    setHata(null); setMesgul(true);
    try {
      const s = await apiSend<{
        islenecek: number; atlanacak: number; toplam_kurus: number;
        satirlar?: TopluSatir[];
      }>("/api/panel/borclandirma-toplu-onizleme", "POST", govde());
      setOnizleme(s);
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  async function isle() {
    setHata(null); setMesgul(true);
    try {
      const sonuc = await apiSend<{ atlananlar?: Atlanan[] }>(
        "/api/panel/borclandirma-toplu", "POST", govde());
      // (P192 §3.2) SESSIZ ATLAMA YOK: atlanan varsa kullaniciya SOYLENIR.
      // Onceden yalnizca bir sayi donuyordu ve kimse bakmiyordu; yonetici
      // eksik tahakkuk yaptigini fark etmiyordu.
      if (sonuc?.atlananlar?.length) {
        toast.error(
          `${t("finansAtlananlar")}: ${sonuc.atlananlar
            .map((a) => `${a.unit_no ?? ""} (${atlamaMetni(t, a.neden)})`)
            .join(", ")}`,
        );
      }
      toast.success(t("finansKaydedildi"));
      setOnizleme(null); setTutar(""); setAciklama("");
      onKaydedildi();
      onKapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  return (
    <Modal
      acik={acik}
      baslik={t("finansTopluBorclandirma")}
      onKapat={onKapat}
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          {onizleme ? (
            <Dugme tur="birincil" disabled={mesgul} onClick={() => void isle()}>
              {mesgul ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          ) : (
            <Dugme tur="birincil" disabled={mesgul} onClick={() => void onizle()}>
              {t("finansOnizle")}
            </Dugme>
          )}
        </span>
      }
    >
      <div className="grid gap-3">
        <AlanSarmal etiket={t("finansSutunTur")} zorunlu>
          {(b) => (
            <Secim {...b} value={tanimId}
              onChange={(e) => { setTanimId(e.target.value); setOnizleme(null); }}>
              <option value="">{t("finansTurSec")}</option>
              {tanimlar.map((g) => <option key={g.id} value={g.id}>{g.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("finansAlanTarih")} zorunlu>
            {(b) => <Alan {...b} type="date" value={tarih}
              onChange={(e) => { setTarih(e.target.value); setOnizleme(null); }} />}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansAlanSonOdeme")}>
            {(b) => <Alan {...b} type="date" value={sonOdeme}
              onChange={(e) => { setSonOdeme(e.target.value); setOnizleme(null); }} />}
          </AlanSarmal>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("finansDagitim")}>
            {(b) => (
              <Secim {...b} value={dagitim}
                onChange={(e) => {
                  setDagitim(e.target.value as Dagitim); setOnizleme(null);
                }}>
                {DAGITIMLAR.map((d) => (
                  <option key={d} value={d}>{t(DAGITIM_ETIKET[d])}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansKalemTipi")}>
            {(b) => (
              <Secim {...b} value={kalemTipi}
                onChange={(e) => {
                  setKalemTipi(e.target.value as KalemTipi); setOnizleme(null);
                }}>
                {KALEM_TIPLERI.map((k) => (
                  <option key={k} value={k}>{t(KALEM_ETIKET[k])}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        </div>
        <AlanSarmal
          etiket={dagitim === "daire_basina"
            ? t("finansAlanTutar")
            : t("finansDagitilacakToplam")}
        >
          {(b) => <Alan {...b} value={tutar} inputMode="decimal"
            onChange={(e) => { setTutar(e.target.value); setOnizleme(null); }} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanAciklama")}>
          {(b) => <Alan {...b} value={aciklama} onChange={(e) => setAciklama(e.target.value)} />}
        </AlanSarmal>

        {onizleme && (
          <div
            className="rounded-lg p-3"
            style={{ background: "var(--yz-metal-2)", fontSize: "var(--yz-fs-sm)" }}
          >
            <p>{t("finansToplamKayit", { n: onizleme.islenecek })}</p>
            <p className="tabular-nums">
              {t("finansToplamTutar", { tutar: kurusToTL(onizleme.toplam_kurus) })}
            </p>
            {/* (P192 §3.2) ATLANANLAR ISLEMEDEN ONCE GORUNUR. "500
                daireden 3'u atlanacak" bilgisi sonradan fark edilirse
                eksik tahakkuk sessizce yayilir. */}
            {(onizleme.satirlar ?? []).some((r) => r.atlama_nedeni) && (
              <ul className="mt-2 list-disc ps-4">
                {(onizleme.satirlar ?? [])
                  .filter((r) => r.atlama_nedeni)
                  .map((r) => (
                    <li key={r.unit_id}>
                      {r.unit_no} — {atlamaMetni(t, r.atlama_nedeni as string)}
                    </li>
                  ))}
              </ul>
            )}
          </div>
        )}
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
