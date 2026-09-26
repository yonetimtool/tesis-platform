"use client";

// (P181 Bölüm 9) REZERVASYON YÖNETİMİ — YÖNETİM yüzeyi (admin/yönetici).
//
// Mobilde vardı (rezervasyon ekranı "Alanlar" sekmesi + yönetim rezervasyon
// listesi), web'de YOKTU. Aynı VERİ MODELİ ve aynı UÇLAR (yeni tablo YOK):
//   - Alanlar:      GET/POST /common-areas, PATCH /common-areas/{id}
//   - Rezervasyonlar: GET /reservations (yönetim=tümü), POST .../cancel
//
// İŞ KURALLARI SUNUCUDA (mobil ile birebir): çakışma kontrolü + zamanlama
// (reservations_timing.py) + saklama süresi (göç 0054, tenant.rezervasyon_
// gecmis_ay). İstemci KOPYALAMAZ — iki kopya zamanla ayrışır. REZERVASYON
// OLUŞTURMA backend'de YALNIZ resident'tir (RBAC); yönetim burada rezervasyon
// ÜRETMEZ, sakin `/rezervasyonlarim`'dan oluşturur. "Düzenleme" = ALAN
// düzenleme (rezervasyonun kendisi düzenlenebilir değil — mobilde de öyle).

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
  Secim,
  Sekmeler,
  OzetKarti,
  OzetSeridi,
  SayfaBasligi,
  Rozet,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihBicimi } from "@/lib/tarih";
import { SINIR } from "@/lib/girdi-siniri";

type OrtakAlan = {
  id: string;
  ad: string;
  aciklama: string | null;
  aktif: boolean;
  acilis: string;
  kapanis: string;
  slot_dakika: number;
};
type Rezervasyon = {
  id: string;
  alan_ad: string | null;
  tarih: string;
  baslangic: string;
  bitis: string;
  kisi_sayisi: number;
  durum: string;
  gecmis: boolean;
};

// (P245) UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const GECMIS_HAYIR = "false" as const;
const DURUM_IPTAL = "iptal" as const;
const R_OLUMLU = "olumlu" as const;
const R_NOTR = "notr" as const;

const IKON_ALAN = "M3 21h18M5 21V7l7-4 7 4v14M10 21v-5h4v5";
const IKON_TAKVIM = "M7 3v4M17 3v4M3 9h18M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z";
const IKON_ONAY = "M20 6 9 17l-5-5";

