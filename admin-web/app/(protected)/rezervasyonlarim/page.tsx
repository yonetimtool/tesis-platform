"use client";

// (P126.3) REZERVASYONLARIM — sakinin kendi rezervasyonları + yeni talep.
//
// ZAMANLAMA KURALLARI (24 sa önceden / günde bir / 10 dk asgari) SUNUCUDA
// ölçülür ve hata metni isteğin dilinde döner. İstemciye kopyalanmadı: iki
// kopya zamanla ayrışır ve kullanıcı "ekran izin verdi, sunucu reddetti"
// çelişkisini yaşar.
//
// LİSTE SUNUCUDA KENDİ-KAPSAMLIDIR — istemci süzgeci yok (`taleplerim` ile
// aynı gerekçe: istemci süzgeci bir gün unutulur, sunucu kuralı unutulmaz).
//
// ===========================================================================
// (P244 §8a) KART YIGINI -> TABLO
// ===========================================================================
// Her rezervasyon bir kartti. Rezervasyon kaydi TEKRARLI ve DAR bir
// kayittir (alan, tarih, saat araligi, kisi, durum); kullanicinin
// sordugu soru "hangi gun neredeyim" — yani sutun sutun taranacak bir
// soru. Kart dili burada ekrana uc kayit sigdiriyordu.
//
// TARIH KOLONU SIRALANABILIR: rezervasyon listesinin dogal sirasi
// tarihtir ve sutun basligina basmak bunu geri verir.
import { useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  SayfaBasligi,
  Secim,
  Sekmeler,
  Rozet,
  VeriTablosu,
} from "@/components/ui";
import type { Kolon } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihBicimi } from "@/lib/tarih";

type Alan = { id: string; ad: string; aktif: boolean; slot_dakika?: number };
type Rezervasyon = {
  id: string;
  alan_ad: string | null;
  tarih: string;
  baslangic: string;
  bitis: string;
  kisi_sayisi: number;
  durum: string;
  /** (P165) Bitis saati gecti mi — SUNUCU hesaplar (tesis saat dilimi). */
  gecmis: boolean;
};

// METIN DEGIL KIMLIK (modul duzeyi — tur 18 dersi).
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  onaylandi: "rezervasyonOnayli",
  iptal: "rezervasyonIptal",
};

