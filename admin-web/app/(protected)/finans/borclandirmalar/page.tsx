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
// "IPTAL ET" DE YOK ve bu bilincli: bir tahakkuk ters kayitla degil
// SILINEREK duzeltilir (uc `DELETE /dues/assessments/{id}` tasimiyor,
// yani bugun duzeltme yolu YOK). Olmayan bir yolu dugme olarak cizmek,
// kullaniciyi calismayacak bir eyleme davet etmek olurdu; eksik raporda
// yazili.

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
}

const YOK_ISARETI = "—";

/** `YYYY-MM-DD` -> `YYYY-MM`. Donem tarihten TURETILIR (bkz. modal). */
function donemden(tarih: string): string {
  return tarih.slice(0, 7);
}

export default function BorclandirmalarPage() {
  const t = useT();
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
  ];

  return (
    <div className="space-y-4">
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
  const [onizleme, setOnizleme] = useState<{
    islenecek: number; atlanacak: number; toplam_kurus: number;
  } | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  function govde() {
    const kurus = tlToKurus(tutar);
    return {
      donem: donemden(tarih),
      gelir_gider_tanim_id: tanimId,
      // TUTAR BOS BIRAKILABILIR: uc o zaman DAIRE TIPININ varsayilan
      // tutarini kullanir (P26). Sifir gondermek bunu bozardi.
      tutar_kurus: kurus && kurus > 0 ? kurus : null,
      son_odeme_tarihi: sonOdeme || null,
      tarih: tarih || null,
      aciklama: aciklama.trim() || null,
    };
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
      await apiSend("/api/panel/borclandirma-toplu", "POST", govde());
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
        <AlanSarmal etiket={t("finansAlanTutar")}>
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
          </div>
        )}
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
