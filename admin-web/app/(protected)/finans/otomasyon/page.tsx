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

import { useEffect, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  Kart,
  Modal,
  HataDurumu,
  Rozet,
  SayfaBasligi,
  Secim,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { KurallarKarti } from "@/components/otomasyon/kurallar";
import { hatirlatmaCumlesi } from "@/lib/otomasyon-cumle";
import { teslimAciklamasi } from "@/lib/teslim-durumu";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useI18n, useT } from "@/lib/i18n/kullan";
import { tarihSaatBicimi } from "@/lib/tarih";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";
import { kurusToTL, tlToKurus } from "@/lib/money";
import { ISTEMCI_SINIR, SINIR } from "@/lib/girdi-siniri";

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
  // (P250 §7)
  eposta: boolean;
  ilk_gun: number | null;
  tekrar_sayisi: number;
  aralik_gun: number | null;
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
  maas: "otoTurMaas",
};

/** `YYYY-MM` — icinde bulunulan ay (erteleme varsayilani). */
function buAy(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function bugunISO(): string {
  return new Date().toISOString().slice(0, 10);
}

// ----------------------------- HATIRLATMA --------------------------------- #
function HatirlatmaKarti() {
  const t = useT();
  const { dil } = useI18n();
  const toast = useToast();
  const { data, mutate } = useSWR<Ayar>("/api/panel/hatirlatma-ayari", jsonFetcher);
  const [mesgul, setMesgul] = useState(false);
  const [ilk, setIlk] = useState("");
  const [tekrar, setTekrar] = useState("");
  const [aralik, setAralik] = useState("");

  useEffect(() => {
    if (!data) return;
    setIlk(String(data.ilk_gun ?? 3));
    setTekrar(String(data.tekrar_sayisi || 3));
    setAralik(String(data.aralik_gun ?? 7));
  }, [data]);

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

  // UCU BIRLIKTE gider (sunucu kademeleri bunlardan uretir). YALNIZ
  // DEGISTIYSE: alandan cikmak tek basina kayit tetiklemesin (her
  // odak gecisi gereksiz bir yazma ve kademeleri duzene sokma olurdu).
  function plani_yaz() {
    const yeni = {
      ilk_gun: Number(ilk) || 0,
      tekrar_sayisi: Math.max(1, Number(tekrar) || 1),
      aralik_gun: Math.max(1, Number(aralik) || 1),
    };
    if (
      data &&
      yeni.ilk_gun === data.ilk_gun &&
      yeni.tekrar_sayisi === data.tekrar_sayisi &&
      yeni.aralik_gun === data.aralik_gun
    ) {
      return;
    }
    void yaz(yeni);
  }

  return (
    <div id="hatirlatma-ayrinti">
    <Kart>
      <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t("otoHatirlatma")}
      </h2>
      <p className="mb-2" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("otoHatirlatmaAciklama")}
      </p>
      {data && (
        <p
          data-test="hatirlatma-cumlesi"
          className="mb-3 font-medium"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
        >
          {hatirlatmaCumlesi(data, t, dil)}
        </p>
      )}
      <div className="mb-3 flex flex-wrap gap-4">
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            data-test="hatirlatma-aktif"
            checked={data?.aktif ?? false}
            onChange={(e) => void yaz({ aktif: e.target.checked })}
          />
          {t("otoAktif")}
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            data-test="hatirlatma-eposta"
            checked={data?.eposta ?? true}
            onChange={(e) => void yaz({ eposta: e.target.checked })}
          />
          {t("otoHatirlatmaEposta")}
        </label>
      </div>
      <div className="grid gap-3 sm:grid-cols-4">
        <AlanSarmal etiket={t("otoHatirlatmaIlkGun")}>
          {(b) => (
            <Alan {...b} data-test="hatirlatma-ilk" inputMode="numeric" maxLength={2}
              value={ilk} disabled={mesgul}
              onChange={(e) => setIlk(e.target.value.replace(/\D/g, ""))}
              onBlur={plani_yaz} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("otoHatirlatmaTekrar")}>
          {(b) => (
            <Alan {...b} data-test="hatirlatma-tekrar" inputMode="numeric" maxLength={1}
              value={tekrar} disabled={mesgul}
              onChange={(e) => setTekrar(e.target.value.replace(/\D/g, ""))}
              onBlur={plani_yaz} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("otoHatirlatmaAralik")}>
          {(b) => (
            <Alan {...b} data-test="hatirlatma-aralik" inputMode="numeric" maxLength={2}
              value={aralik} disabled={mesgul}
              onChange={(e) => setAralik(e.target.value.replace(/\D/g, ""))}
              onBlur={plani_yaz} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("otoVadeOncesi")}>
          {(b) => (
            <Alan {...b} type="number" min={0} max={30}
              defaultValue={data?.vade_oncesi_gun ?? 3}
              disabled={mesgul}
              onBlur={(e) => void yaz({ vade_oncesi_gun: Number(e.target.value) })} />
          )}
        </AlanSarmal>
      </div>
      <p className="mt-2" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {t("otoHatirlatmaKimeNotu")}
      </p>
      <AlanSarmal etiket={t("otoHatirlatmaMetin")} ipucu={t("otoHatirlatmaMetinNotu")}>
        {(b) => (
          <Alan maxLength={1000 /* sunucu: HatirlatmaAyariUpdate.metin */} {...b} defaultValue={data?.metin ?? ""} disabled={mesgul}
            onBlur={(e) => void yaz({ metin: e.target.value || null })} />
        )}
      </AlanSarmal>
    </Kart>
    </div>
  );
}

// (P250 §7) OTOMATIK HATIRLATMA E-POSTALARI — teslim durumuyla.
const EPOSTA_DURUM_METNI: Record<string, SozlukAnahtari> = {
  kuyrukta: "odemeKoduDurumkuyrukta",
  gonderildi: "odemeKoduDurumgonderildi",
  iletildi: "odemeKoduDurumiletildi",
  geri_dondu: "odemeKoduDurumgeri_dondu",
  basarisiz: "odemeKoduDurumbasarisiz",
  yapilandirilmadi: "odemeKoduDurumyapilandirilmadi",
};
const EPOSTA_DURUM_YEDEK: SozlukAnahtari = "odemeKoduDurumbasarisiz";

function HatirlatmaEpostalariKarti() {
  const t = useT();
  const { data } = useSWR<{ items: { id: string; ad: string | null; gonderim_zamani: string; durum: string }[] }>(
    "/api/panel/hatirlatma-epostalari?limit=20",
    jsonFetcher,
  );
  const ogeler = data?.items ?? [];
  return (
    <Kart>
      <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t("otoEpostaGecmisi")}
      </h2>
      {ogeler.length === 0 ? (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("otoEpostaGecmisiBos")}
        </p>
      ) : (
        <ul className="divide-y" data-test="hatirlatma-epostalari">
          {ogeler.map((o) => (
            <li key={o.id} className="flex flex-wrap items-center justify-between gap-2 py-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
              <span style={{ color: "var(--yz-text)" }}>{o.ad ?? YOK}</span>
              <span style={{ color: "var(--yz-text-2)" }}>{tarihSaatBicimi(o.gonderim_zamani)}</span>
              <span className="flex flex-col items-end gap-0.5">
                <Rozet>{t(EPOSTA_DURUM_METNI[o.durum] ?? EPOSTA_DURUM_YEDEK)}</Rozet>
                {/* (P251 §10) Ulasmadiysa ne yapilacagi — ham hata yok. */}
                {teslimAciklamasi(o.durum) ? (
                  <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                    {t(teslimAciklamasi(o.durum)!)}
                  </span>
                ) : null}
              </span>
            </li>
          ))}
        </ul>
      )}
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
      <SayfaBasligi
        baslik={t("finansOtomasyon")}
        aciklama={t("otoSayfaAlt")}
      />
      {/* (P250 §9) Her kural duz cumle + ac/kapat + son calisma; yeni
          kural sihirbazla. Eski plan/gider TABLOLARI bunun yerine gecti. */}
      <KurallarKarti />
      <HatirlatmaKarti />
      <HatirlatmaGecmisiKarti />
      <HatirlatmaEpostalariKarti />
      <GunlukKarti />
    </div>
  );
}