function durumAnahtari(durum: string): SozlukAnahtari {
  const a = DURUM_ANAHTARI[durum];
  if (a) return a;
  // `??` ile tek satirda yazmak sabit-metin taramasini tetikliyor (uclu
  // icindeki dizge gorunen metinle ayni sozdiziminde durur).
  return "rezervasyonDurumBilinmiyor";
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SEKME_AKTIF = "aktif" as const;
const SEKME_GECMIS = "gecmis" as const;
const DURUM_IPTAL = "iptal" as const;
const YOK = "—";

export default function RezervasyonlarimPage() {
  const t = useT();
  const toast = useToast();
  // (P165 §3) AKTIF / GECMIS AYRIMI — SUNUCU KARAR VERIR.
  //
  // Olculen kusur: saati gecmis rezervasyonlar aktif listede duruyor ve
  // altlarinda "Iptal et" yaziyordu. Gecmis bir rezervasyon iptal
  // EDILEMEZ; dugme yanilticiydi.
  //
  // AYRIM ISTEMCIDE YAPILMAZ: cihaz saati yanlis kurulu olabilir ve
  // `tarih + bitis` ancak TESISIN saat diliminde bir ANA donusur. Sunucu
  // `?gecmis=` suzgeciyle cevap veriyor, istemci yalnizca soruyor.
  const [sekme, setSekme] = useState<string>(SEKME_AKTIF);
  const gecmisMi = sekme === SEKME_GECMIS;
  const { data, error, isLoading, mutate } = useSWR<{ items: Rezervasyon[] }>(
    `/api/reservations?limit=50&offset=0&gecmis=${gecmisMi}`,
    jsonFetcher,
  );
  const { data: alanVeri } = useSWR<{ items: Alan[] }>(
    "/api/common-areas",
    jsonFetcher,
  );

  const [alanId, setAlanId] = useState("");
  const [tarih, setTarih] = useState("");
  const [baslangic, setBaslangic] = useState("");
  const [bitis, setBitis] = useState("");
  const [kisi, setKisi] = useState("2");
  const [formHata, setFormHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);

  const kayitlar = data?.items ?? [];
  const alanlar = (alanVeri?.items ?? []).filter((a) => a.aktif);
  // (E2E 2026-09 / TESIS-12) Sunucu slot izgarasina hizali saat istiyor;
  // saat secicinin adimi secili alanin slotu olsun (kural sunucuda, bu
  // yalniz yazimi kolaylastirir — hizasiz deger sunucu metniyle reddedilir).
  const slotSaniye = (alanlar.find((a) => a.id === alanId)?.slot_dakika ?? 60) * 60;

  async function gonder() {
    if (!alanId || !tarih || !baslangic || !bitis) {
      setFormHata(t("rezervasyonAlanZorunlu"));
      return;
    }
    setFormHata(null);
    setGonderiyor(true);
    try {
      await apiSend("/api/reservations", "POST", {
        alan_id: alanId,
        tarih,
        baslangic,
        bitis,
        kisi_sayisi: Number(kisi) || 1,
      });
      toast.success(t("rezervasyonOlusturuldu"));
      setTarih("");
      setBaslangic("");
      setBitis("");
      void mutate();
    } catch (e) {
      // SUNUCU metni aynen gosterilir — zamanlama kurallarinin gerekcesini
      // en dogru anlatan cumle onunkidir.
      setFormHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  async function iptalEt(id: string) {
    try {
      await apiSend(`/api/reservations/${id}/cancel`, "POST");
      toast.success(t("rezervasyonIptalEdildi"));
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const kolonlar: Kolon<Rezervasyon>[] = [
    {
      id: "alan",
      baslik: t("rezervasyonAlan"),
      hucre: (r) => <span className="font-medium">{r.alan_ad ?? YOK}</span>,
      deger: (r) => r.alan_ad ?? "",
      kartRolu: "baslik",
    },
    {
      id: "tarih",
      baslik: t("rezervasyonTarih"),
      hucre: (r) => tarihBicimi(r.tarih),
      deger: (r) => r.tarih,
      kartRolu: "ozet",
    },
    {
      id: "saat",
      baslik: t("rezervasyonKolonSaat"),
      hucre: (r) => (
        <span className="tabular-nums">
          {r.baslangic}–{r.bitis}
        </span>
      ),
      deger: (r) => r.baslangic,
      kartRolu: "ozet",
    },
    {
      id: "kisi",
      baslik: t("rezervasyonKisi"),
      hucre: (r) => t("rezervasyonKisiSayisi", { n: r.kisi_sayisi }),
      deger: (r) => r.kisi_sayisi,
      sayisal: true,
      darEkrandaGizle: true,
    },
    {
      id: "durum",
      baslik: t("rezervasyonKolonDurum"),
      hucre: (r) => (
        <Rozet durum={r.durum === DURUM_IPTAL ? "notr" : "olumlu"}>
          {t(durumAnahtari(r.durum))}
        </Rozet>
      ),
      kartRolu: "rozet",
    },
    {
      id: "eylem",
      baslik: t("listeIslemler"),
      // (P165 §3) GECMISTE "IPTAL ET" YOK.
      // Kosul `r.gecmis` — SUNUCUNUN hesapladigi bayrak. Sekmeye bakmak
      // yetmezdi: aktif sekmede duran bir rezervasyonun bitis saati,
      // sayfa acikken de gecebilir.
      hucre: (r) =>
        !r.gecmis && r.durum !== DURUM_IPTAL ? (
          <Dugme boy="kucuk" onClick={() => void iptalEt(r.id)}>
            {t("rezervasyonIptalEt")}
          </Dugme>
        ) : r.gecmis ? (
          // SALT-OKUNUR DURUM: iptal edilmisse "iptal edildi",
          // edilmemisse "tamamlandi". Ucuncu bir durum (katilim yok)
          // veride YOK — uydurulmadi.
          <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {r.durum === DURUM_IPTAL
              ? t("rezervasyonGecmisIptal")
              : t("rezervasyonGecmisTamam")}
          </span>
        ) : null,
      gizlenebilir: false,
      kartRolu: "eylem",
    },
  ];

  const liste = (
    <VeriTablosu
      kolonlar={kolonlar}
      satirlar={kayitlar}
      satirId={(r) => r.id}
      yukleniyor={isLoading}
      // (P61) HATA TABLOYA VERILIR: istek dustugunde "rezervasyon yok"
      // yazmak, rezervasyonun OLMADIGINI soylemek olurdu.
      hata={error ? t("ortakHataOlustu") : null}
      onTekrar={() => void mutate()}
      bosBaslik={gecmisMi ? t("rezervasyonGecmisYok") : t("rezervasyonYok")}
      bosAciklama={gecmisMi ? t("rezervasyonGecmisYokAlt") : t("rezervasyonYokAlt")}
    />
  );

  return (
    <div>
      <SayfaBasligi
        baslik={t("rezervasyonBaslik")}
        aciklama={t("rezervasyonSayfaAlt")}
        eylem={
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden
              // acildiginda onceki denemenin mesaji ekranda duruyordu ve
              // kullanici hic denemeden hata gormus oluyordu.
              setFormHata(null);
              setModalAcik(true);
            }}
          >
            {t("rezervasyonYeni")}
          </Dugme>
        }
      />

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("rezervasyonYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
            tur="birincil"
            disabled={gonderiyor}
            onClick={() => void gonder()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : t("rezervasyonTalepEt")}
          </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
          <AlanSarmal etiket={t("rezervasyonAlan")}>
  {(b) => (
    <Secim {...b} value={alanId}
              onChange={(e) => setAlanId(e.target.value)}
            >
              <option value="">{t("ortakSeciniz")}</option>
              {alanlar.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.ad}
                </option>
              ))}</Secim>
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("rezervasyonTarih")}>
  {(b) => (
    <Alan {...b} type="date"
              value={tarih}
              onChange={(e) => setTarih(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("rezervasyonBaslangic")}>
  {(b) => (
    <Alan {...b} type="time"
              step={slotSaniye}
              value={baslangic}
              onChange={(e) => setBaslangic(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("rezervasyonBitis")}>
  {(b) => (
    <Alan {...b} type="time"
              step={slotSaniye}
              value={bitis}
              onChange={(e) => setBitis(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("rezervasyonKisi")}>
  {(b) => (
    <Alan {...b} type="number"
              min={1}
              value={kisi}
              onChange={(e) => setKisi(e.target.value)} />
  )}
</AlanSarmal>
        </div>
        <HataDurumu mesaj={formHata} />
        </div>
      </Modal>

      {/* IKI SEKME, TEK LISTE GOVDESI: veri anahtari `gecmisMi`ye
          bagli, yani sekme degisince SUNUCUYA yeniden soruluyor.
          Govdeyi iki kez yazmak, iki ayri bakim noktasi demekti. */}
      <Sekmeler
        aktifId={sekme}
        onDegis={setSekme}
        sekmeler={[
          { id: SEKME_AKTIF, baslik: t("rezervasyonSekmeAktif"), icerik: liste },
          { id: SEKME_GECMIS, baslik: t("rezervasyonSekmeGecmis"), icerik: liste },
        ]}
      />
    </div>
  );
}
