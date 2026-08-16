"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  Dugme,
  Kart,
  Modal,
  Rozet,
  Sekmeler,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { ODEME_DURUM, ODEME_YONTEM, enumAdi } from "@/lib/enum-adlari";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { kisaKimlik } from "@/lib/kimlik";
import { kurusToTL, tlToKurus } from "@/lib/money";
import { useT } from "@/lib/i18n/kullan";
import type {
  DuesAssessmentList,
  DuesAssessmentResult,
  DuesPayment,
  DuesAssessment,
  DuesPaymentList,
  UnitList,
} from "@/lib/types";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SEKME_TAHAKKUK = "tahakkuk" as const;
const SEKME_ODEME = "odeme" as const;
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_UYARI = "uyari" as const;
const DURUM_NOTR = "notr" as const;

const BOS_DURUM: TabloDurumu = {
  sayfa: 1,
  boy: 25,
  siraKolon: null,
  siraYonu: "artan",
};

export default function DuesPage() {
  const t = useT();
  const toast = useToast();
  const [sekme, setSekme] = useState<string>(SEKME_TAHAKKUK);

  // --- toplu tahakkuk ---
  const [donem, setDonem] = useState("");
  const [tl, setTl] = useState("");
  const [son, setSon] = useState("");
  const [desc, setDesc] = useState("");
  const [bErr, setBErr] = useState<string | null>(null);
  const [bRes, setBRes] = useState<{ created: number; atlanan: number } | null>(null);
  const [bBusy, setBBusy] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);

  // --- listeler ---
  const [aDonem, setADonem] = useState("");
  const [aDurum, setADurum] = useState<TabloDurumu>(BOS_DURUM);
  const aOffset = (aDurum.sayfa - 1) * aDurum.boy;
  const aQs = aDonem ? `&donem=${encodeURIComponent(aDonem)}` : "";
  // HATA SESSIZ KALMAMALI: uc dustugunde sayfa "Tahakkuk yok" gosteriyordu —
  // kullanici "kayit yok" ile "sunucu dustu"yu ayirt edemiyordu (tur 42).
  const {
    data: assessments,
    error: aErr,
    isLoading: aYukleniyor,
    mutate: mutateA,
  } = useSWR<DuesAssessmentList>(
    `/api/dues/assessments?limit=${aDurum.boy}&offset=${aOffset}${aQs}`,
    jsonFetcher,
  );

  const [pDurum, setPDurum] = useState<TabloDurumu>(BOS_DURUM);
  const pOffset = (pDurum.sayfa - 1) * pDurum.boy;
  const {
    data: payments,
    error: pErr,
    isLoading: pYukleniyor,
    mutate: mutateP,
  } = useSWR<DuesPaymentList>(
    `/api/dues/payments?limit=${pDurum.boy}&offset=${pOffset}`,
    jsonFetcher,
  );

  // (P160) DAIRE NUMARASI. Sozlesme yalniz `unit_id` donuyor ve sayfa
  // ekrana `u.slice(0,8)` — yani bir UUID parcasi — yaziyordu. Aidat
  // ekraninda "hangi daire" en temel sorudur ve UUID onu YANITLAMIYOR.
  // Uc DEGISTIRILMEDI (kilitli kural 1); daire listesi ayrica cekilip
  // istemcide eslestiriliyor. Uc en fazla 200 daire dondurdugu icin
  // eslesmeyen kimlik ESKI davranisa (kisa kimlik) duser — uydurma ad
  // gosterilmez.
  const { data: units } = useSWR<UnitList>("/api/units?limit=200&offset=0", jsonFetcher);
  const daireAdlari = useMemo(() => {
    const m = new Map<string, string>();
    for (const u of units?.items ?? []) {
      m.set(u.id, u.blok ? `${u.blok}/${u.no}` : u.no);
    }
    return m;
  }, [units]);
  const daireAdi = (id: string) => daireAdlari.get(id) ?? kisaKimlik(id);

  async function bulk(e: React.FormEvent) {
    e.preventDefault();
    setBErr(null);
    setBRes(null);
    const k = tlToKurus(tl);
    if (k === null || k <= 0) {
      setBErr(t("aidatTutarGecersiz"));
      return;
    }
    setBBusy(true);
    try {
      // unit_id/unit_ids YOK -> tum aktif daireler. Mevcut donemler atlanir.
      const res = await apiSend<DuesAssessmentResult>("/api/dues/assessments", "POST", {
        donem,
        tutar_kurus: k,
        son_odeme_tarihi: son || null,
        aciklama: desc || null,
      });
      setBRes({ created: res.created.length, atlanan: res.atlanan });
      mutateA();
      toast.success(t("aidatTopluOlusturuldu"));
    } catch (err) {
      setBErr(err instanceof Error ? err.message : t("aidatTopluOlusturulamadi"));
    } finally {
      setBBusy(false);
    }
  }

  const tahakkukKolonlari: Kolon<DuesAssessment>[] = useMemo(
    () => [
      {
        id: "daire",
        baslik: t("raporTabloDaire"),
        gizlenebilir: false,
        hucre: (a) => daireAdi(a.unit_id),
      },
      { id: "donem", baslik: t("ortakDonem"), hucre: (a) => a.donem },
      {
        id: "tutar",
        baslik: t("raporTabloTutar"),
        sayisal: true,
        hucre: (a) => <span className="font-medium">{kurusToTL(a.tutar_kurus)}</span>,
      },
      {
        id: "son",
        baslik: t("aidatSonOdemeKisa"),
        hucre: (a) => a.son_odeme_tarihi ?? "—",
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, daireAdlari],
  );

  const odemeKolonlari: Kolon<DuesPayment>[] = useMemo(
    () => [
      {
        id: "daire",
        baslik: t("raporTabloDaire"),
        gizlenebilir: false,
        hucre: (p) => daireAdi(p.unit_id),
      },
      { id: "yontem", baslik: t("aidatYontem"), hucre: (p) => enumAdi(t, ODEME_YONTEM, p.yontem) },
      {
        id: "durum",
        baslik: t("ortakDurum"),
        hucre: (p) => (
          <Rozet
            durum={
              p.durum === "basarili"
                ? DURUM_OLUMLU
                : p.durum === "bekliyor"
                  ? DURUM_UYARI
                  : DURUM_NOTR
            }
          >
            {enumAdi(t, ODEME_DURUM, p.durum)}
          </Rozet>
        ),
      },
      {
        id: "tutar",
        baslik: t("raporTabloTutar"),
        sayisal: true,
        hucre: (p) => <span className="font-medium">{kurusToTL(p.tutar_kurus)}</span>,
      },
      {
        id: "zaman",
        baslik: t("raporTabloZaman"),
        darEkrandaGizle: true,
        hucre: (p) => formatDateTime(p.odeme_zamani),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, daireAdlari],
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("aidatBaslik")}
      </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={() => {
          // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden acildiginda
          // onceki denemenin mesaji ekranda duruyordu ve kullanici hic
          // denemeden hata gormus oluyordu.
          setBErr(null);
          setModalAcik(true);
        }}>
          {t("aidatTopluOlustur")}
        </Dugme>
      </div>

      {/* TOPLU TAHAKKUK — (P161) MODALA ALINDI.
          P160'ta "dugme arkasina saklamak onu bulunmaz yapardi" diye
          sayfada birakilmisti. P161 butun olusturma islemlerini modala
          topladi ve gerekce degisti: bulunurluk artik BASLIKTAKI
          dugmeyle saglaniyor, form ise listeyi asagi itmiyor. */}
      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("aidatTopluBaslik")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={bBusy}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="aidat-form" yukleniyor={bBusy}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="aidat-form" onSubmit={bulk} className="space-y-3">
          {/* DAR EKRAN: 4 sutun 360 dp'ye sigmiyor — Rusca etiketlerle sayfa
              yana kayiyordu (tur 25 surusu +23 px olctu). Dar ekranda 2,
              sm'den itibaren 4 sutun. */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <AlanSarmal etiket={t("ortakDonem")} ipucu={t("aidatDonemOrnek")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  value={donem}
                  onChange={(e) => setDonem(e.target.value)}
                  placeholder="2026-07"
                  required
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("aidatTutarTl")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  inputMode="decimal"
                  value={tl}
                  onChange={(e) => setTl(e.target.value)}
                  placeholder="750,00"
                  required
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("aidatSonOdeme")}>
              {(b) => (
                <Alan {...b} type="date" value={son} onChange={(e) => setSon(e.target.value)} />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("ortakAciklamaOpsiyonel")}>
              {(b) => (
                <Alan {...b} value={desc} onChange={(e) => setDesc(e.target.value)} />
              )}
            </AlanSarmal>
          </div>

          {bErr && (
            <p
              role="alert"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {bErr}
            </p>
          )}
          {bRes && (
            <p
              role="status"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-success-ink)" }}
            >
              {t("aidatTopluSonuc", { olusan: bRes.created, atlanan: bRes.atlanan })}
            </p>
          )}
        </form>
      </Modal>

      {/* IKI LISTE SEKMEDE: ikisi de 4-5 sutunlu ve AYRI sayfaliyor;
          alt alta konunca sayfa surekli kaydiriliyordu. Ikisi de tek
          tik uzakta — gizlenmiyor. */}
      <Sekmeler
        aktifId={sekme}
        onDegis={setSekme}
        sekmeler={[
          {
            id: SEKME_TAHAKKUK,
            baslik: t("aidatTahakkuklar"),
            icerik: (
              <VeriTablosu<DuesAssessment>
                kolonlar={tahakkukKolonlari}
                satirlar={assessments?.items ?? []}
                satirId={(a) => a.id}
                hata={aErr ? aErr.message : null}
                onTekrar={() => void mutateA()}
                yukleniyor={aYukleniyor && !assessments}
                bosBaslik={t("aidatTahakkukYok")}
                bosAciklama={t("aidatTahakkukYokAlt")}
                sunucuTarafli
                toplam={assessments?.meta?.total ?? 0}
                durum={aDurum}
                onDurumDegisti={setADurum}
                araclar={
                  <div className="w-full sm:w-48">
                    <AlanSarmal etiket={t("aidatDonemFiltresi")}>
                      {(b) => (
                        <Alan
                          {...b}
                          value={aDonem}
                          onChange={(e) => {
                            setADonem(e.target.value);
                            // Suzgec degisince BASA don: eski sayfada
                            // kalmak bos gorunen bir liste demekti.
                            setADurum({ ...aDurum, sayfa: 1 });
                          }}
                          placeholder="2026-07"
                        />
                      )}
                    </AlanSarmal>
                  </div>
                }
              />
            ),
          },
          {
            id: SEKME_ODEME,
            baslik: t("aidatOdemeler"),
            icerik: (
              <VeriTablosu<DuesPayment>
                kolonlar={odemeKolonlari}
                satirlar={payments?.items ?? []}
                satirId={(p) => p.id}
                hata={pErr ? pErr.message : null}
                onTekrar={() => void mutateP()}
                yukleniyor={pYukleniyor && !payments}
                bosBaslik={t("aidatOdemeYok")}
                bosAciklama={t("aidatOdemeYokAlt")}
                sunucuTarafli
                toplam={payments?.meta?.total ?? 0}
                durum={pDurum}
                onDurumDegisti={setPDurum}
              />
            ),
          },
        ]}
      />
    </div>
  );
}
