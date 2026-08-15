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
  Secim,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihBicimi } from "@/lib/tarih";

type Alan = { id: string; ad: string; aktif: boolean };
type Rezervasyon = {
  id: string;
  alan_ad: string | null;
  tarih: string;
  baslangic: string;
  bitis: string;
  kisi_sayisi: number;
  durum: string;
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

export default function RezervasyonlarimPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Rezervasyon[] }>(
    "/api/reservations?limit=50&offset=0",
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

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("rezervasyonBaslik")}
      </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={() => setModalAcik(true)}>
          {t("rezervasyonYeni")}
        </Dugme>
      </div>

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
              value={baslangic}
              onChange={(e) => setBaslangic(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("rezervasyonBitis")}>
  {(b) => (
    <Alan {...b} type="time"
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

      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("rezervasyonListe")}</h2>
        {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <IskeletMetin satir={3} />
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <BosDurum baslik={t("rezervasyonYok")} />
        ) : null}
        {kayitlar.map((r) => (
          <Kart key={r.id} className="space-y-1">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{r.alan_ad ?? "—"}</h3>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs">
                {t(durumAnahtari(r.durum))}
              </span>
            </div>
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
              {tarihBicimi(r.tarih)} · {r.baslangic}–{r.bitis} ·{" "}
              {t("rezervasyonKisiSayisi", { n: r.kisi_sayisi })}
            </p>
            {r.durum !== "iptal" ? (
              <Dugme
                boy="kucuk"
                onClick={() => void iptalEt(r.id)}
              >
                {t("rezervasyonIptalEt")}
              </Dugme>
            ) : null}
          </Kart>
        ))}
      </section>
    </div>
  );
}
