"use client";

// (P167 §4.3/§4.4) GIDER ve GELIR — satir tabanli giris modali.
//
// IKI SAYFA TEK BILESEN: brief'in "Yeni Gider Hareketi" ve "Yeni Gelir
// Hareketi" modallari ayni kolonlari istiyor (Hareket Tipi | Belge No |
// Tarih | Firma | Tur | Durumu | Kasa | Tutar | Aciklama | Sil).
// Degisen tek sey satirin `tip`i ve basligi.
//
// Ikisini ayri yazmak, ayni on iki alani iki kez dogrulamak ve birinde
// bir kurali unutmak olurdu.

import { useState } from "react";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Modal,
  Secim,
} from "@/components/ui";
import { apiSend, genIdempotencyKey } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tlToKurus } from "@/lib/money";

import {
  bugun,
  useFirmalar,
  useGelirGiderTanimlari,
  useKasalar,
} from "./ortak";
import {
  SatirTablosu,
  yeniSatirAnahtari,
  type SatirTabani,
} from "./satir-tablosu";

interface Satir extends SatirTabani {
  belgeNo: string;
  tarih: string;
  firmaId: string;
  tanimId: string;
  durum: string;
  kasaId: string;
  aciklama: string;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_ODENDI = "odendi";
const DURUMLAR: { id: string; anahtar: SozlukAnahtari }[] = [
  { id: "odendi", anahtar: "finansDurumOdendi" },
  { id: "bekliyor", anahtar: "finansDurumBekliyor" },
  { id: "onay_bekliyor", anahtar: "finansDurumOnayBekliyor" },
];

function hucreGirdi(
  deger: string,
  onDegisti: (v: string) => void,
  etiket: string,
  tip?: string,
) {
  return (
    <Alan
      value={deger}
      type={tip}
      aria-label={etiket}
      onChange={(e) => onDegisti(e.target.value)}
      className="!h-10 min-w-28"
    />
  );
}

function hucreSecim(
  deger: string,
  onDegisti: (v: string) => void,
  etiket: string,
  secenekler: { id: string; ad: string }[],
  bosMetin: string,
) {
  return (
    <Secim
      value={deger}
      aria-label={etiket}
      onChange={(e) => onDegisti(e.target.value)}
      className="!h-10 min-w-32"
    >
      <option value="">{bosMetin}</option>
      {secenekler.map((s) => (
        <option key={s.id} value={s.id}>{s.ad}</option>
      ))}
    </Secim>
  );
}

export function HareketModali({
  acik,
  tip,
  baslikAnahtari,
  onKapat,
  onKaydedildi,
}: {
  acik: boolean;
  /** `gider` ya da `gelir` — satirin tipi. */
  tip: string;
  baslikAnahtari: SozlukAnahtari;
  onKapat: () => void;
  onKaydedildi: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const kasalar = useKasalar();
  const firmalar = useFirmalar();
  const tanimlar = useGelirGiderTanimlari();

  const bosSatir = (): Satir => ({
    _k: yeniSatirAnahtari(),
    belgeNo: "",
    tarih: bugun(),
    firmaId: "",
    tanimId: "",
    // BRIEF: "Durumu (varsayilan Odendi)".
    durum: DURUM_ODENDI,
    kasaId: kasalar[0]?.id ?? "",
    tutar: "",
    aciklama: "",
  });

  const [satirlar, setSatirlar] = useState<Satir[]>([bosSatir()]);
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);
  // (P192 §6.2) IDEMPOTENCY ANAHTARI — uc basligi ANLIYOR ama bu ekran
  // GONDERMIYORDU: zaman asimi sonrasi tekrar (kullanici "kaydedilmedi"
  // sanip yeniden basar) kasada IKI hareket olusturabilirdi. Anahtar
  // FORM ORNEGI BASINA uretilir; basarili kayittan sonra yenilenir.
  const [anahtar, setAnahtar] = useState(() => genIdempotencyKey());

  function sifirla() {
    setSatirlar([bosSatir()]);
    setHata(null);
  }

  async function kaydet() {
    // BOS SATIRLAR ELENIR, HATA DEGIL: kullanici "+ Yeni Satır"a fazladan
    // basmis olabilir ve bunu bir hata gibi sunmak, yaptigi isi
    // engellemek olurdu. Ama HICBIR dolu satir yoksa bu bir hatadir.
    const dolu = satirlar.filter((s) => (tlToKurus(s.tutar) ?? 0) > 0);
    if (dolu.length === 0) {
      setHata(t("finansSatirGerekli"));
      return;
    }
    if (dolu.some((s) => !s.kasaId)) {
      setHata(t("finansKasaGerekli"));
      return;
    }
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/panel/finans-hareketler", "POST", {
        satirlar: dolu.map((s) => ({
          tip,
          tutar_kurus: tlToKurus(s.tutar),
          kasa_id: s.kasaId,
          firma_id: s.firmaId || null,
          gelir_gider_tanim_id: s.tanimId || null,
          tarih: s.tarih || null,
          // BOS BELGE NO SUNUCUYA `null` GIDER: merkezi seri orada
          // devreye girer (`belge_no.py`). Bos dize gondermek,
          // "kullanici bir sey yazdi" gibi okunurdu.
          belge_no: s.belgeNo.trim() || null,
          aciklama: s.aciklama.trim() || null,
          durum: s.durum,
        })),
      }, { "Idempotency-Key": anahtar });
      toast.success(t("finansKaydedildi"));
      sifirla();
      setAnahtar(genIdempotencyKey());
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
      baslik={t(baslikAnahtari)}
      onKapat={onKapat}
      genislikSinifi="max-w-5xl"
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          <Dugme tur="birincil" disabled={kaydediyor} onClick={() => void kaydet()}>
            {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </span>
      }
    >
      <div className="space-y-3">
        <SatirTablosu<Satir>
          satirlar={satirlar}
          onDegisti={setSatirlar}
          bosSatir={bosSatir}
          basliklar={[
            t("finansSutunBelgeNo"),
            t("finansSutunTarih"),
            t("finansSutunFirma"),
            t("finansSutunTur"),
            t("finansSutunDurum"),
            t("finansSutunKasa"),
            t("finansSutunAciklama"),
          ]}
          hucreler={(s, guncelle) => [
            hucreGirdi(s.belgeNo, (v) => guncelle({ belgeNo: v }), t("finansSutunBelgeNo")),
            hucreGirdi(s.tarih, (v) => guncelle({ tarih: v }), t("finansSutunTarih"), "date"),
            hucreSecim(s.firmaId, (v) => guncelle({ firmaId: v }), t("finansSutunFirma"), firmalar, t("finansFirmaSec")),
            hucreSecim(s.tanimId, (v) => guncelle({ tanimId: v }), t("finansSutunTur"), tanimlar, t("finansTurSec")),
            hucreSecim(
              s.durum, (v) => guncelle({ durum: v }), t("finansSutunDurum"),
              DURUMLAR.map((d) => ({ id: d.id, ad: t(d.anahtar) })), "",
            ),
            hucreSecim(s.kasaId, (v) => guncelle({ kasaId: v }), t("finansSutunKasa"), kasalar, t("finansKasaSec")),
            hucreGirdi(s.aciklama, (v) => guncelle({ aciklama: v }), t("finansSutunAciklama")),
          ]}
        />
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
