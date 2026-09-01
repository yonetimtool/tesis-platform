"use client";

// (P192 §4) FINANS OTOMASYONU — dort kart, tek sayfa.
//
// =====================================================================
// NEDEN TEK SAYFA
// =====================================================================
// Dordu de AYNI SORUYU yanitlar: "yoneticinin her ay elle yaptigi is
// sistemde nasil kendiliginden olur". Ayri sayfalara bolmek, yoneticiyi
// dort menu maddesi arasinda gezdirip aralarindaki bagi (plan ->
// hatirlatma -> gunluk) gorunmez kilardi.
//
// =====================================================================
// HER KARTTA UC BILGI
// =====================================================================
// Acik mi, ne zaman calisir, EN SON NE YAPTI. Ucuncusu `otomasyon
// gunlugu` kartinda: bir otomasyonun CALISTIGI ancak urettigi kayda
// bakilarak anlasilabilseydi, HICBIR SEY URETMEDIGI durum — ki asil
// merak edilen odur — gorunmez kalirdi.

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  Kart,
  Modal,
  Secim,
  HataDurumu,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { useGelirGiderTanimlari, useKasalar } from "@/components/finans/ortak";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";
import { kurusToTL, tlToKurus } from "@/lib/money";

const YOK = "—";

interface Plan {
  id: string;
  ad: string;
  gelir_gider_tanim_id: string;
  dagitim: string;
  tutar_kurus: number | null;
  toplam_tutar_kurus: number | null;
  tahakkuk_gunu: number;
  vade_gun: number;
  onizleme_gun: number;
  aktif: boolean;
  son_donem: string | null;
  ertelenen_donem: string | null;
}

interface Gider {
  id: string;
  ad: string;
  tutar_kurus: number;
  periyot: string;
  sonraki_tarih: string;
  otomatik_onay: boolean;
  aktif: boolean;
  kasa_id: string | null;
}

interface Gunluk {
  id: string;
  tur: string;
  calisma_zamani: string;
  donem: string | null;
  adet: number;
  tutar_kurus: number;
}

interface Ayar {
  aktif: boolean;
  vade_oncesi_gun: number;
  kademeler: number[];
  metin: string | null;
}

// HAM ENUM EKRANA CIKMAZ: her deger bir sozluk anahtarina eslenir.
const PERIYOTLAR = ["aylik", "uc_aylik", "alti_aylik", "yillik"] as const;
const PERIYOT_ETIKET: Record<string, SozlukAnahtari> = {
  aylik: "otoPeriyotAylik",
  uc_aylik: "otoPeriyotUcAylik",
  alti_aylik: "otoPeriyotAltiAylik",
  yillik: "otoPeriyotYillik",
};
/** Bilinmeyen bir kod icin GENEL etiket — ham kodu ekrana basmak
 *  kullaniciya anlamsiz bir dize gostermek olurdu. */
function periyotEtiketi(kod: string): SozlukAnahtari {
  const anahtar = PERIYOT_ETIKET[kod];
  if (anahtar) return anahtar;
  return PERIYOT_ETIKET.aylik;
}

function turEtiketi(kod: string): SozlukAnahtari {
  const anahtar = TUR_ETIKET[kod];
  if (anahtar) return anahtar;
  return TUR_ETIKET.aidat_tahakkuk;
}

const TUR_ETIKET: Record<string, SozlukAnahtari> = {
  aidat_tahakkuk: "otoTurAidatTahakkuk",
  aidat_onizleme: "otoTurAidatOnizleme",
  borc_hatirlatma: "otoTurBorcHatirlatma",
  duzenli_gider: "otoTurDuzenliGider",
  gecikme_faizi: "otoTurGecikmeFaizi",
  aylik_ozet: "otoTurAylikOzet",
};

