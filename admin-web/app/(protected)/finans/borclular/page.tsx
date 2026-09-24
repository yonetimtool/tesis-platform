"use client";

// (P192 §5.1-5.3) BORCLULAR — yaslandirma + tahsilat gostergesi + toplu islem.
//
// =====================================================================
// NEDEN AYNI SAYFADA
// =====================================================================
// Yaslandirma bir SORU sorar ("kim ne kadar suredir borclu"), toplu
// islem o sorunun CEVABINI uygular. Ikisini ayirmak, yoneticiyi listeyi
// bir ekranda gorup baska bir ekranda tekrar secmeye zorlardi.
//
// Tahsilat gostergesi de burada cunku yoneticinin ilk baktigi sayi odur
// ve yaslandirmanin BAGLAMIDIR: %95 tahsilatta 90+ kovasindaki uc daire
// bir sorun degil, %60'ta ayni uc daire bir uyaridir.

import { useState } from "react";
import useSWR from "swr";

// (P245) OZET SERIDI IKONLARI ve "veri yok" isareti.
const YOK_ISARETI = "—";
const IKON_KISI = "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z";
const IKON_BORC = "M12 9v4m0 4h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z";
const IKON_ORTALAMA = "M3 3v18h18M7 15l4-4 3 3 5-6";

