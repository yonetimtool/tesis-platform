"use client";

// (P126.4) OLAYLAR — güvenliğin ihlal/olay bildirimi.
//
// KAYNAK `manuel` SABİTLENİR: bu ekrandan açılan her kayıt elle
// bildirilmiştir. `kamera` ANPR/görüntü işlemeden, `devriye` tur akışından
// gelir; kullanıcıya kaynak seçtirmek, otomatik üretilmiş bir kaydı elle
// taklit etmesine izin vermek olurdu — olay kaydının kanıt değeri buradan
// gelir.
import { useState } from "react";
import useSWR from "swr";

import {
  Modal,
  CokSatir,
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihSaatUzun } from "@/lib/tarih";

type Olay = {
  id: string;
  baslik: string;
  aciklama: string | null;
  kaynak: string;
  konum: string | null;
  durum: string;
  created_at: string;
};

// METIN DEGIL KIMLIK (modul duzeyi).
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  yeni: "olayYeni",
  inceleniyor: "olayInceleniyor",
  kapatildi: "olayKapatildi",
};
const KAYNAK_ANAHTARI: Record<string, SozlukAnahtari> = {
  kamera: "olayKaynakKamera",
  manuel: "olayKaynakManuel",
  devriye: "olayKaynakDevriye",
};

function durumAnahtari(durum: string): SozlukAnahtari {
  const a = DURUM_ANAHTARI[durum];
  if (a) return a;
  return "olayDurumBilinmiyor";
}

function kaynakAnahtari(kaynak: string): SozlukAnahtari {
  const a = KAYNAK_ANAHTARI[kaynak];
  if (a) return a;
  return "olayDurumBilinmiyor";
}

export default function OlaylarPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Olay[] }>(
    "/api/violations?limit=50&offset=0",
    jsonFetcher,
  );

  const [baslik, setBaslik] = useState("");
  const [aciklama, setAciklama] = useState("");
  const [konum, setKonum] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);

  const kayitlar = data?.items ?? [];

  async function bildir() {
    if (!baslik.trim()) {
      setHata(t("olayBaslikZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      await apiSend("/api/violations", "POST", {
        baslik: baslik.trim(),
        aciklama: aciklama.trim() || null,
        // Bkz. dosya basligi: kaynak SABIT.
        kaynak: "manuel",
        konum: konum.trim() || null,
      });
      setBaslik("");
      setAciklama("");
      setKonum("");
      toast.success(t("olayBildirildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("olayBaslik")}
      </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={() => {
          // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden acildiginda
          // onceki denemenin mesaji ekranda duruyordu ve kullanici hic
          // denemeden hata gormus oluyordu.
          setHata(null);
          setModalAcik(true);
        }}>
          {t("olayYeniBildir")}
        </Dugme>
      </div>

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("olayYeniBildir")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
            tur="birincil"
            disabled={gonderiyor}
            onClick={() => void bildir()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : t("olayBildir")}
          </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4">
          <AlanSarmal etiket={t("olayKonu")}>
  {(b) => (
    <Alan {...b} value={baslik}
              onChange={(e) => setBaslik(e.target.value)}
              maxLength={200} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("olayKonum")}>
  {(b) => (
    <Alan {...b} value={konum}
              onChange={(e) => setKonum(e.target.value)}
              maxLength={200} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("olayAciklama")}>
            {(b) => (
              <CokSatir {...b} rows={4} value={aciklama}
              onChange={(e) => setAciklama(e.target.value)}
              maxLength={5000} />
            )}
          </AlanSarmal>
        </div>
        <HataDurumu mesaj={hata} />
        </div>
      </Modal>

      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("olayListe")}</h2>
        {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <IskeletMetin satir={3} />
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <BosDurum baslik={t("olayYok")} />
        ) : null}
        {kayitlar.map((o) => (
          <Kart key={o.id} className="space-y-1">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{o.baslik}</h3>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs">
                {t(durumAnahtari(o.durum))}
              </span>
            </div>
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {tarihSaatUzun(o.created_at)} · {t(kaynakAnahtari(o.kaynak))}
              {o.konum ? ` · ${o.konum}` : ""}
            </p>
            {o.aciklama ? <p className="text-sm">{o.aciklama}</p> : null}
          </Kart>
        ))}
      </section>
    </div>
  );
}