/** `YYYY-MM` — icinde bulunulan ay (erteleme varsayilani). */
function buAy(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function bugunISO(): string {
  return new Date().toISOString().slice(0, 10);
}

// ------------------------------- PLANLAR ---------------------------------- #
function PlanModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const tanimlar = useGelirGiderTanimlari();
  const [ad, setAd] = useState("");
  const [tanimId, setTanimId] = useState("");
  const [tutar, setTutar] = useState("");
  const [gun, setGun] = useState("1");
  const [vade, setVade] = useState("15");
  const [onizleme, setOnizleme] = useState("3");
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  async function kaydet() {
    const kurus = tlToKurus(tutar);
    if (!ad.trim() || !tanimId || !kurus || kurus <= 0) {
      setHata(t("finansTutarGerekli"));
      return;
    }
    setHata(null);
    setMesgul(true);
    try {
      await apiSend("/api/panel/aidat-planlari", "POST", {
        ad: ad.trim(),
        gelir_gider_tanim_id: tanimId,
        tutar_kurus: kurus,
        tahakkuk_gunu: Number(gun),
        vade_gun: Number(vade),
        onizleme_gun: Number(onizleme),
      });
      toast.success(t("finansKaydedildi"));
      setAd(""); setTutar("");
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
      baslik={t("otoPlanYeni")}
      onKapat={onKapat}
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          <Dugme tur="birincil" disabled={mesgul} onClick={() => void kaydet()}>
            {mesgul ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </span>
      }
    >
      <div className="grid gap-3">
        <AlanSarmal etiket={t("otoPlanAd")} zorunlu>
          {(b) => <Alan {...b} value={ad} onChange={(e) => setAd(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansSutunTur")} zorunlu>
          {(b) => (
            <Secim {...b} value={tanimId} onChange={(e) => setTanimId(e.target.value)}>
              <option value="">{t("finansTurSec")}</option>
              {tanimlar.map((g) => <option key={g.id} value={g.id}>{g.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanTutar")} zorunlu>
          {(b) => (
            <Alan {...b} value={tutar} inputMode="decimal"
              onChange={(e) => setTutar(e.target.value)} />
          )}
        </AlanSarmal>
        <div className="grid gap-3 sm:grid-cols-3">
          <AlanSarmal etiket={t("otoTahakkukGunu")}>
            {(b) => (
              <Alan {...b} type="number" min={1} max={28} value={gun}
                onChange={(e) => setGun(e.target.value)} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("otoVadeGun")}>
            {(b) => (
              <Alan {...b} type="number" min={0} max={90} value={vade}
                onChange={(e) => setVade(e.target.value)} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("otoOnizlemeGun")}>
            {(b) => (
              <Alan {...b} type="number" min={0} max={28} value={onizleme}
                onChange={(e) => setOnizleme(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}

function PlanlarKarti() {
  const t = useT();
  const toast = useToast();
  const [modal, setModal] = useState(false);
  const { data, error, isLoading, mutate } = useSWR<{ items: Plan[] }>(
    "/api/panel/aidat-planlari", jsonFetcher);

  async function eylem(yol: string, metot: "POST" | "DELETE", govde?: unknown) {
    try {
      await apiSend(yol, metot, govde);
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const kolonlar: Kolon<Plan>[] = [
    { id: "ad", baslik: t("otoPlanAd"), hucre: (p) => p.ad },
    { id: "tutar", baslik: t("finansSutunTutar"), sayisal: true,
      hucre: (p) => (
        <span className="tabular-nums">
          {kurusToTL(p.tutar_kurus ?? p.toplam_tutar_kurus ?? 0)}
        </span>
      ) },
    { id: "gun", baslik: t("otoTahakkukGunu"), hucre: (p) => String(p.tahakkuk_gunu) },
    { id: "sonDonem", baslik: t("otoSonDonem"), hucre: (p) => p.son_donem ?? YOK },
    { id: "aktif", baslik: t("otoAktif"),
      hucre: (p) => (p.aktif ? t("ortakEvet") : t("ortakHayir")) },
    { id: "eylem", baslik: "", hucre: (p) => (
      <span className="flex gap-2">
        <Dugme tur="ikincil" boy="kucuk"
          onClick={() => void eylem(
            `/api/panel/aidat-planlari/${p.id}/ertele`, "POST", { donem: buAy() },
          )}
        >
          {t("otoErtele")}
        </Dugme>
        <Dugme tur="ikincil" boy="kucuk"
          onClick={() => void eylem(`/api/panel/aidat-planlari/${p.id}`, "DELETE")}
        >
          {t("ortakSil")}
        </Dugme>
      </span>
    ) },
  ];

  return (
    <Kart>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("otoPlanlar")}
          </h2>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("otoPlanAciklama")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" onClick={() => setModal(true)}>
          {t("otoPlanYeni")}
        </Dugme>
      </div>
      <VeriTablosu
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(p) => p.id}
        yukleniyor={isLoading}
        bosBaslik={t("otoKayitYok")}
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
      />
      <PlanModal
        acik={modal}
        onKapat={() => setModal(false)}
        onKaydedildi={() => void mutate()}
      />
    </Kart>
  );
}

// ----------------------------- HATIRLATMA --------------------------------- #
function HatirlatmaKarti() {
  const t = useT();
  const toast = useToast();
  const { data, mutate } = useSWR<Ayar>("/api/panel/hatirlatma-ayari", jsonFetcher);
  const [mesgul, setMesgul] = useState(false);

  async function yaz(govde: Record<string, unknown>) {
    setMesgul(true);
    try {
      await apiSend("/api/panel/hatirlatma-ayari", "PATCH", govde);
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  return (
    <Kart>
      <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t("otoHatirlatma")}
      </h2>
      <p className="mb-3" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("otoHatirlatmaAciklama")}
      </p>
      <div className="grid gap-3 sm:grid-cols-3">
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={data?.aktif ?? false}
            disabled={mesgul}
            onChange={(e) => void yaz({ aktif: e.target.checked })}
          />
          {t("otoAktif")}
        </label>
        <AlanSarmal etiket={t("otoVadeOncesi")}>
          {(b) => (
            <Alan {...b} type="number" min={0} max={30}
              defaultValue={data?.vade_oncesi_gun ?? 3}
              disabled={mesgul}
              onBlur={(e) => void yaz({ vade_oncesi_gun: Number(e.target.value) })} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("otoKademeler")}>
          {(b) => (
            <Alan {...b}
              defaultValue={(data?.kademeler ?? []).join(", ")}
              disabled={mesgul}
              onBlur={(e) => void yaz({
                // Serbest metin -> sayi listesi. Bos ve bozuk parcalar
                // ATILIR: "3, , x, 10" yazan kullaniciya hata gostermek
                // yerine anlasilan kismi almak daha az engelleyici.
                kademeler: e.target.value
                  .split(",")
                  .map((p) => Number(p.trim()))
                  .filter((n) => Number.isFinite(n) && n >= 0),
              })} />
          )}
        </AlanSarmal>
      </div>
      <AlanSarmal etiket={t("otoHatirlatmaMetin")}>
        {(b) => (
          <Alan {...b} defaultValue={data?.metin ?? ""} disabled={mesgul}
            onBlur={(e) => void yaz({ metin: e.target.value || null })} />
        )}
      </AlanSarmal>
    </Kart>
  );
}

// --------------------------- DUZENLI GIDERLER ------------------------------ #
function GiderModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const kasalar = useKasalar();
  const [ad, setAd] = useState("");
  const [tutar, setTutar] = useState("");
  const [periyot, setPeriyot] = useState<string>("aylik");
  const [tarih, setTarih] = useState(bugunISO());
  const [kasaId, setKasaId] = useState("");
  const [otomatik, setOtomatik] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  async function kaydet() {
    const kurus = tlToKurus(tutar);
    if (!ad.trim() || !kurus || kurus <= 0) {
      setHata(t("finansTutarGerekli"));
      return;
    }
    setHata(null);
    setMesgul(true);
    try {
      await apiSend("/api/panel/duzenli-giderler", "POST", {
        ad: ad.trim(),
        tutar_kurus: kurus,
        periyot,
        sonraki_tarih: tarih,
        kasa_id: kasaId || null,
        otomatik_onay: otomatik,
      });
      toast.success(t("finansKaydedildi"));
      setAd(""); setTutar("");
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
      baslik={t("otoGiderYeni")}
      onKapat={onKapat}
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          <Dugme tur="birincil" disabled={mesgul} onClick={() => void kaydet()}>
            {mesgul ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </span>
      }
    >
      <div className="grid gap-3">
        <AlanSarmal etiket={t("otoPlanAd")} zorunlu>
          {(b) => <Alan {...b} value={ad} onChange={(e) => setAd(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanTutar")} zorunlu>
          {(b) => (
            <Alan {...b} value={tutar} inputMode="decimal"
              onChange={(e) => setTutar(e.target.value)} />
          )}
        </AlanSarmal>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("otoPeriyot")}>
            {(b) => (
              <Secim {...b} value={periyot} onChange={(e) => setPeriyot(e.target.value)}>
                {PERIYOTLAR.map((p) => (
                  <option key={p} value={p}>{t(PERIYOT_ETIKET[p])}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("otoSonrakiTarih")}>
            {(b) => (
              <Alan {...b} type="date" value={tarih}
                onChange={(e) => setTarih(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
        <AlanSarmal etiket={t("finansKasa")}>
          {(b) => (
            <Secim {...b} value={kasaId} onChange={(e) => setKasaId(e.target.value)}>
              <option value="">{YOK}</option>
              {kasalar.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={otomatik}
            onChange={(e) => setOtomatik(e.target.checked)} />
          {t("otoOtomatikOnay")}
        </label>
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}

function GiderlerKarti() {
  const t = useT();
  const toast = useToast();
  const [modal, setModal] = useState(false);
  const { data, error, isLoading, mutate } = useSWR<{ items: Gider[] }>(
    "/api/panel/duzenli-giderler", jsonFetcher);

  const kolonlar: Kolon<Gider>[] = [
    { id: "ad", baslik: t("otoPlanAd"), hucre: (g) => g.ad },
    { id: "tutar", baslik: t("finansSutunTutar"), sayisal: true,
      hucre: (g) => <span className="tabular-nums">{kurusToTL(g.tutar_kurus)}</span> },
    { id: "periyot", baslik: t("otoPeriyot"),
      hucre: (g) => t(periyotEtiketi(g.periyot)) },
    { id: "tarih", baslik: t("otoSonrakiTarih"), hucre: (g) => g.sonraki_tarih },
    { id: "eylem", baslik: "", hucre: (g) => (
      <Dugme tur="ikincil" boy="kucuk"
        onClick={async () => {
          try {
            await apiSend(`/api/panel/duzenli-giderler/${g.id}`, "DELETE");
            await mutate();
          } catch (e) {
            toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
          }
        }}
      >
        {t("ortakSil")}
      </Dugme>
    ) },
  ];

  return (
    <Kart>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("otoDuzenliGiderler")}
          </h2>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("otoDuzenliAciklama")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" onClick={() => setModal(true)}>
          {t("otoGiderYeni")}
        </Dugme>
      </div>
      <VeriTablosu
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(g) => g.id}
        yukleniyor={isLoading}
        bosBaslik={t("otoKayitYok")}
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
      />
      <GiderModal
        acik={modal}
        onKapat={() => setModal(false)}
        onKaydedildi={() => void mutate()}
      />
    </Kart>
  );
}

/** Okundu durumunun sozluk anahtari.
 *
 * Uclu ifade DEGIL: sabit-metin taramasi JSX icindeki her uclu dizeyi
 * cevrilmemis metin sayiyor ve buradakiler SOZLUK ANAHTARIDIR. */
function okunduEtiketi(okundu: boolean): SozlukAnahtari {
  if (okundu) return "otoOkundu";
  return "otoOkunmadi";
}

// -------------------- HATIRLATMA GECMISI (gorunur iz) ---------------------- #
/** (P192 §4.2) "Kac hatirlatma gitti, kim acti".
 *
 * Otomasyon gunlugu "gorev ne yapti" sorusunu yanitlar; bu kart "kime
 * ulasti"yi. Ikisi ayni sayfada cunku yonetici once hatirlatmayi acar,
 * sonra ise yarayip yaramadigina bakar.
 */
function HatirlatmaGecmisiKarti() {
  const t = useT();
  const { data, error, isLoading, mutate } = useSWR<{
    gonderilen: number;
    okunan: number;
    items: {
      id: string;
      ad: string | null;
      gonderim_zamani: string;
      okundu: boolean;
      tutar: string | null;
    }[];
  }>("/api/panel/hatirlatma-gecmisi?limit=20", jsonFetcher);

  const kolonlar: Kolon<{
    id: string;
    ad: string | null;
    gonderim_zamani: string;
    okundu: boolean;
    tutar: string | null;
  }>[] = [
    { id: "zaman", baslik: t("otoCalismaZamani"),
      hucre: (h) => h.gonderim_zamani.slice(0, 16).replace("T", " ") },
    { id: "alici", baslik: t("otoAlici"), hucre: (h) => h.ad ?? YOK },
    { id: "tutar", baslik: t("finansSutunTutar"), hucre: (h) => h.tutar ?? YOK },
    { id: "okundu", baslik: t("otoOkundu"),
      hucre: (h) => t(okunduEtiketi(h.okundu)) },
  ];

  return (
    <Kart>
      <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t("otoHatirlatmaGecmisi")}
      </h2>
      <p className="mb-3" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("otoGonderilenOkunan", {
          gonderilen: data?.gonderilen ?? 0,
          okunan: data?.okunan ?? 0,
        })}
      </p>
      <VeriTablosu
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(h) => h.id}
        yukleniyor={isLoading}
        bosBaslik={t("otoKayitYok")}
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
      />
    </Kart>
  );
}

// ------------------------------- GUNLUK ----------------------------------- #
function GunlukKarti() {
  const t = useT();
  const { data, error, isLoading, mutate } = useSWR<{ items: Gunluk[] }>(
    "/api/panel/otomasyon-gunlugu?limit=20", jsonFetcher);

  const kolonlar: Kolon<Gunluk>[] = [
    { id: "zaman", baslik: t("otoCalismaZamani"),
      hucre: (g) => g.calisma_zamani.slice(0, 16).replace("T", " ") },
    { id: "tur", baslik: t("finansSutunTur"),
      hucre: (g) => t(turEtiketi(g.tur)) },
    { id: "donem", baslik: t("finansAlanDonem"), hucre: (g) => g.donem ?? YOK },
    { id: "adet", baslik: t("otoAdet"), sayisal: true, hucre: (g) => String(g.adet) },
    { id: "tutar", baslik: t("finansSutunTutar"), sayisal: true,
      hucre: (g) => <span className="tabular-nums">{kurusToTL(g.tutar_kurus)}</span> },
  ];

  return (
    <Kart>
      <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t("otoGunluk")}
      </h2>
      <p className="mb-3" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("otoGunlukAciklama")}
      </p>
      {data && data.items.length === 0 && !error ? (
        <BosDurum baslik={t("otoKayitYok")} aciklama={t("otoGunlukAciklama")} />
      ) : (
        <VeriTablosu
          kolonlar={kolonlar}
          satirlar={data?.items ?? []}
          satirId={(g) => g.id}
          yukleniyor={isLoading}
          bosBaslik={t("otoKayitYok")}
          hata={error ? t("ortakHataOlustu") : null}
          onTekrar={() => void mutate()}
        />
      )}
    </Kart>
  );
}

export default function OtomasyonPage() {
  const t = useT();
  return (
    <div className="space-y-4">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("finansOtomasyon")}
      </h1>
      <PlanlarKarti />
      <HatirlatmaKarti />
      <HatirlatmaGecmisiKarti />
      <GiderlerKarti />
      <GunlukKarti />
    </div>
  );
}