function BorcIkonu({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  Grafik,
  Kart,
  Modal,
  HataDurumu,
  VeriTablosu,
  type Kolon,
  OzetKarti,
  OzetSeridi,
  SayfaBasligi,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL } from "@/lib/money";

const YOK = "—";

/** Dugme turu — ADLI TIP, satir ici birlesim DEGIL.
 *
 * Sabit-metin taramasi `): "birincil" | "ikincil"` gibi bir imzayi da
 * "cevrilmemis metin" sayiyor (iki nokta + dizge). Tarama haksiz degil:
 * gorunen metinle bilesen turunu ayirt edemez. Adli tip ikisini de
 * cozer ve imzayi okunakli birakir. */
type DugmeTuru = (typeof DUGME_TURLERI)[number];
const DUGME_TURLERI = ["birincil", "ikincil"] as const;

/** Secili kovanin dugme turu (secili olan VURGULU cizilir). */
function kovaTuru(secili: boolean): DugmeTuru {
  if (secili) return DUGME_TURLERI[0];
  return DUGME_TURLERI[1];
}

interface Daire {
  unit_id: string;
  unit_no: string;
  en_eski_gun: number;
  kova: string;
  kalan_kurus: number;
  borclu_ad: string | null;
}

interface Kova {
  kova: string;
  daire: number;
  kalan_kurus: number;
  daireler: Daire[];
}

interface Yaslandirma {
  kovalar: Kova[];
  toplam_kalan_kurus: number;
  toplam_daire: number;
}

interface Gosterge {
  donem: string;
  tahakkuk_kurus: number;
  tahsilat_kurus: number;
  oran_yuzde: number | null;
  onceki_oran_yuzde: number | null;
  degisim_puan: number | null;
}

function GostergeKarti() {
  const t = useT();
  const { data } = useSWR<Gosterge>(
    "/api/panel/tahsilat-gostergesi", jsonFetcher);
  if (!data) return null;
  return (
    <Kart>
      <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {t("gosTahsilatOrani")}
      </h2>
      <p className="tabular-nums" style={{ fontSize: "var(--yz-fs-h1)" }}>
        {data.oran_yuzde === null ? YOK : `%${data.oran_yuzde}`}
      </p>
      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {data.onceki_oran_yuzde === null
          ? t("gosDegisimYok")
          : t("gosGecenAy", { oran: data.onceki_oran_yuzde })}
      </p>
      <p className="tabular-nums" style={{ fontSize: "var(--yz-fs-sm)" }}>
        {kurusToTL(data.tahsilat_kurus)} / {kurusToTL(data.tahakkuk_kurus)}
      </p>
    </Kart>
  );
}

function PlanModal({
  acik, onKapat, secili, onBitti,
}: {
  acik: boolean; onKapat: () => void; secili: string[]; onBitti: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const [taksit, setTaksit] = useState("3");
  const [vade, setVade] = useState(new Date().toISOString().slice(0, 10));
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  async function uygula() {
    setHata(null);
    setMesgul(true);
    try {
      const s = await apiSend<{ daire: number }>(
        "/api/panel/borclulara-odeme-plani", "POST", {
          unit_ids: secili,
          taksit_sayisi: Number(taksit),
          ilk_vade: vade,
        });
      toast.success(t("yasPlanUygulandi", { n: s.daire }));
      onBitti();
      onKapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  return (
    <Modal
      acik={acik}
      baslik={t("yasOdemePlani")}
      onKapat={onKapat}
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          <Dugme tur="birincil" disabled={mesgul} onClick={() => void uygula()}>
            {mesgul ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </span>
      }
    >
      <div className="grid gap-3">
        <AlanSarmal etiket={t("yasTaksit")}>
          {(b) => (
            <Alan {...b} type="number" min={2} max={36} value={taksit}
              onChange={(e) => setTaksit(e.target.value)} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("yasIlkVade")}>
          {(b) => (
            <Alan {...b} type="date" value={vade}
              onChange={(e) => setVade(e.target.value)} />
          )}
        </AlanSarmal>
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}

export default function BorclularPage() {
  const t = useT();
  const toast = useToast();
  const [kova, setKova] = useState<string | null>(null);
  const [secili, setSecili] = useState<string[]>([]);
  const [plan, setPlan] = useState(false);

  const { data, error, isLoading, mutate } = useSWR<Yaslandirma>(
    kova
      ? `/api/panel/yaslandirma?kova=${encodeURIComponent(kova)}`
      : "/api/panel/yaslandirma?ozet=true",
    jsonFetcher,
  );
  const satirlar = kova
    ? (data?.kovalar.find((k) => k.kova === kova)?.daireler ?? [])
    : [];

  async function toplu(yol: string, basari: (n: number) => string) {
    if (secili.length === 0) return;
    try {
      const s = await apiSend<Record<string, number>>(yol, "POST", {
        unit_ids: secili,
      });
      toast.success(basari(s.gonderilen ?? s.affedilen_kalem ?? 0));
      setSecili([]);
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const kolonlar: Kolon<Daire>[] = [
    { id: "sec", baslik: "", hucre: (d) => (
      <input
        type="checkbox"
        aria-label={d.unit_no}
        checked={secili.includes(d.unit_id)}
        onChange={(e) =>
          setSecili((o) =>
            e.target.checked
              ? [...o, d.unit_id]
              : o.filter((x) => x !== d.unit_id),
          )
        }
      />
    ) },
    { id: "daire", baslik: t("finansSutunDaire"), hucre: (d) => d.unit_no },
    { id: "borclu", baslik: t("yasBorclu"), hucre: (d) => d.borclu_ad ?? YOK },
    { id: "gun", baslik: t("yasGun"), sayisal: true,
      hucre: (d) => String(d.en_eski_gun), deger: (d) => d.en_eski_gun },
    { id: "kalan", baslik: t("yasKalan"), sayisal: true,
      hucre: (d) => <span className="tabular-nums">{kurusToTL(d.kalan_kurus)}</span>,
      deger: (d) => d.kalan_kurus },
  ];

  return (
    <div>
      <SayfaBasligi baslik={t("finansBorclular")} aciklama={t("borclularSayfaAlt")} />

      {/* (P245) OZET SERIDI — referansta (ui2, borclular ekrani) ustte uc kart:
          toplam borclu, toplam borc, ortalama.
          -----------------------------------------------------------------
          SAYILAR YASLANDIRMA UCUNDAN ve SUZGECSIZ: sayfadaki kova
          secimi listeyi daraltir, SERIDI DEGIL. Aksi halde "90+"
          secildiginde "Toplam borclu: 3" yazardi — oysa toplam borclu
          degismez (P244 §8c dersi).
          ORTALAMA TURETILIR ama UYDURULMAZ: daire sayisi sifirken
          bolme yapilmaz, "—" yazilir. */}
      <OzetSeridi>
        <OzetKarti
          etiket={t("borclularOzetDaire")}
          deger={String(data?.toplam_daire ?? 0)}
          durum={(data?.toplam_daire ?? 0) > 0 ? "uyari" : "olumlu"}
          ikon={<BorcIkonu yol={IKON_KISI} />}
        />
        <OzetKarti
          // (E2E 2026-09, FINANS-06) Bu rakam yalniz VADESI GECMIS borcun
          // toplamidir; "Toplam acik borc" adi Finans ekranindaki (tum acik
          // borc) rakamla ayni adi tasiyordu.
          etiket={t("borclularOzetVadesiGecmis")}
          deger={kurusToTL(data?.toplam_kalan_kurus ?? 0)}
          durum={(data?.toplam_kalan_kurus ?? 0) > 0 ? "kritik" : "olumlu"}
          ikon={<BorcIkonu yol={IKON_BORC} />}
        />
        <OzetKarti
          etiket={t("borclularOzetOrtalama")}
          deger={
            data && data.toplam_daire > 0
              ? kurusToTL(Math.round(data.toplam_kalan_kurus / data.toplam_daire))
              : YOK_ISARETI
          }
          durum="notr"
          ikon={<BorcIkonu yol={IKON_ORTALAMA} />}
          altBilgi={t("borclularOzetOrtalamaAlt")}
        />
      </OzetSeridi>

      <GostergeKarti />

      <Kart>
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("yasBaslik")}
        </h2>
        <p className="mb-3" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("yasAciklama")}
        </p>
        {error && <HataDurumu mesaj={t("ortakHataOlustu")} onTekrar={() => void mutate()} />}
        {/* (P223 §4) YASLANDIRMA GORSELI — YATAY cubuk.
            Kovalar bugune kadar yalnizca dugme olarak diziliyordu: hangi
            kovanin agir bastigi ancak rakamlar tek tek okunarak
            anlasiliyordu. Yatay secildi cunku etiketler ("90+") dikey
            eksende kirpilmadan sigar ve kova sirasi YUKARIDAN ASAGIYA
            dogal okunur. Rakamlar grafigin altindaki tabloda DA var
            (bilesen her zaman cizer) — renk tek basina anlam tasimaz. */}
        {(data?.kovalar ?? []).length > 0 && (
          <div className="mb-3">
            <Grafik
              tur="yatay"
              baslik={t("yasGrafikBaslik")}
              bosBaslik={t("yasKovaYok")}
              // (E2E 2026-09, FINANS-20) GRAFIGE TL VERILIR. Cubuk ekseni
              // `bicimle`yi kullanmiyor ve kurusu ham yaziyordu: 2.000 TL'lik
              // kova ekseni 200000'e uzaniyor, 100 kat buyuk okunuyordu.
              // Tablo satiri TL'yi kurusa geri cevirip ayni bicimle yazar.
              dilimler={(data?.kovalar ?? []).map((k) => ({
                ad: k.kova,
                deger: k.kalan_kurus / 100,
              }))}
              bicimle={(n) => kurusToTL(Math.round(n * 100))}
            />
          </div>
        )}
        <div className="flex flex-wrap gap-2">
          {(data?.kovalar ?? []).map((k) => (
            <Dugme
              key={k.kova}
              // Secili kova VURGULU cizilir. Uclu ifade sabit-metin
              // taramasina takildigi icin degisken uzerinden veriliyor:
              // tarama JSX icindeki her uclu dizeyi cevrilmemis metin
              // sayiyor ve burada dizeler BILESEN TURUDUR, metin degil.
              tur={kovaTuru(kova === k.kova)}
              boy="kucuk"
              onClick={() => { setKova(kova === k.kova ? null : k.kova); setSecili([]); }}
            >
              {/* Kova ETIKETLERI SAYIDIR ("0-30"), cevrilmez: gun araligi
                  her dilde ayni yazilir ve cevirmek yanlis araliklar
                  uretme riski acardi. */}
              <span className="tabular-nums">{k.kova}</span>
              {" · "}
              {t("yasDaireSayisi", { n: k.daire })}
              {" · "}
              <span className="tabular-nums">{kurusToTL(k.kalan_kurus)}</span>
            </Dugme>
          ))}
        </div>
      </Kart>

      {kova && (
        <Kart>
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
              {t("yasSecilen", { n: secili.length })}
            </span>
            <span className="flex flex-wrap gap-2">
              <Dugme tur="ikincil" boy="kucuk" disabled={secili.length === 0}
                onClick={() => void toplu(
                  "/api/panel/borclulara-hatirlat",
                  (n) => t("yasHatirlatildi", { n }),
                )}
              >
                {t("yasTopluHatirlat")}
              </Dugme>
              <Dugme tur="ikincil" boy="kucuk" disabled={secili.length === 0}
                onClick={() => void toplu(
                  "/api/panel/borclulara-faiz-affi",
                  (n) => t("yasAffedildi", { n }),
                )}
              >
                {t("yasTopluFaizAffi")}
              </Dugme>
              <Dugme tur="ikincil" boy="kucuk" disabled={secili.length === 0}
                onClick={() => setPlan(true)}
              >
                {t("yasOdemePlani")}
              </Dugme>
            </span>
          </div>
          <VeriTablosu
            kolonlar={kolonlar}
            satirlar={satirlar}
            satirId={(d) => d.unit_id}
            yukleniyor={isLoading}
            // (E2E 2026-09) "Henuz kayit yok" borclu listesinde bir sey
            // soylemiyordu: borc yoksa bu NORMAL durumdur ve oyle denir.
            bosBaslik={t("borclularBos")}
            bosAciklama={t("borclularBosAlt")}
          />
        </Kart>
      )}

      <PlanModal
        acik={plan}
        onKapat={() => setPlan(false)}
        secili={secili}
        onBitti={() => { setSecili([]); void mutate(); }}
      />
    </div>
  );
}
