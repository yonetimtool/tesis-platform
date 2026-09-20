"use client";

// (P126.4) ZİYARETÇİLER — güvenliğin kapı ekranı.
//
// KAYIT YALNIZ GÜVENLİK: sunucu `_REGISTRAR = require_role("security")` ile
// zorlar; yönetici/admin geçmişi okur ama kayıt açmaz (kapı operasyonu).
// Bu sayfa `app.*` tesis yüzeyindedir ve rol kapısı girişte uygulanır.
import { useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  BosDurum,
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
import { tarihSaatUzun } from "@/lib/tarih";

type Ziyaretci = {
  id: string;
  unit_no: string | null;
  ziyaretci_ad: string;
  notlar: string | null;
  giris_zamani: string;
  cikis_zamani: string | null;
};

export default function ZiyaretcilerPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Ziyaretci[] }>(
    "/api/visitors?limit=50&offset=0",
    jsonFetcher,
  );

  const [ad, setAd] = useState("");
  const [daireNo, setDaireNo] = useState("");
  const [notlar, setNotlar] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  // (P162 §5) ZIYARETCI KAYDINI DUZENLEME — webde YOKTU.
  //
  // Uc (`PATCH /visitors/{id}`) ve rol kapisi (`_REGISTRAR` = guvenlik)
  // zaten vardi; mobilde kullaniliyordu, webde vekil ve dugme eksikti.
  // Kapida yanlis yazilan bir ad ya da daire, vardiya devrinde
  // duzeltilebilmeli — aksi halde kayit kalici olarak yanlis kalir.
  //
  // AYNI MODAL: yeni kayit ile duzenleme tek formu paylasir. Iki ayri
  // form, iki ayri dogrulama demekti ve biri gerilerdi.
  const [duzenlenen, setDuzenlenen] = useState<{ id: string } | null>(null);

  const kayitlar = data?.items ?? [];

  async function kaydet() {
    if (!ad.trim() || !daireNo.trim()) {
      setHata(t("ziyaretciAlanZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      // DAIRE NO ile gonderilir: kapida görevli daire NUMARASINI bilir,
      // kaydın kimliğini değil. Sunucu numarayı çözer.
      const govde = {
        unit_no: daireNo.trim(),
        ziyaretci_ad: ad.trim(),
        // `null` ACIKCA gonderilir: notu TEMIZLEMEK icin tek yol bu.
        // Alani hic gondermemek "degistirme" demek olurdu.
        notlar: notlar.trim() || null,
      };
      if (duzenlenen) await apiSend(`/api/visitors/${duzenlenen.id}`, "PATCH", govde);
      else await apiSend("/api/visitors", "POST", govde);
      setAd("");
      setDaireNo("");
      setNotlar("");
      setDuzenlenen(null);
      setModalAcik(false);
      toast.success(t("ziyaretciKaydedildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  async function cikisYap(id: string) {
    try {
      await apiSend(`/api/visitors/${id}/checkout`, "POST");
      toast.success(t("ziyaretciCikisYapildi"));
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  // (P244 §6c) ICERIDEKI = cikis damgasi olmayan kayit.
  const iceridekiler = kayitlar.filter((z) => !z.cikis_zamani).length;

  const kolonlar = [
    {
      id: "ad",
      baslik: t("ziyaretciKolonAd"),
      hucre: (z: Ziyaretci) => (
        <span>
          <span className="block" style={{ color: "var(--yz-text)" }}>
            {z.ziyaretci_ad}
          </span>
          {z.notlar ? (
            <span
              className="block truncate"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {z.notlar}
            </span>
          ) : null}
        </span>
      ),
      deger: (z: Ziyaretci) => z.ziyaretci_ad,
    },
    {
      id: "daire",
      baslik: t("aracKolonDaire"),
      hucre: (z: Ziyaretci) => z.unit_no ?? "—",
      deger: (z: Ziyaretci) => z.unit_no ?? "",
    },
    {
      id: "giris",
      baslik: t("ziyaretciKolonGiris"),
      hucre: (z: Ziyaretci) => tarihSaatUzun(z.giris_zamani),
      deger: (z: Ziyaretci) => z.giris_zamani,
    },
    {
      id: "durum",
      baslik: t("ortakDurum"),
      // ROZET METIN TASIR: renk tek tasiyici degil.
      hucre: (z: Ziyaretci) =>
        z.cikis_zamani ? (
          <span style={{ color: "var(--yz-text-2)" }}>
            {t("aracCikti", { saat: tarihSaatUzun(z.cikis_zamani) })}
          </span>
        ) : (
          <Rozet durum="bilgi" nokta>
            {t("aracIceride")}
          </Rozet>
        ),
      deger: (z: Ziyaretci) => (z.cikis_zamani ? "1" : "0"),
    },
    {
      id: "eylem",
      kartRolu: "eylem" as const,
      baslik: "",
      gizlenebilir: false,
      hucre: (z: Ziyaretci) => (
        <div className="flex justify-end gap-2">
          {/* DUZENLEME CIKISTAN BAGIMSIZ: kapida yanlis yazilan bir ad ya
              da daire, ziyaretci ciktiktan SONRA da duzeltilebilmeli —
              kayit aksi halde kalici olarak yanlis kalir. Sunucu kapisi
              (`_REGISTRAR`) ikisinde de ayni. */}
          <Dugme
            boy="kucuk"
            onClick={() => {
              setDuzenlenen({ id: z.id });
              setAd(z.ziyaretci_ad);
              setDaireNo(z.unit_no ?? "");
              setNotlar(z.notlar ?? "");
              setHata(null);
              setModalAcik(true);
            }}
          >
            {t("ortakDuzenle")}
          </Dugme>
          {/* CIKIS DUGMESI yalnizca ICERIDEKI ziyaretcide: cikmis birine
              tekrar cikis yaptirmak, kaydi ikinci kez damgalamak
              olurdu. */}
          {!z.cikis_zamani ? (
            <Dugme boy="kucuk" onClick={() => void cikisYap(z.id)}>
              {t("ziyaretciCikis")}
            </Dugme>
          ) : null}
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <SayfaBasligi
        baslik={t("ziyaretciBaslik")}
        eylem={
          <Dugme
          tur="birincil"
          boy="kucuk"
          onClick={() => {
            // YENI KAYIT: duzenleme durumu ve alanlar TEMIZLENIR.
            // Temizlemeseydik "yeni" dugmesi son duzenlenen kaydin
            // uzerine yazardi.
            setDuzenlenen(null);
            setAd("");
            setDaireNo("");
            setNotlar("");
            setHata(null);
            setModalAcik(true);
          }}
        >
            {t("ziyaretciYeni")}
          </Dugme>
        }
      />

      {/* (P244 §6c) OZET SERIDI — sayilar GORUNEN listeden (liste
          sayfalanmiyor). "Icerideki" sayisi operasyonun en sik sordugu
          soru: kapida kac kisi var. */}
      {!isLoading && !error && kayitlar.length > 0 && (
        <OzetSeridi>
          <OzetKarti
            etiket={t("ziyaretciOzetToplam")}
            deger={String(kayitlar.length)}
            durum="notr"
          />
          <OzetKarti
            etiket={t("ziyaretciOzetIceride")}
            deger={String(iceridekiler)}
            durum={iceridekiler > 0 ? "bilgi" : "olumlu"}
            altBilgi={t("ziyaretciOzetIcerideAlt")}
          />
          <OzetKarti
            etiket={t("ziyaretciOzetCikmis")}
            deger={String(kayitlar.length - iceridekiler)}
            durum="olumlu"
          />
        </OzetSeridi>
      )}

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={duzenlenen ? t("ziyaretciDuzenle") : t("ziyaretciYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
            tur="birincil"
            disabled={gonderiyor}
            onClick={() => void kaydet()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : duzenlenen ? t("ortakKaydet") : t("ziyaretciGirisKaydet")}
          </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
          <AlanSarmal etiket={t("ziyaretciAd")}>
  {(b) => (
    <Alan {...b} value={ad}
              onChange={(e) => setAd(e.target.value)}
              maxLength={120} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("ziyaretciDaire")}>
  {(b) => (
    <Alan {...b} value={daireNo}
              onChange={(e) => setDaireNo(e.target.value)}
              maxLength={30} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("ziyaretciNot")}>
  {(b) => (
    <Alan {...b} value={notlar}
              onChange={(e) => setNotlar(e.target.value)}
              maxLength={500} />
  )}
</AlanSarmal>
        </div>
        <HataDurumu mesaj={hata} />
        </div>
      </Modal>

      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("ziyaretciListe")}</h2>
        {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <IskeletMetin satir={3} />
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <BosDurum baslik={t("ziyaretciYok")} aciklama={t("ziyaretciYokAlt")} />
        ) : null}
        {/* (P244 §6c) KART YIGINI -> TABLO.
            Her ziyaretci AYRI BIR KARTTI; kayit tekrarli ve kisa alanli
            (ad, daire, giris, cikis). Tablo ayni alanda cok daha fazla
            kayit gosterir ve "kim iceride" sorusu tek sutundan okunur.
            HATA TABLOYA VERILIR (P61): istek dustugunde "kayit yok"
            yazmak, kayit OLMADIGINI soylemek olurdu. */}
        <VeriTablosu
          kolonlar={kolonlar}
          satirlar={kayitlar}
          satirId={(z) => z.id}
          yukleniyor={isLoading}
          hata={error ? t("ortakHataOlustu") : null}
          yogunluk="sik"
          bosBaslik={t("ziyaretciYok")}
          bosAciklama={t("ziyaretciYokAlt")}
        />
      </section>
    </div>
  );
}
