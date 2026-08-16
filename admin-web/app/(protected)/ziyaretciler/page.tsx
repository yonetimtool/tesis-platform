"use client";

// (P126.4) ZİYARETÇİLER — güvenliğin kapı ekranı.
//
// KAYIT YALNIZ GÜVENLİK: sunucu `_REGISTRAR = require_role("security")` ile
// zorlar; yönetici/admin geçmişi okur ama kayıt açmaz (kapı operasyonu).
// Bu sayfa `app.*` tesis yüzeyindedir ve rol kapısı girişte uygulanır.
import { useState } from "react";
import useSWR from "swr";

import {
  Modal,
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

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("ziyaretciBaslik")}
      </h1>
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
      </div>

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
          <BosDurum baslik={t("ziyaretciYok")} />
        ) : null}
        {kayitlar.map((z) => (
          <Kart key={z.id} className="space-y-1">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{z.ziyaretci_ad}</h3>
              <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{z.unit_no ?? "—"}</span>
            </div>
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {tarihSaatUzun(z.giris_zamani)}
              {z.cikis_zamani ? ` → ${tarihSaatUzun(z.cikis_zamani)}` : ""}
            </p>
            {z.notlar ? <p className="text-sm">{z.notlar}</p> : null}
            <div className="flex flex-wrap gap-2">
              {/* DUZENLEME CIKISTAN BAGIMSIZ: kapida yanlis yazilan bir ad
                  ya da daire, ziyaretci ciktiktan SONRA da duzeltilebilmeli
                  — kayit aksi halde kalici olarak yanlis kalir. Sunucu
                  kapisi (`_REGISTRAR`) ikisinde de ayni. */}
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
              {/* CIKIS DUGMESI yalnizca ICERIDEKI ziyaretcide: cikmis
                  birine tekrar cikis yaptirmak, kaydi ikinci kez
                  damgalamak olurdu. */}
              {!z.cikis_zamani ? (
                <Dugme boy="kucuk" onClick={() => void cikisYap(z.id)}>
                  {t("ziyaretciCikis")}
                </Dugme>
              ) : null}
            </div>
          </Kart>
        ))}
      </section>
    </div>
  );
}
