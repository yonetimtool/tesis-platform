"use client";

// (P250 §9) OTOMASYON KURALLARI — duz cumle, ac/kapat, son calisma, sihirbaz.
//
// Onceki ekran tablolardan olusuyordu ("Tahakkuk gunu", "Periyot", "Son
// donem" sutunlari): yonetici bir kuralin NE YAPTIGINI sutunlari
// birlestirerek kendisi cikarmak zorundaydi. Simdi her kural tek bir
// cumledir ve yaninda:
//   * ac/kapat anahtari (kurali silmeden durdurmak),
//   * en son ne zaman calistigi ve NE YAPTIGI,
//   * tekil kurallarda (hatirlatma, gecikme faizi) "bugun calissaydi".
// Yeni kural dort adimli sihirbazla kurulur: ne zaman -> kime -> ne
// yapilsin -> onizleme. Onizleme SUNUCUDAN gelir (gorevin kullandigi
// ayni hesap); kaydetmeden once "47 daireye 56.400 ₺ borc yazilirdi"
// gorulur.
//
// HATIRLATMA TEK KAYIT: buradaki anahtar ile asagidaki hatirlatma
// ayrintilari kartı (§7) ve mobil ayni `hatirlatma-ayari` kaydini yazar.

import { useEffect, useState } from "react";
import useSWR, { useSWRConfig } from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Kart,
  Modal,
  Secim,
  useOnay,
} from "@/components/ui";
import { useGelirGiderTanimlari, useKasalar } from "@/components/finans/ortak";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useI18n } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";
import { ISTEMCI_SINIR, SINIR } from "@/lib/girdi-siniri";
import { kurusToTL, kurusToTLSade, tlToKurus } from "@/lib/money";
import {
  PAYLASIM,
  SIKLIK,
  gecikmeCumlesi,
  giderCumlesi,
  hatirlatmaCumlesi,
  maasCumlesi,
  planCumlesi,
  sonCalismaCumlesi,
  type GecikmeKurali,
  type GiderKurali,
  type HatirlatmaKurali,
  type MaasKurali,
  type PlanKurali,
  type SonCalisma,
} from "@/lib/otomasyon-cumle";
import { saltTarihBicimi, tarihSaatBicimi } from "@/lib/tarih";

const UC = {
  plan: "/api/panel/aidat-planlari",
  gider: "/api/panel/duzenli-giderler",
  hatirlatma: "/api/panel/hatirlatma-ayari",
  gecikme: "/api/panel/gecikme-ayari",
  son: "/api/panel/otomasyon-son-calismalar",
  hatirlatmaOnizleme: "/api/panel/hatirlatma-onizleme",
  gecikmeOnizleme: "/api/panel/gecikme-faizi-onizleme",
  planOnizleme: "/api/panel/aidat-plani-onizleme",
  maas: "/api/panel/maas-ayari",
  maasCalistir: "/api/panel/maaslar-calistir",
  maasOnayla: "/api/panel/maaslar-onayla",
} as const;

interface Onizleme {
  adet: number;
  toplam_kurus: number;
  atlanan: number;
  donem: string | null;
  ilk_tarih: string | null;
}

