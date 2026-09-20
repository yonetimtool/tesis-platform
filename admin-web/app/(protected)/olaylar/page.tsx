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
  Alan,
  AlanSarmal,
  BosDurum,
  CokSatir,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Modal,
  OzetKarti,
  OzetSeridi,
  Rozet,
  SayfaBasligi,
  VeriTablosu,
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
// (P244 §6c) UCLUDE DIZE YAZILMAZ (`sabit-metin`) — durum kimligi de dize.
const DURUM_KAPALI = "kapatildi" as const;
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

  // (P244 §6c) ACIK OLAY = kapatilmamis olan. Durum kimlikleri
  // `DURUM_ANAHTARI`de; "kapatildi" disindaki her sey acik sayilir ki
  // yeni bir durum eklendiginde sessizce "kapali" tarafina dusmesin.
  const acikSayisi = kayitlar.filter((o) => o.durum !== DURUM_KAPALI).length;

  const kolonlar = [
    {
      id: "tarih",
      baslik: t("ortakTarih"),
      hucre: (o: Olay) => tarihSaatUzun(o.created_at),
      deger: (o: Olay) => o.created_at,
    },
    {
      id: "baslik",
      baslik: t("olayKolonBaslik"),
      hucre: (o: Olay) => (
        <span>
          <span className="block" style={{ color: "var(--yz-text)" }}>
            {o.baslik}
          </span>
          {o.aciklama ? (
            // ACIKLAMA IKINCI SATIRDA ve KIRPILIR: uzun bir metin satir
            // yuksekligini bozup tablonun ritmini kirardi.
            <span
              className="block truncate"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {o.aciklama}
            </span>
          ) : null}
        </span>
      ),
      deger: (o: Olay) => o.baslik,
    },
    {
      id: "kaynak",
      baslik: t("olayKolonKaynak"),
      hucre: (o: Olay) => t(kaynakAnahtari(o.kaynak)),
      darEkrandaGizle: true,
    },
    {
      id: "konum",
      baslik: t("olayKolonKonum"),
      hucre: (o: Olay) => o.konum ?? "—",
      darEkrandaGizle: true,
    },
    {
      id: "durum",
      baslik: t("ortakDurum"),
      // ROZET METIN TASIR: renk tek tasiyici degil.
      hucre: (o: Olay) => (
        <Rozet durum={o.durum === DURUM_KAPALI ? "olumlu" : "uyari"}>
          {t(durumAnahtari(o.durum))}
        </Rozet>
      ),
      deger: (o: Olay) => o.durum,
    },
  ];

  return (
    <div className="space-y-6">
      <SayfaBasligi
        baslik={t("olayBaslik")}
        eylem={
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden
              // acildiginda onceki denemenin mesaji ekranda duruyordu ve
              // kullanici hic denemeden hata gormus oluyordu.
              setHata(null);
              setModalAcik(true);
            }}
          >
            {t("olayYeniBildir")}
          </Dugme>
        }
      />

      {/* (P244 §6c) OZET SERIDI — sayilar GORUNEN listeden.
          Liste sayfalanmiyor (sunucu tum olaylari donduruyor), yani
          gorunen kume = tum kume. Sayfalansaydi `meta.total` gerekirdi
          (arac gecislerinde oyle yapildi). */}
      {!isLoading && !error && kayitlar.length > 0 && (
        <OzetSeridi>
          <OzetKarti
            etiket={t("olayOzetToplam")}
            deger={String(kayitlar.length)}
            durum="notr"
          />
          <OzetKarti
            etiket={t("olayOzetAcik")}
            deger={String(acikSayisi)}
            durum={acikSayisi > 0 ? "uyari" : "olumlu"}
            altBilgi={acikSayisi > 0 ? t("olayOzetAcikAlt") : undefined}
          />
          <OzetKarti
            etiket={t("olayOzetKapali")}
            deger={String(kayitlar.length - acikSayisi)}
            durum="olumlu"
          />
        </OzetSeridi>
      )}

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
        {/* (P244 §6c) KART YIGINI -> TABLO.
            Her olay AYRI BIR KARTTI ve ekrana dort kayit siginiyordu.
            Olay kaydi tekrarli ve kisa alanli (tarih, baslik, kaynak,
            konum, durum); tablo ayni alanda yirmi kayit gosterir ve goz
            sutunlari takip eder.
            HATA TABLOYA VERILIR: istek dustugunde "kayit yok" yazmak,
            kayit OLMADIGINI soylemek olurdu (P61). */}
        <VeriTablosu
          kolonlar={kolonlar}
          satirlar={kayitlar}
          satirId={(o) => o.id}
          yukleniyor={isLoading}
          hata={error ? t("ortakHataOlustu") : null}
          yogunluk="sik"
          bosBaslik={t("olayYok")}
          bosAciklama={t("olayYokAlt")}
        />
      </section>
    </div>
  );
}