function RezIkonu({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

/** Bugunun ISO gunu — sayac sorgusu icin. */
function bugunIso(): string {
  return new Date().toISOString().slice(0, 10);
}

const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  onaylandi: "rezervasyonOnayli",
  iptal: "rezervasyonIptal",
};
function durumAnahtari(durum: string): SozlukAnahtari {
  const a = DURUM_ANAHTARI[durum];
  if (a) return a;
  return "rezervasyonDurumBilinmiyor";
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SEKME_ALANLAR = "alanlar" as const;
const SEKME_REZ = "rezervasyonlar" as const;

type AlanTaslak = {
  id: string | null;
  ad: string;
  aciklama: string;
  acilis: string;
  kapanis: string;
  slot_dakika: string;
};
const BOS_TASLAK: AlanTaslak = {
  id: null, ad: "", aciklama: "", acilis: "09:00", kapanis: "22:00", slot_dakika: "60",
};

export default function RezervasyonYonetimiPage() {
  const t = useT();
  const [sekme, setSekme] = useState<string>(SEKME_ALANLAR);

  // (P245) SAYAÇLAR AYRI SORGULARDAN (`?...&limit=1` -> `meta.total`).
  //
  // Iki sekme de KENDI listesini cekiyor ve ikisi de SUZGECLI; serit
  // onlardan beslenseydi, sekme ya da tarih degisince sayilar da
  // degisirdi — yani "bugun 3 rezervasyon" yerine "secili suzgecte 3"
  // yazardi. (P244 §8c'de bakim ekraninda olculen ders.)
  const { data: alanSayisi } = useSWR<{ items: OrtakAlan[] }>(
    "/api/common-areas",
    jsonFetcher,
  );
  const { data: bugunSayisi } = useSWR<{ meta?: { total?: number } }>(
    `/api/reservations?limit=1&offset=0&tarih=${bugunIso()}`,
    jsonFetcher,
  );
  const { data: aktifSayisi } = useSWR<{ meta?: { total?: number } }>(
    `/api/reservations?limit=1&offset=0&gecmis=${GECMIS_HAYIR}`,
    jsonFetcher,
  );
  const aktifAlan = (alanSayisi?.items ?? []).filter((a) => a.aktif).length;

  return (
    <div>
      <SayfaBasligi baslik={t("rezYonBaslik")} aciklama={t("rezYonSayfaAlt")} />

      <OzetSeridi>
        <OzetKarti
          etiket={t("rezYonOzetAlan")}
          deger={String(aktifAlan)}
          durum="notr"
          ikon={<RezIkonu yol={IKON_ALAN} />}
          altBilgi={t("rezYonOzetAlanAlt")}
        />
        <OzetKarti
          etiket={t("rezYonOzetBugun")}
          deger={String(bugunSayisi?.meta?.total ?? 0)}
          durum="bilgi"
          ikon={<RezIkonu yol={IKON_TAKVIM} />}
        />
        <OzetKarti
          etiket={t("rezYonOzetAktif")}
          deger={String(aktifSayisi?.meta?.total ?? 0)}
          durum="olumlu"
          ikon={<RezIkonu yol={IKON_ONAY} />}
          altBilgi={t("rezYonOzetAktifAlt")}
        />
      </OzetSeridi>

      <Sekmeler
        aktifId={sekme}
        onDegis={setSekme}
        sekmeler={[
          { id: SEKME_ALANLAR, baslik: t("rezYonAlanlar"), icerik: <AlanlarSekmesi /> },
          { id: SEKME_REZ, baslik: t("rezYonRezervasyonlar"), icerik: <RezervasyonlarSekmesi /> },
        ]}
      />
    </div>
  );
}

// ------------------------------- ALANLAR ----------------------------------- //
function AlanlarSekmesi() {
  const t = useT();
  const toast = useToast();
  const { data, isLoading, error, mutate } = useSWR<{ items: OrtakAlan[] }>(
    "/api/common-areas",
    jsonFetcher,
  );
  const [taslak, setTaslak] = useState<AlanTaslak | null>(null);
  const [formHata, setFormHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const alanlar = data?.items ?? [];

  async function kaydet() {
    if (!taslak) return;
    if (!taslak.ad.trim() || !taslak.acilis || !taslak.kapanis) {
      setFormHata(t("rezervasyonAlanZorunlu"));
      return;
    }
    setFormHata(null);
    setGonderiyor(true);
    try {
      const govde = {
        ad: taslak.ad.trim(),
        aciklama: taslak.aciklama.trim() || null,
        acilis: taslak.acilis,
        kapanis: taslak.kapanis,
        slot_dakika: Number(taslak.slot_dakika) || 60,
      };
      if (taslak.id) {
        await apiSend(`/api/common-areas/${taslak.id}`, "PATCH", govde);
        toast.success(t("rezYonAlanGuncellendi"));
      } else {
        await apiSend("/api/common-areas", "POST", govde);
        toast.success(t("rezYonAlanOlusturuldu"));
      }
      setTaslak(null);
      void mutate();
    } catch (e) {
      // SUNUCU metni aynen: ad çakışması / saat tutarsızlığı gerekçesini en
      // doğru anlatan cümle onunkidir (409/422 tenant dilinde döner).
      setFormHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  async function aktiflikDegis(a: OrtakAlan) {
    try {
      await apiSend(`/api/common-areas/${a.id}`, "PATCH", { aktif: !a.aktif });
      toast.success(t("rezYonAlanGuncellendi"));
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Dugme tur="birincil" boy="kucuk" onClick={() => { setFormHata(null); setTaslak({ ...BOS_TASLAK }); }}>
          {t("rezYonYeniAlan")}
        </Dugme>
      </div>

      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? <IskeletMetin satir={3} /> : null}
      {!isLoading && !error && alanlar.length === 0 ? (
        <BosDurum baslik={t("rezYonAlanYok")} aciklama={t("rezYonAlanYokAlt")} />
      ) : null}

      <div className="space-y-3">
        {alanlar.map((a) => (
          <Kart key={a.id} className="space-y-1">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{a.ad}</h3>
              {/* (P245) ELLE KURULMUS ROZET -> PAYLASILAN `Rozet`.
                  OLCULEN KUSUR: zemin `--yz-success-edge` (#159946),
                  metin `--yz-success-ink` (#107736) — yesil uzerine
                  yesil, kontrast 1.53 (esik 4.5). Etiket okunmuyordu.
                  Gercek tarayicida goruldu; jsdom renk cozmedigi icin
                  hicbir test bunu olcemezdi (P226 dersi).
                  `Rozet` kenar + metin kullanir, dolgu DEGIL. */}
              <Rozet durum={a.aktif ? R_OLUMLU : R_NOTR}>
                {a.aktif ? t("rezYonAktif") : t("rezYonPasif")}
              </Rozet>
            </div>
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
              {a.acilis}–{a.kapanis} · {t("rezYonSlotOzet", { n: a.slot_dakika })}
            </p>
            {a.aciklama ? (
              <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>{a.aciklama}</p>
            ) : null}
            <div className="flex gap-2 pt-1">
              <Dugme boy="kucuk" onClick={() => {
                setFormHata(null);
                setTaslak({
                  id: a.id, ad: a.ad, aciklama: a.aciklama ?? "",
                  acilis: a.acilis, kapanis: a.kapanis, slot_dakika: String(a.slot_dakika),
                });
              }}>
                {t("rezYonDuzenle")}
              </Dugme>
              <Dugme boy="kucuk" tur="sessiz" onClick={() => void aktiflikDegis(a)}>
                {a.aktif ? t("rezYonPasiflestir") : t("rezYonAktiflestir")}
              </Dugme>
            </div>
          </Kart>
        ))}
      </div>

      <Modal
        acik={taslak !== null}
        onKapat={() => setTaslak(null)}
        baslik={taslak?.id ? t("rezYonDuzenle") : t("rezYonYeniAlan")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setTaslak(null)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={gonderiyor} onClick={() => void kaydet()}>
              {gonderiyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        {taslak ? (
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <AlanSarmal etiket={t("rezYonAlanAdi")}>
                {(b) => (
                  <Alan maxLength={SINIR.BASLIK /* sunucu: OrtakAlanCreate.ad */} {...b} value={taslak.ad}
                    onChange={(e) => setTaslak({ ...taslak, ad: e.target.value })} />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("rezYonSlotDk")}>
                {(b) => (
                  <Alan {...b} type="number" min={1}
                    value={taslak.slot_dakika}
                    onChange={(e) => setTaslak({ ...taslak, slot_dakika: e.target.value })} />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("rezYonAcilis")}>
                {(b) => (
                  <Alan {...b} type="time" value={taslak.acilis}
                    onChange={(e) => setTaslak({ ...taslak, acilis: e.target.value })} />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("rezYonKapanis")}>
                {(b) => (
                  <Alan {...b} type="time" value={taslak.kapanis}
                    onChange={(e) => setTaslak({ ...taslak, kapanis: e.target.value })} />
                )}
              </AlanSarmal>
            </div>
            <AlanSarmal etiket={t("rezYonAciklama")}>
              {(b) => (
                <Alan maxLength={1000 /* sunucu: OrtakAlanCreate.aciklama */} {...b} value={taslak.aciklama}
                  onChange={(e) => setTaslak({ ...taslak, aciklama: e.target.value })} />
              )}
            </AlanSarmal>
            <HataDurumu mesaj={formHata} />
          </div>
        ) : null}
      </Modal>
    </div>
  );
}

// ---------------------------- REZERVASYONLAR ------------------------------- //
function RezervasyonlarSekmesi() {
  const t = useT();
  const toast = useToast();
  const [gecmis, setGecmis] = useState(false);
  const [alanId, setAlanId] = useState("");
  const [tarih, setTarih] = useState("");

  const { data: alanVeri } = useSWR<{ items: OrtakAlan[] }>("/api/common-areas", jsonFetcher);
  const alanlar = alanVeri?.items ?? [];

  const qs = new URLSearchParams({ limit: "100", offset: "0", gecmis: String(gecmis) });
  if (alanId) qs.set("alan_id", alanId);
  if (tarih) qs.set("tarih", tarih);
  const { data, isLoading, error, mutate } = useSWR<{ items: Rezervasyon[] }>(
    `/api/reservations?${qs.toString()}`,
    jsonFetcher,
  );
  const kayitlar = data?.items ?? [];

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
    <div className="space-y-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="w-full sm:w-56">
          <AlanSarmal etiket={t("rezervasyonAlan")}>
            {(b) => (
              <Secim {...b} value={alanId} onChange={(e) => setAlanId(e.target.value)}>
                <option value="">{t("rezYonTumAlanlar")}</option>
                {alanlar.map((a) => (
                  <option key={a.id} value={a.id}>{a.ad}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        </div>
        <div className="w-full sm:w-44">
          <AlanSarmal etiket={t("rezervasyonTarih")}>
            {(b) => (
              <Alan {...b} type="date" value={tarih} onChange={(e) => setTarih(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
        <Sekmeler
          aktifId={gecmis ? "g" : "a"}
          onDegis={(id) => setGecmis(id === "g")}
          sekmeler={[
            { id: "a", baslik: t("rezervasyonSekmeAktif"), icerik: null },
            { id: "g", baslik: t("rezervasyonSekmeGecmis"), icerik: null },
          ]}
        />
      </div>

      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? <IskeletMetin satir={3} /> : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <BosDurum baslik={t("rezYonRezYok")} aciklama={t("rezYonRezYokAlt")} />
      ) : null}

      <div className="space-y-3">
        {kayitlar.map((r) => (
          <Kart key={r.id} className="space-y-1">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{r.alan_ad ?? "—"}</h3>
              {/* Ayni gerekce: durum rozeti de paylasilan bilesenden. */}
              <Rozet durum={r.durum === DURUM_IPTAL ? R_NOTR : R_OLUMLU}>
                {t(durumAnahtari(r.durum))}
              </Rozet>
            </div>
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
              {tarihBicimi(r.tarih)} · {r.baslangic}–{r.bitis} ·{" "}
              {t("rezervasyonKisiSayisi", { n: r.kisi_sayisi })}
            </p>
            {!r.gecmis && r.durum !== "iptal" ? (
              <Dugme boy="kucuk" onClick={() => void iptalEt(r.id)}>
                {t("rezervasyonIptalEt")}
              </Dugme>
            ) : null}
          </Kart>
        ))}
      </div>
    </div>
  );
}