function buAy(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

/** Bugunden itibaren ayin `gun`une denk gelen ilk tarih (YYYY-MM-DD). */
export function ilkAylikTarih(gun: number, bugun = new Date()): string {
  const y = bugun.getFullYear();
  const m = bugun.getMonth();
  const hedef = bugun.getDate() <= gun ? new Date(y, m, gun) : new Date(y, m + 1, gun);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${hedef.getFullYear()}-${p(hedef.getMonth() + 1)}-${p(hedef.getDate())}`;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`): sozluk anahtarlari
// ve stil degerleri adlandirilmis sabit / yardimcidan gelir.
const CIZGI = "solid";
const KENAR = "var(--yz-border)";
const KENAR_SECILI = "var(--yz-accent-edge)";

function durumAnahtari(aktif: boolean): SozlukAnahtari {
  if (aktif) return "otoKuralAcik";
  return "otoKuralKapali";
}

function tutarEtiketi(tur: string | null, paylasim: string): SozlukAnahtari {
  if (tur === "gider") return "otoSihirbazTutar";
  if (paylasim === "daire_basina") return "otoSihirbazTutarDaire";
  return "otoSihirbazTutarToplam";
}

// ------------------------------- SATIR ------------------------------------ #
function KuralSatiri({
  id,
  cumle,
  aktif,
  son,
  ek,
  onAnahtar,
  eylemler,
}: {
  id: string;
  cumle: string;
  aktif: boolean;
  son: string;
  ek?: string | null;
  onAnahtar: (acik: boolean) => void;
  eylemler?: React.ReactNode;
}) {
  const { t } = useI18n();
  return (
    <li
      className="flex flex-wrap items-start justify-between gap-3 py-3"
      data-test={`kural-${id}`}
    >
      <div className="min-w-0 flex-1 space-y-1">
        <p
          data-test="kural-cumle"
          style={{
            fontSize: "var(--yz-fs-sm)",
            fontWeight: 600,
            color: aktif ? "var(--yz-text)" : "var(--yz-text-2)",
          }}
        >
          {cumle}
        </p>
        <p data-test="kural-son" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
          {son}
        </p>
        {ek ? (
          <p data-test="kural-bugun" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {ek}
          </p>
        ) : null}
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <label className="flex items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
          <input
            type="checkbox"
            role="switch"
            aria-checked={aktif}
            aria-label={t("otoKuralAnahtar", { cumle })}
            data-test="kural-anahtar"
            checked={aktif}
            onChange={(e) => onAnahtar(e.target.checked)}
          />
          {t(durumAnahtari(aktif))}
        </label>
        {eylemler}
      </div>
    </li>
  );
}

// ------------------------------ LISTE ------------------------------------- #
export function KurallarKarti() {
  const { t, dil } = useI18n();
  const toast = useToast();
  const { mutate: genelTazele } = useSWRConfig();
  const { onayla, diyalog } = useOnay();
  const [sihirbaz, setSihirbaz] = useState(false);

  const planlar = useSWR<{ items: PlanKurali[] }>(UC.plan, jsonFetcher);
  const giderler = useSWR<{ items: GiderKurali[] }>(UC.gider, jsonFetcher);
  const hatirlatma = useSWR<HatirlatmaKurali>(UC.hatirlatma, jsonFetcher);
  const gecikme = useSWR<GecikmeKurali>(UC.gecikme, jsonFetcher);
  const son = useSWR<{ items: SonCalisma[] }>(UC.son, jsonFetcher);
  const hOniz = useSWR<Onizleme>(UC.hatirlatmaOnizleme, jsonFetcher);
  // (P252 §2) Maas otomasyonu — denetciye 403 (ucret bilgisi): satir cizilmez.
  const maas = useSWR<MaasKurali>(UC.maas, jsonFetcher);
  const gOniz = useSWR<{ items: { fark_kurus: number }[]; toplam_fark_kurus: number }>(
    UC.gecikmeOnizleme,
    jsonFetcher,
  );

  const sonlar = new Map((son.data?.items ?? []).map((s) => [s.kural, s]));
  const zaman = (iso: string) => tarihSaatBicimi(iso, dil);
  const tarih = (iso: string) => saltTarihBicimi(iso, dil);

  async function yaz(yol: string, metot: "PATCH" | "POST" | "DELETE", govde?: unknown) {
    try {
      await apiSend(yol, metot, govde);
      // Hatirlatma ayrintilari karti ayni kaydi okur: genel tazeleme.
      await Promise.all([
        planlar.mutate(), giderler.mutate(), hatirlatma.mutate(), gecikme.mutate(),
        hOniz.mutate(), gOniz.mutate(), maas.mutate(), son.mutate(), genelTazele(UC.hatirlatma),
      ]);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function sil(yol: string) {
    const tamam = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("otoKuralSilOnay"),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (tamam) await yaz(yol, "DELETE");
  }

  async function maaslariCalistir() {
    try {
      const r = await apiSend<{ yazilan: number; toplam_kurus: number }>(UC.maasCalistir, "POST", {});
      if (r.yazilan > 0) {
        toast.success(t("otoKuralMaasCalisti", { adet: r.yazilan, tutar: kurusToTL(r.toplam_kurus) }));
      } else {
        toast.info(t("otoKuralMaasYazilacakYok"));
      }
      await Promise.all([maas.mutate(), son.mutate()]);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const gecikmeAdet = (gOniz.data?.items ?? []).filter((i) => i.fark_kurus > 0).length;
  const bos =
    planlar.data && giderler.data &&
    planlar.data.items.length === 0 && giderler.data.items.length === 0;

  return (
    <Kart>
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("otoKurallarBaslik")}
          </h2>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("otoKurallarAlt")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" data-test="kural-yeni" onClick={() => setSihirbaz(true)}>
          {t("otoKuralYeni")}
        </Dugme>
      </div>
      <HataDurumu mesaj={planlar.error || giderler.error ? t("ortakHataOlustu") : null} />
      <ul className="divide-y" data-test="kurallar">
        {(planlar.data?.items ?? []).map((p) => (
          <KuralSatiri
            key={p.id}
            id={p.id}
            cumle={planCumlesi(p, t)}
            aktif={p.aktif}
            son={sonCalismaCumlesi(sonlar.get(p.id), t, zaman)}
            ek={p.ertelenen_donem === buAy() ? t("otoKuralBuAyAtlanacak") : null}
            onAnahtar={(acik) => void yaz(`${UC.plan}/${p.id}`, "PATCH", { aktif: acik })}
            eylemler={
              <>
                <Dugme tur="ikincil" boy="kucuk"
                  onClick={() => void yaz(`${UC.plan}/${p.id}/ertele`, "POST", { donem: buAy() })}>
                  {t("otoKuralBuAyAtla")}
                </Dugme>
                <Dugme tur="ikincil" boy="kucuk" onClick={() => void sil(`${UC.plan}/${p.id}`)}>
                  {t("ortakSil")}
                </Dugme>
              </>
            }
          />
        ))}
        {(giderler.data?.items ?? []).map((g) => (
          <KuralSatiri
            key={g.id}
            id={g.id}
            cumle={giderCumlesi(g, t, tarih)}
            aktif={g.aktif}
            son={sonCalismaCumlesi(sonlar.get(g.id), t, zaman)}
            onAnahtar={(acik) => void yaz(`${UC.gider}/${g.id}`, "PATCH", { aktif: acik })}
            eylemler={
              <Dugme tur="ikincil" boy="kucuk" onClick={() => void sil(`${UC.gider}/${g.id}`)}>
                {t("ortakSil")}
              </Dugme>
            }
          />
        ))}
        {hatirlatma.data ? (
          <KuralSatiri
            id="borc_hatirlatma"
            cumle={hatirlatmaCumlesi(hatirlatma.data, t, dil)}
            aktif={hatirlatma.data.aktif}
            son={sonCalismaCumlesi(sonlar.get("borc_hatirlatma"), t, zaman)}
            ek={hOniz.data ? t("otoKuralBugunHatirlatma", { adet: hOniz.data.adet }) : null}
            onAnahtar={(acik) => void yaz(UC.hatirlatma, "PATCH", { aktif: acik })}
            eylemler={
              <a href="#hatirlatma-ayrinti" className="underline" style={{ fontSize: "var(--yz-fs-sm)" }}>
                {t("otoKuralAyarla")}
              </a>
            }
          />
        ) : null}
        {gecikme.data ? (
          <KuralSatiri
            id="gecikme_faizi"
            cumle={gecikmeCumlesi(gecikme.data, t)}
            aktif={gecikme.data.gecikme_uygula}
            son={sonCalismaCumlesi(sonlar.get("gecikme_faizi"), t, zaman)}
            ek={
              gOniz.data && gecikme.data.gecikme_uygula
                ? t("otoKuralBugunGecikme", {
                    adet: gecikmeAdet,
                    tutar: kurusToTL(gOniz.data.toplam_fark_kurus),
                  })
                : null
            }
            onAnahtar={(acik) => void yaz(UC.gecikme, "PATCH", { gecikme_uygula: acik })}
          />
        ) : null}
        {maas.data ? (
          <KuralSatiri
            id="maas"
            cumle={maasCumlesi(maas.data, t)}
            aktif={maas.data.aktif}
            son={sonCalismaCumlesi(sonlar.get("maas"), t, zaman)}
            onAnahtar={(acik) => void yaz(UC.maas, "PATCH", { aktif: acik })}
            eylemler={
              <>
                <label className="flex items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}
                  title={t("otoKuralMaasOtomatikIpucu")}>
                  <input
                    type="checkbox"
                    data-test="maas-otomatik-onay"
                    checked={maas.data.otomatik_onay}
                    onChange={(e) => void yaz(UC.maas, "PATCH", { otomatik_onay: e.target.checked })}
                  />
                  {t("otoKuralMaasOtomatik")}
                </label>
                <Dugme tur="ikincil" boy="kucuk" data-test="maas-calistir"
                  disabled={!maas.data.aktif || maas.data.gruplar.length === 0}
                  onClick={() => void maaslariCalistir()}>
                  {t("otoKuralMaasCalistir")}
                </Dugme>
              </>
            }
          />
        ) : null}
      </ul>
      {maas.data && maas.data.onay_bekleyenler.length > 0 ? (
        <MaasOnayBekleyenler
          satirlar={maas.data.onay_bekleyenler}
          onDegisti={() => void maas.mutate()}
        />
      ) : null}
      {bos ? (
        <p className="mt-2" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("otoKuralYok")}
        </p>
      ) : null}
      {sihirbaz ? (
        <KuralSihirbazi
          onKapat={() => setSihirbaz(false)}
          onKaydedildi={() => void Promise.all([planlar.mutate(), giderler.mutate()])}
        />
      ) : null}
      {diyalog}
    </Kart>
  );
}

// ------------------------ (P252 §2) MAAS ONAYI ---------------------------- #
/** Onay bekleyen maaslar: satir basina (tutar duzeltilebilir) ve toplu onay.
 *
 * Kismi ay maasi oranla hesaplanir ve HER ZAMAN onay bekler; yonetici
 * tutari burada duzeltip onaylar. Onay ayari kapaliyken yazilan tam ay
 * maaslari da burada toplanir ve tek tikla onaylanir. */
function MaasOnayBekleyenler({
  satirlar,
  onDegisti,
}: {
  satirlar: MaasKurali["onay_bekleyenler"];
  onDegisti: () => void;
}) {
  const { t, dil } = useI18n();
  const toast = useToast();
  const [tutarlar, setTutarlar] = useState<Record<string, string>>({});
  const [mesgul, setMesgul] = useState(false);

  async function tekOnay(id: string, varsayilan: number) {
    const metin = tutarlar[id];
    const kurus = metin === undefined || metin.trim() === "" ? varsayilan : tlToKurus(metin);
    if (kurus === null || kurus <= 0) {
      toast.error(t("calismaUcretGecersiz"));
      return;
    }
    setMesgul(true);
    try {
      await apiSend(`/api/panel/finans-hareketler/${id}/onayla`, "POST",
        kurus === varsayilan ? {} : { tutar_kurus: kurus });
      toast.success(t("otoMaasOnaylandi", { adet: 1 }));
      onDegisti();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  async function topluOnay() {
    setMesgul(true);
    try {
      const r = await apiSend<{ onaylanan: number }>(UC.maasOnayla, "POST", {
        ids: satirlar.map((s) => s.id),
      });
      toast.success(t("otoMaasOnaylandi", { adet: r.onaylanan }));
      onDegisti();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  return (
    <div className="mt-3 rounded-lg p-3" data-test="maas-onay-bekleyenler"
      style={{ background: "var(--yz-surface-2)" }}>
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 600, color: "var(--yz-text)" }}>
            {t("otoMaasOnayBaslik")}
          </h3>
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("otoMaasOnayAlt")}</p>
        </div>
        <Dugme tur="birincil" boy="kucuk" disabled={mesgul} data-test="maas-toplu-onay"
          onClick={() => void topluOnay()}>
          {t("otoMaasTumunuOnayla", { adet: satirlar.length })}
        </Dugme>
      </div>
      <ul className="divide-y">
        {satirlar.map((s) => (
          <li key={s.id} className="flex flex-wrap items-center justify-between gap-2 py-2"
            data-test={`maas-bekleyen-${s.id}`}>
            <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
              {s.aciklama}
              <span className="ms-2" style={{ color: "var(--yz-text-2)" }}>{saltTarihBicimi(s.tarih, dil)}</span>
            </span>
            <span className="flex items-center gap-2">
              <div className="w-32">
                <Alan
                  aria-label={t("finansSutunTutar")}
                  inputMode="decimal"
                  maxLength={ISTEMCI_SINIR.SAYI}
                  disabled={mesgul}
                  value={tutarlar[s.id] ?? kurusToTLSade(s.tutar_kurus)}
                  onChange={(e) => setTutarlar({ ...tutarlar, [s.id]: e.target.value })}
                />
              </div>
              <Dugme boy="kucuk" disabled={mesgul} onClick={() => void tekOnay(s.id, s.tutar_kurus)}>
                {t("otoMaasOnayla")}
              </Dugme>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

// ----------------------------- SIHIRBAZ ----------------------------------- #
type Siklik = "aylik" | "uc_aylik" | "alti_aylik" | "yillik";
type Tur = "borc" | "gider";
const SIKLIKLAR: readonly Siklik[] = ["aylik", "uc_aylik", "alti_aylik", "yillik"];
const PAYLASIMLAR = ["daire_basina", "esit", "arsa_payi", "metrekare"] as const;
const ADIMLAR: readonly SozlukAnahtari[] = [
  "otoSihirbazNeZaman", "otoSihirbazKime", "otoSihirbazNe", "otoSihirbazOnizleme",
];
const SON_ADIM = 3;
const TUR_BORC: Tur = "borc";
const TUR_GIDER: Tur = "gider";
const DUGME_BIRINCIL = "birincil" as const;
const DUGME_IKINCIL = "ikincil" as const;

export function KuralSihirbazi({
  onKapat,
  onKaydedildi,
}: {
  onKapat: () => void;
  onKaydedildi: () => void;
}) {
  const { t, dil } = useI18n();
  const toast = useToast();
  const tanimlar = useGelirGiderTanimlari();
  const kasalar = useKasalar();
  const [adim, setAdim] = useState(0);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);
  // 1) ne zaman
  const [siklik, setSiklik] = useState<Siklik>("aylik");
  const [gun, setGun] = useState("1");
  const [ilkTarih, setIlkTarih] = useState("");
  // 2) kime
  const [tur, setTur] = useState<Tur | null>(null);
  const [paylasim, setPaylasim] = useState<(typeof PAYLASIMLAR)[number]>("daire_basina");
  // 3) ne yapilsin
  const [ad, setAd] = useState("");
  const [tanimId, setTanimId] = useState("");
  const [tutar, setTutar] = useState("");
  const [vade, setVade] = useState("10");
  const [kasaId, setKasaId] = useState("");
  const [otomatik, setOtomatik] = useState(false);
  // 4) onizleme
  const [onizleme, setOnizleme] = useState<Onizleme | null>(null);

  const gunSayi = Number(gun);
  const kurus = tlToKurus(tutar) ?? 0;
  // Borc yazma yalniz aylik: plan ayin bir gununde calisir.
  useEffect(() => {
    if (siklik !== "aylik" && tur === TUR_BORC) setTur(null);
  }, [siklik, tur]);

  function planGovdesi() {
    return {
      ad: ad.trim(),
      gelir_gider_tanim_id: tanimId,
      dagitim: paylasim,
      tutar_kurus: paylasim === "daire_basina" ? kurus : null,
      toplam_tutar_kurus: paylasim === "daire_basina" ? null : kurus,
      tahakkuk_gunu: gunSayi,
      vade_gun: Number(vade) || 0,
      onizleme_gun: 3,
    };
  }
  function giderGovdesi() {
    return {
      ad: ad.trim(),
      tutar_kurus: kurus,
      periyot: siklik,
      sonraki_tarih: siklik === "aylik" ? ilkAylikTarih(gunSayi) : ilkTarih,
      kasa_id: kasaId || null,
      otomatik_onay: otomatik,
    };
  }

  function adimGecerli(): boolean {
    if (adim === 0) {
      return siklik === "aylik" ? gunSayi >= 1 && gunSayi <= 28 : /^\d{4}-\d{2}-\d{2}$/.test(ilkTarih);
    }
    if (adim === 1) return tur !== null;
    if (adim === 2) {
      if (!ad.trim() || kurus <= 0) return false;
      return tur === TUR_GIDER || Boolean(tanimId);
    }
    return true;
  }

  async function ileri() {
    if (!adimGecerli()) {
      setHata(t("otoSihirbazEksik"));
      return;
    }
    setHata(null);
    if (adim === 2) {
      setOnizleme(null);
      if (tur === TUR_BORC) {
        setMesgul(true);
        try {
          setOnizleme(await apiSend<Onizleme>(UC.planOnizleme, "POST", planGovdesi()));
        } catch (e) {
          setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
          return;
        } finally {
          setMesgul(false);
        }
      }
    }
    setAdim((a) => Math.min(a + 1, SON_ADIM));
  }

  async function kaydet() {
    setMesgul(true);
    setHata(null);
    try {
      if (tur === TUR_BORC) await apiSend(UC.plan, "POST", planGovdesi());
      else await apiSend(UC.gider, "POST", giderGovdesi());
      toast.success(t("finansKaydedildi"));
      onKaydedildi();
      onKapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  const tarih = (iso: string) => saltTarihBicimi(iso, dil);
  const radyo = (secili: boolean) => ({
    borderWidth: "var(--yz-border-w)",
    borderStyle: CIZGI,
    borderColor: secili ? KENAR_SECILI : KENAR,
    borderRadius: "var(--yz-radius-btn)",
  });

  return (
    <Modal
      acik
      onKapat={onKapat}
      baslik={t("otoKuralYeni")}
      eylemler={
        <span className="flex gap-2">
          {adim > 0 ? (
            <Dugme tur={DUGME_IKINCIL} disabled={mesgul} onClick={() => { setHata(null); setAdim(adim - 1); }}>
              {t("otoSihirbazGeri")}
            </Dugme>
          ) : (
            <Dugme tur={DUGME_IKINCIL} onClick={onKapat}>{t("ortakIptal")}</Dugme>
          )}
          {adim < SON_ADIM ? (
            <Dugme tur={DUGME_BIRINCIL} disabled={mesgul} data-test="sihirbaz-ileri" onClick={() => void ileri()}>
              {t("otoSihirbazIleri")}
            </Dugme>
          ) : (
            <Dugme tur={DUGME_BIRINCIL} disabled={mesgul} data-test="sihirbaz-kaydet" onClick={() => void kaydet()}>
              {t("otoSihirbazKaydet")}
            </Dugme>
          )}
        </span>
      }
    >
      <p className="mb-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {t("otoSihirbazAdim", { n: adim + 1, toplam: ADIMLAR.length })}
      </p>
      <h3 className="mb-3" data-test="sihirbaz-baslik" style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t(ADIMLAR[adim])}
      </h3>

      {adim === 0 ? (
        <div className="space-y-3">
          <fieldset className="grid gap-2 sm:grid-cols-2">
            <legend className="sr-only">{t("otoSihirbazNeZaman")}</legend>
            {SIKLIKLAR.map((s) => (
              <label key={s} className="flex items-center gap-2 p-2" style={radyo(siklik === s)}>
                <input type="radio" name="siklik" checked={siklik === s} onChange={() => setSiklik(s)} />
                {t(SIKLIK[s])}
              </label>
            ))}
          </fieldset>
          {siklik === "aylik" ? (
            <AlanSarmal etiket={t("otoSihirbazAyinGunu")} ipucu={t("otoSihirbazGunIpucu")}>
              {(b) => (
                <Alan {...b} type="number" min={1} max={28} value={gun}
                  onChange={(e) => setGun(e.target.value)} />
              )}
            </AlanSarmal>
          ) : (
            <AlanSarmal etiket={t("otoSihirbazIlkTarih")}>
              {(b) => (
                <Alan {...b} type="date" value={ilkTarih} onChange={(e) => setIlkTarih(e.target.value)} />
              )}
            </AlanSarmal>
          )}
        </div>
      ) : null}

      {adim === 1 ? (
        <div className="space-y-3">
          <fieldset className="grid gap-2">
            <legend className="sr-only">{t("otoSihirbazKime")}</legend>
            <label className="flex items-start gap-2 p-2" style={radyo(tur === TUR_BORC)}>
              <input type="radio" name="tur" checked={tur === TUR_BORC}
                disabled={siklik !== "aylik"} onChange={() => setTur(TUR_BORC)} />
              <span>
                <span className="block font-medium">{t("otoSihirbazKimeDaireler")}</span>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {siklik === "aylik" ? t("otoSihirbazKimeDairelerAlt") : t("otoSihirbazYalnizAylik")}
                </span>
              </span>
            </label>
            <label className="flex items-start gap-2 p-2" style={radyo(tur === TUR_GIDER)}>
              <input type="radio" name="tur" checked={tur === TUR_GIDER} onChange={() => setTur(TUR_GIDER)} />
              <span>
                <span className="block font-medium">{t("otoSihirbazKimeGider")}</span>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {t("otoSihirbazKimeGiderAlt")}
                </span>
              </span>
            </label>
          </fieldset>
          {tur === TUR_BORC ? (
            <AlanSarmal etiket={t("otoSihirbazPaylasim")}>
              {(b) => (
                <Secim {...b} value={paylasim}
                  onChange={(e) => setPaylasim(e.target.value as (typeof PAYLASIMLAR)[number])}>
                  {PAYLASIMLAR.map((p) => <option key={p} value={p}>{t(PAYLASIM[p])}</option>)}
                </Secim>
              )}
            </AlanSarmal>
          ) : null}
        </div>
      ) : null}

      {adim === 2 ? (
        <div className="grid gap-3">
          <AlanSarmal etiket={t("otoSihirbazAd")} ipucu={t("otoSihirbazAdOrnek")} zorunlu>
            {(b) => <Alan maxLength={SINIR.AD} {...b} value={ad} onChange={(e) => setAd(e.target.value)} />}
          </AlanSarmal>
          {tur === TUR_BORC ? (
            <AlanSarmal etiket={t("otoSihirbazKalem")} zorunlu>
              {(b) => (
                <Secim {...b} value={tanimId} onChange={(e) => setTanimId(e.target.value)}>
                  <option value="">{t("finansTurSec")}</option>
                  {tanimlar.map((g) => <option key={g.id} value={g.id}>{g.ad}</option>)}
                </Secim>
              )}
            </AlanSarmal>
          ) : null}
          <AlanSarmal
            etiket={t(tutarEtiketi(tur, paylasim))}
            zorunlu
          >
            {(b) => (
              <Alan maxLength={ISTEMCI_SINIR.SAYI} {...b} value={tutar} inputMode="decimal"
                onChange={(e) => setTutar(e.target.value)} />
            )}
          </AlanSarmal>
          {tur === TUR_BORC ? (
            <AlanSarmal etiket={t("otoSihirbazVade")}>
              {(b) => (
                <Alan {...b} type="number" min={0} max={90} value={vade}
                  onChange={(e) => setVade(e.target.value)} />
              )}
            </AlanSarmal>
          ) : (
            <>
              <AlanSarmal etiket={t("otoSihirbazKasa")}>
                {(b) => (
                  <Secim {...b} value={kasaId} onChange={(e) => setKasaId(e.target.value)}>
                    <option value="">—</option>
                    {kasalar.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
                  </Secim>
                )}
              </AlanSarmal>
              <label className="flex items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
                <input type="checkbox" checked={otomatik} onChange={(e) => setOtomatik(e.target.checked)} />
                {t("otoSihirbazOtomatikOnay")}
              </label>
            </>
          )}
        </div>
      ) : null}

      {adim === 3 ? (
        <div className="space-y-2" data-test="sihirbaz-onizleme">
          <p style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 600, color: "var(--yz-text)" }}>
            {tur === TUR_BORC
              ? planCumlesi(planGovdesi(), t)
              : giderCumlesi(giderGovdesi(), t, tarih)}
          </p>
          {tur === TUR_BORC && onizleme ? (
            <>
              <p data-test="sihirbaz-bugun" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                {t("otoKuralBugunPlan", { adet: onizleme.adet, tutar: kurusToTL(onizleme.toplam_kurus) })}
              </p>
              {onizleme.atlanan > 0 ? (
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
                  {t("otoKuralBugunAtlanan", { adet: onizleme.atlanan })}
                </p>
              ) : null}
              {onizleme.ilk_tarih ? (
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {t("otoKuralIlkCalisma", { tarih: tarih(onizleme.ilk_tarih) })}
                </p>
              ) : null}
            </>
          ) : null}
          {tur === TUR_GIDER ? (
            <p data-test="sihirbaz-bugun" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
              {t("otoKuralBugunGider", {
                tutar: kurusToTL(kurus),
                tarih: tarih(giderGovdesi().sonraki_tarih),
              })}
            </p>
          ) : null}
        </div>
      ) : null}

      <div className="mt-3">
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
