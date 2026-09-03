"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Kart,
  Modal,
  Rozet,
  Secim,
} from "@/components/ui";
import { KalipModali } from "@/components/vardiya/kalip-modali";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { rolAdi } from "@/lib/roles";
import type { AsyncIs } from "@/lib/tipler";

/**
 * (P205 §2) VARDIYA PLANLAMA — ZAMAN CIZELGESI.
 *
 * =========================================================================
 * NEDEN IZGARA DEGIL CIZELGE
 * =========================================================================
 * P203'teki ekran GUN x VARDIYA izgarasiydi ve "bu gun bu vardiyada kim
 * var" sorusunu yanitliyordu. Yoneticinin sordugu ikinci soru ise
 * KISIYE aittir: "Ali bu hafta ne zaman calisiyor, bosluk nerede".
 * Izgarada bir kisinin haftasini gormek icin yedi hucreyi gozle taramak
 * gerekiyordu. Cizelgede kisi BIR SATIRDIR ve bosluk GORULEBILIR bir
 * seydir.
 *
 * =========================================================================
 * GORUNUM SECICI: SAAT EKSENI HER ZOOM'DA ANLAMLI DEGIL
 * =========================================================================
 * GUN ICI ve HAFTA gorunumlerinde eksen SAATTIR (00:00-23:00). AY
 * gorunumunde eksen GUNDUR: 31 gun x 24 saat = 744 sutun, hicbir
 * ekranda okunmaz ve yatay kaydirma bunu kullanilabilir yapmaz. Ayda
 * sorulan soru zaten "hangi GUNLER calisiyor"dur.
 *
 * =========================================================================
 * BLOK SURUKLENMIYOR — KARAR VE GEREKCE
 * =========================================================================
 * Suruklemek "kolay" gorunur ama BEDELI SESSIZ: dokunmatik ekranda
 * kaydirma ile surukleme ayni harekettir ve yanlislikla birakilan bir
 * blok, KIMSENIN FARK ETMEDIGI bir vardiya degisikligi uretir —
 * ustelik denetime "yonetici degistirdi" diye yazilir. Bu ekranda
 * degisiklik ACIK bir eylemdir: bloga tiklanir, saat YAZILIR,
 * kaydedilir. Ayrintili gerekce `docs/P205-kararlar.md` K2.4.
 */

type Blok = {
  plan_id: string;
  tarih: string;
  baslar: string;
  biter: string;
  shift_ad: string | null;
  not_metni: string | null;
  gece_asiyor: boolean;
};
type CizelgeKisi = { user_id: string; ad: string; rol: string; bloklar: Blok[] };
type Cizelge = { baslangic: string; bitis: string; personel: CizelgeKisi[] };
type Personel = { id: string; ad: string; role: string };
type Slot = {
  shift_ad: string;
  baslangic_saat: string;
  bitis_saat: string;
};
type Kisi = { plan_id: string; user_id: string; ad: string; rol: string };
type Simdi = {
  gorevdeki_vardiya: Slot | null;
  gorevdekiler: Kisi[];
  sonraki_vardiya: Slot | null;
  sonrakiler: Kisi[];
};
type TopluGun = { tarih: string; durum: string; plan_id: string | null };
type TopluSonuc = {
  uygulandi: boolean;
  eklenen: number;
  cakisan: number;
  gunler: TopluGun[];
  uyarilar: string[];
};

type Gorunum = "gun" | "hafta" | "ay";
const GUN_SAYISI: Record<Gorunum, number> = { gun: 1, hafta: 7, ay: 31 };
const GORUNUMLER: Gorunum[] = ["gun", "hafta", "ay"];
/** Gorunum -> sozluk anahtari. JSX icinde ucluyla secilseydi
 *  `sabit-metin` taramasi anahtarlari CEVRILMEMIS METIN sanardi
 *  (hakli bir tarama, yanlis bir eslesme). */
const GORUNUM_ANAHTARI = {
  gun: "vardiyaGorunumGun",
  hafta: "vardiyaGorunumHafta",
  ay: "vardiyaGorunumAy",
} as const;

/** Saat basina piksel — GUN ICI genis, HAFTA dar. Haftada 24 px/saat
 *  4032 px'lik bir tuval demekti; 12 px/saat ile hafta bir ekrana iki
 *  kaydirmada sigar ve bloklar hâlâ ayirt edilebilir. */
const PX_SAAT: Record<Gorunum, number> = { gun: 56, hafta: 12, ay: 0 };
/** AY gorunumunde eksen GUNDUR. */
const PX_GUN_AY = 34;

const SAATLER = Array.from({ length: 24 }, (_, i) => i);

/** Hafta gunu -> sozluk anahtari (JS `getDay()` sirasi: 0=pazar). */
const HAFTA_GUNLERI = [
  { gun: 1, anahtar: "gunPazartesi" },
  { gun: 2, anahtar: "gunSali" },
  { gun: 3, anahtar: "gunCarsamba" },
  { gun: 4, anahtar: "gunPersembe" },
  { gun: 5, anahtar: "gunCuma" },
  { gun: 6, anahtar: "gunCumartesi" },
  { gun: 0, anahtar: "gunPazar" },
] as const;

/** JSX ucluda sabit metin yazilamaz (`sabit-metin` taramasi). */
const SEFFAF = "transparent";

/** Dugme turleri — JSX ucluda sabit metin olarak yazilamaz. */
const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;

function isoGun(d: Date): string {
  // YEREL gun — `toISOString()` UTC'ye kaydirir ve TR'de gece
  // yarisindan sonra BIR GUN GERI gosterirdi.
  const y = d.getFullYear();
  const a = String(d.getMonth() + 1).padStart(2, "0");
  const g = String(d.getDate()).padStart(2, "0");
  return `${y}-${a}-${g}`;
}

function gunEkle(iso: string, gun: number): string {
  const d = new Date(`${iso}T00:00:00`);
  d.setDate(d.getDate() + gun);
  return isoGun(d);
}

/** Iki tarih arasindaki GUN farki (yerel, saat dilimi kaydirmasiz). */
function gunFarki(a: string, b: string): number {
  const x = new Date(`${a}T00:00:00`).getTime();
  const y = new Date(`${b}T00:00:00`).getTime();
  return Math.round((y - x) / 86_400_000);
}

/** `2026-09-02T22:00:00` -> gorunum baslangicindan itibaren SAAT. */
function saatOfseti(baslangic: string, damga: string): number {
  const d = new Date(damga);
  const bas = new Date(`${baslangic}T00:00:00`);
  return (d.getTime() - bas.getTime()) / 3_600_000;
}

const ss = (damga: string) => damga.slice(11, 16);

export default function VardiyaPlaniSayfasi() {
  const t = useT();
  const toast = useToast();
  const [gorunum, setGorunum] = useState<Gorunum>("hafta");
  const [baslangic, setBaslangic] = useState(() => isoGun(new Date()));
  const [rolSuzgeci, setRolSuzgeci] = useState("");
  const [aramaSuzgeci, setAramaSuzgeci] = useState("");
  const [filtrelerAcik, setFiltrelerAcik] = useState(false);
  const [ekleAcik, setEkleAcik] = useState(false);
  const [secili, setSecili] = useState<{ kisi: CizelgeKisi; blok: Blok } | null>(
    null,
  );
  // (P207 §1) AY GORUNUMUNDE GUN SECIMI.
  //
  // Secim SET olarak tutulur cunku secim DUZENSIZ olabilir ("tum
  // pazartesiler"); aralik (baslangic-bitis) bunu anlatamazdi.
  const [seciliGunler, setSeciliGunler] = useState<Set<string>>(new Set());
  const [kalipAcik, setKalipAcik] = useState(false);
  // Son toplu islemin kimligi — GERI ALMA bunu kullanir. Yalnizca son
  // islem tutulur: "hangi partiyi geri alacagim" sorusu yoneticiye
  // sorulacak bir sey degil; yanlis planin ardindan yapilan ILK sey
  // onu geri almaktir.
  const [sonParti, setSonParti] = useState<string | null>(null);
  // Suruklerken baslangic gunu — fare basiliyken gezilen gunler secilir.
  const [surukleBas, setSurukleBas] = useState<string | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);
  const seritRef = useRef<HTMLDivElement | null>(null);

  const gun = GUN_SAYISI[gorunum];
  const uc = `/api/vardiya-plani/cizelge?baslangic=${baslangic}&gun=${gun}`;
  const { data, error, mutate, isLoading } = useSWR<Cizelge>(uc, jsonFetcher);
  const { data: personel } = useSWR<{ items: Personel[] }>(
    "/api/users?limit=200",
    jsonFetcher,
  );
  // (P203 §4.2) ANLIK DURUM KORUNDU: cizelge "bu hafta kim calisiyor"
  // sorusunu yanitliyor, bu kart "SU AN kim gorevde" sorusunu. Ikincisi
  // cizelgeden gozle okunabilir gorunur ama gece 03:00'te dogru satiri
  // bulmak icin kaydirmak gerekirdi.
  const { data: simdiDurum } = useSWR<Simdi>(
    "/api/vardiya-plani/simdi",
    jsonFetcher,
    { refreshInterval: 60_000 },
  );

  // ANLIK SAAT CIZGISI: dakikada bir yeter — saniyede bir yenilemek
  // pil ve cizim maliyeti uretir, cizgi bir piksel bile oynamaz.
  const [simdi, setSimdi] = useState(() => new Date());
  useEffect(() => {
    const s = setInterval(() => setSimdi(new Date()), 60_000);
    return () => clearInterval(s);
  }, []);

  const bugun = isoGun(simdi);
  const suzulmus = useMemo(() => {
    const ara = aramaSuzgeci.trim().toLocaleLowerCase("tr");
    return (data?.personel ?? []).filter(
      (k) =>
        (!rolSuzgeci || k.rol === rolSuzgeci) &&
        (!ara || k.ad.toLocaleLowerCase("tr").includes(ara)),
    );
  }, [data, rolSuzgeci, aramaSuzgeci]);
  const suzgecSayisi = (rolSuzgeci ? 1 : 0) + (aramaSuzgeci.trim() ? 1 : 0);

  const genislik =
    gorunum === "ay" ? gun * PX_GUN_AY : gun * 24 * PX_SAAT[gorunum];

  /** "Simdi" cizgisinin soldan uzakligi — gorunum disindaysa null. */
  const simdiSol = useMemo(() => {
    const fark = gunFarki(baslangic, bugun);
    if (fark < 0 || fark >= gun) return null;
    if (gorunum === "ay") return fark * PX_GUN_AY;
    const saat = fark * 24 + simdi.getHours() + simdi.getMinutes() / 60;
    return saat * PX_SAAT[gorunum];
  }, [baslangic, bugun, gun, gorunum, simdi]);

  function gunDegistir(g: string) {
    setSeciliGunler((s2) => {
      const y = new Set(s2);
      if (y.has(g)) {
        y.delete(g);
      } else {
        y.add(g);
      }
      return y;
    });
  }

  /** Suruklerken: iki gun ARASINDAKI her gunu secer (kaldirmaz). */
  function araligiSec(a: string, b: string) {
    const [ilk, son] = gunFarki(a, b) >= 0 ? [a, b] : [b, a];
    const adet = gunFarki(ilk, son);
    setSeciliGunler((s2) => {
      const y = new Set(s2);
      for (let i = 0; i <= adet; i++) y.add(gunEkle(ilk, i));
      return y;
    });
  }

  /** "Tum pazartesiler" gibi kalip secimi: 0=pazar ... 1=pazartesi. */
  function haftaGunuSec(haftaGunu: number) {
    setSeciliGunler((s2) => {
      const y = new Set(s2);
      for (let i = 0; i < gun; i++) {
        const g = gunEkle(baslangic, i);
        if (new Date(`${g}T00:00:00`).getDay() === haftaGunu) y.add(g);
      }
      return y;
    });
  }

  async function calistir(is: AsyncIs) {
    setBekliyor(true);
    setHata(null);
    try {
      await is();
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  return (
    <div className="space-y-4">
      {/* ------------------------- 2.1 ANA EKRAN ------------------------- */}
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("vardiyaPlaniBaslik")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("vardiyaCizelgeAlt")}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Dugme
            type="button"
            boy="kucuk"
            tur="ikincil"
            data-test="vardiya-geri"
            onClick={() => setBaslangic((b) => gunEkle(b, -gun))}
          >
            {t("vardiyaGeri")}
          </Dugme>
          <Dugme
            type="button"
            boy="kucuk"
            tur="ikincil"
            data-test="vardiya-bugun"
            onClick={() => setBaslangic(isoGun(new Date()))}
          >
            {t("vardiyaBugun")}
          </Dugme>
          <span
            className="tabular-nums"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            data-test="vardiya-aralik"
          >
            {gun === 1 ? baslangic : `${baslangic} — ${gunEkle(baslangic, gun - 1)}`}
          </span>
          <Dugme
            type="button"
            boy="kucuk"
            tur="ikincil"
            data-test="vardiya-ileri"
            onClick={() => setBaslangic((b) => gunEkle(b, gun))}
          >
            {t("vardiyaIleri")}
          </Dugme>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {/* GORUNUM SECICI — uc dugme, secili olan ISARETLI. */}
        <div className="flex gap-1" role="group" aria-label={t("vardiyaGorunum")}>
          {GORUNUMLER.map((g) => (
            <Dugme
              key={g}
              type="button"
              boy="kucuk"
              tur={gorunum === g ? BIRINCIL : IKINCIL}
              aria-pressed={gorunum === g}
              data-test={`vardiya-gorunum-${g}`}
              onClick={() => setGorunum(g)}
            >
              {t(GORUNUM_ANAHTARI[g])}
            </Dugme>
          ))}
        </div>
        <Dugme
          type="button"
          boy="kucuk"
          tur="ikincil"
          data-test="vardiya-filtreler"
          onClick={() => setFiltrelerAcik((a) => !a)}
        >
          {t("vardiyaFiltreler", { n: suzgecSayisi })}
        </Dugme>
        <Dugme
          type="button"
          boy="kucuk"
          data-test="vardiya-yeni"
          onClick={() => setEkleAcik(true)}
        >
          {t("vardiyaYeni")}
        </Dugme>
        <Dugme
          type="button"
          boy="kucuk"
          tur="ikincil"
          disabled={bekliyor || isLoading}
          data-test="vardiya-tazele"
          onClick={() => void mutate()}
        >
          {t("vardiyaTazele")}
        </Dugme>
      </div>

      {/* (P207 §1) SECIM ARAC CUBUGU — yalniz AY gorunumunde.
          Gun/hafta gorunumunde bir avuc gun vardir ve toplu planlama
          orada anlamli degil; cubugu her gorunumde cizmek, ekrani
          kullanilmayan bir araca ayirmak olurdu. */}
      {gorunum === "ay" && (
        <div className="flex flex-wrap items-center gap-2" data-test="vardiya-secim-araclari">
          {HAFTA_GUNLERI.map((h) => (
            <Dugme
              key={h.gun}
              type="button"
              boy="kucuk"
              tur={IKINCIL}
              data-test={`vardiya-hafta-gunu-${h.gun}`}
              onClick={() => haftaGunuSec(h.gun)}
            >
              {t(h.anahtar)}
            </Dugme>
          ))}
          <Dugme
            type="button"
            boy="kucuk"
            tur={IKINCIL}
            data-test="vardiya-secimi-temizle"
            onClick={() => setSeciliGunler(new Set())}
          >
            {t("vardiyaSecimiTemizle")}
          </Dugme>
          <span
            data-test="vardiya-secim-sayisi"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("vardiyaSeciliGun", { n: seciliGunler.size })}
          </span>
          <Dugme
            type="button"
            boy="kucuk"
            disabled={seciliGunler.size === 0}
            data-test="vardiya-kalip-ac"
            onClick={() => setKalipAcik(true)}
          >
            {t("vardiyaKalipUygula")}
          </Dugme>
          {/* GERI ALMA: son toplu islem varken gorunur. Otuz gunluk
              yanlis plani tek tek silmek zorunda kalmamak, istegin
              KRITIK sarti. */}
          {sonParti && (
            <Dugme
              type="button"
              boy="kucuk"
              tur="tehlike"
              disabled={bekliyor}
              data-test="vardiya-parti-geri-al"
              onClick={() =>
                void calistir(async () => {
                  const y = (await apiSend(
                    `/api/vardiya-plani/parti/${sonParti}/geri-al`,
                    "POST",
                    {},
                  )) as { iptal_edilen?: number };
                  toast.success(
                    t("vardiyaPartiGeriAlindi", { n: y?.iptal_edilen ?? 0 }),
                  );
                  setSonParti(null);
                })
              }
            >
              {t("vardiyaSonIslemiGeriAl")}
            </Dugme>
          )}
        </div>
      )}

      {filtrelerAcik && (
        <Kart>
          <div className="flex flex-wrap items-end gap-3" data-test="vardiya-suzgecler">
            <AlanSarmal etiket={t("vardiyaSuzgecRol")}>
              {(baglar) => (
                <Secim
                  {...baglar}
                  value={rolSuzgeci}
                  data-test="vardiya-suzgec-rol"
                  onChange={(e) => setRolSuzgeci(e.target.value)}
                >
                  <option value="">{t("ortakTumu")}</option>
                  {["security", "guvenlik_amiri", "tesis_gorevlisi", "yonetici"].map(
                    (r) => (
                      <option key={r} value={r}>
                        {rolAdi(t, r)}
                      </option>
                    ),
                  )}
                </Secim>
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("vardiyaSuzgecKisi")}>
              {(baglar) => (
                <Alan
                  {...baglar}
                  value={aramaSuzgeci}
                  data-test="vardiya-suzgec-kisi"
                  onChange={(e) => setAramaSuzgeci(e.target.value)}
                />
              )}
            </AlanSarmal>
          </div>
        </Kart>
      )}

      <HataDurumu mesaj={hata ?? (error ? t("ortakHataOlustu") : null)} />

      {/* ------------------ (P203 §4.2) ANLIK DURUM ---------------------- */}
      <Kart>
        <div className="grid gap-4 sm:grid-cols-2">
          <div data-test="vardiya-simdi-gorevde">
            <p className="text-sm font-medium text-metin-body">
              {t("vardiyaSuAnGorevde")}
            </p>
            {simdiDurum?.gorevdeki_vardiya ? (
              <>
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                  {simdiDurum.gorevdeki_vardiya.shift_ad}{" "}
                  {simdiDurum.gorevdeki_vardiya.baslangic_saat.slice(0, 5)}–
                  {simdiDurum.gorevdeki_vardiya.bitis_saat.slice(0, 5)}
                </p>
                <p className="mt-1 text-sm text-metin-body">
                  {simdiDurum.gorevdekiler.map((k) => k.ad).join(", ")}
                </p>
              </>
            ) : (
              <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
                {t("vardiyaSuAnKimseYok")}
              </p>
            )}
          </div>
          <div data-test="vardiya-simdi-sonraki">
            <p className="text-sm font-medium text-metin-body">
              {t("vardiyaSiradaki")}
            </p>
            {simdiDurum?.sonraki_vardiya ? (
              <>
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                  {simdiDurum.sonraki_vardiya.shift_ad}{" "}
                  {simdiDurum.sonraki_vardiya.baslangic_saat.slice(0, 5)}–
                  {simdiDurum.sonraki_vardiya.bitis_saat.slice(0, 5)}
                </p>
                <p className="mt-1 text-sm text-metin-body">
                  {simdiDurum.sonrakiler.map((k) => k.ad).join(", ")}
                </p>
              </>
            ) : (
              <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}>
                {t("vardiyaSiradakiYok")}
              </p>
            )}
          </div>
        </div>
        {/* (P203) HAFTAYI KADRODAN DOLDUR KORUNDU: varsayilan kadro
            olmadan yirmi kisilik ekip her hafta tek tek atanirdi. */}
        <div className="mt-3">
          <Dugme
            type="button"
            boy="kucuk"
            tur="ikincil"
            disabled={bekliyor}
            data-test="vardiya-haftayi-doldur"
            onClick={() =>
              void calistir(async () => {
                await apiSend(
                  `/api/vardiya-plani/haftayi-doldur?baslangic=${baslangic}&gun=${gun}`,
                  "POST",
                  {},
                );
                toast.success(t("vardiyaDolduruldu"));
              })
            }
          >
            {t("vardiyaHaftayiDoldur")}
          </Dugme>
        </div>
      </Kart>

      {/* ------------------------- ZAMAN CIZELGESI ------------------------ */}
      {/* (P138) ELLE `<table>` YAZILMAZ. Bu zaten bir veri tablosu
          DEGIL: hucreler saat eksenine gore KONUMLANIR, sutunlara
          bolunmez. `VeriTablosu`ya sokmak kolon uydurmak olurdu. */}
      <Kart>
        <div className="flex">
          {/* SOL SUTUN SABIT: yatay kaydirmada isim kaybolursa hangi
              satira baktigin anlasilmaz. */}
          <div className="w-40 shrink-0">
            <div
              className="h-8 border-b"
              style={{ borderColor: "var(--yz-border)" }}
            />
            {suzulmus.map((k) => (
              <div
                key={k.user_id}
                className="flex h-14 items-center gap-2 border-b pe-2"
                style={{ borderColor: "var(--yz-border)" }}
                data-test={`vardiya-satir-${k.user_id}`}
              >
                {/* AVATAR: ad-soyad bas harfleri. Fotograf yuklemesi
                    personelde yok; harf, satiri gozle taramayi
                    hizlandirir. */}
                <span
                  aria-hidden="true"
                  className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full"
                  style={{
                    background: "var(--yz-surface-2)",
                    fontSize: "var(--yz-fs-xs)",
                    color: "var(--yz-text-2)",
                  }}
                >
                  {k.ad.slice(0, 1).toLocaleUpperCase("tr")}
                </span>
                <span className="min-w-0">
                  <span
                    className="block truncate"
                    style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                  >
                    {k.ad}
                  </span>
                  <span
                    className="block truncate"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                  >
                    {rolAdi(t, k.rol)}
                  </span>
                </span>
              </div>
            ))}
          </div>

          {/* SAG TARAF YATAY KAYDIRIR. */}
          <div className="min-w-0 flex-1 overflow-x-auto" ref={seritRef}>
            <div className="relative" style={{ width: `${genislik}px` }}>
              {/* BASLIK: saatler ya da gunler. */}
              <div
                className="flex h-8 border-b"
                style={{ borderColor: "var(--yz-border)" }}
                data-test="vardiya-eksen"
              >
                {gorunum === "ay"
                  ? Array.from({ length: gun }, (_, i) => gunEkle(baslangic, i)).map(
                      (g) => (
                        // (P207 §1) GUN SECIMI: tiklamak secer/kaldirir,
                        // basili tutup gezmek ARALIK secer. Secim GORSEL
                        // OLARAK BELIRGIN (dolgu + kenarlik): silik bir
                        // isaret, otuz sutunluk bir seritte goz
                        // taramasiyla bulunamazdi.
                        <button
                          key={g}
                          type="button"
                          data-test={`vardiya-gun-sec-${g}`}
                          aria-pressed={seciliGunler.has(g)}
                          className="odak-ic shrink-0 tabular-nums"
                          style={{
                            width: `${PX_GUN_AY}px`,
                            fontSize: "var(--yz-fs-xs)",
                            color: seciliGunler.has(g)
                              ? "var(--yz-text)"
                              : "var(--yz-text-3)",
                            background: seciliGunler.has(g)
                              ? "var(--yz-surface-2)"
                              : SEFFAF,
                            borderInlineStart: seciliGunler.has(g)
                              ? "var(--yz-border-w) solid var(--yz-accent-edge)"
                              : undefined,
                          }}
                          onMouseDown={() => {
                            setSurukleBas(g);
                            gunDegistir(g);
                          }}
                          onMouseEnter={() => {
                            if (surukleBas) araligiSec(surukleBas, g);
                          }}
                          onMouseUp={() => setSurukleBas(null)}
                          onClick={(e) => {
                            // Dokunmatik/klavye: `mousedown` gelmeyen
                            // yollarda tiklama tek basina calismali.
                            if (e.detail === 0) gunDegistir(g);
                          }}
                        >
                          {g.slice(8)}
                        </button>
                      ),
                    )
                  : Array.from({ length: gun }, (_, g) => g).flatMap((g) =>
                      SAATLER.map((s) => (
                        <span
                          key={`${g}-${s}`}
                          className="shrink-0 tabular-nums"
                          style={{
                            width: `${PX_SAAT[gorunum]}px`,
                            fontSize: "var(--yz-fs-xs)",
                            color: "var(--yz-text-3)",
                          }}
                        >
                          {/* HAFTADA yalniz 0/6/12/18: 12 px'e
                              "13:00" sigmaz ve ust uste binen etiket
                              hicbir seyi okunur yapmaz. */}
                          {gorunum === "gun"
                            ? `${String(s).padStart(2, "0")}:00`
                            : s % 6 === 0
                              ? String(s).padStart(2, "0")
                              : ""}
                        </span>
                      )),
                    )}
              </div>

              {/* SIMDI CIZGISI — yalniz gorunum bugunu kapsiyorsa. */}
              {simdiSol !== null && (
                <div
                  aria-hidden="true"
                  data-test="vardiya-simdi-cizgisi"
                  className="pointer-events-none absolute top-0 bottom-0 w-px"
                  style={{ left: `${simdiSol}px`, background: "var(--yz-danger-edge)" }}
                />
              )}

              {suzulmus.map((k) => (
                <div
                  key={k.user_id}
                  className="relative h-14 border-b"
                  style={{ borderColor: "var(--yz-border)" }}
                >
                  {k.bloklar.map((b) => {
                    const bas = Math.max(0, saatOfseti(baslangic, b.baslar));
                    const son = Math.min(gun * 24, saatOfseti(baslangic, b.biter));
                    if (son <= 0 || bas >= gun * 24) return null;
                    const sol =
                      gorunum === "ay"
                        ? (bas / 24) * PX_GUN_AY
                        : bas * PX_SAAT[gorunum];
                    const en =
                      gorunum === "ay"
                        ? Math.max(PX_GUN_AY - 4, ((son - bas) / 24) * PX_GUN_AY)
                        : Math.max(8, (son - bas) * PX_SAAT[gorunum]);
                    return (
                      <button
                        key={b.plan_id}
                        type="button"
                        data-test={`vardiya-blok-${b.plan_id}`}
                        onClick={() => setSecili({ kisi: k, blok: b })}
                        className="odak-ic absolute top-2 h-10 overflow-hidden rounded-md border px-1 text-start"
                        style={{
                          left: `${sol}px`,
                          width: `${en}px`,
                          borderColor: "var(--yz-accent-edge)",
                          background: "var(--yz-surface-2)",
                          borderWidth: "var(--yz-border-w)",
                        }}
                        title={`${ss(b.baslar)}–${ss(b.biter)}`}
                      >
                        <span
                          className="block truncate tabular-nums"
                          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text)" }}
                        >
                          {ss(b.baslar)}–{ss(b.biter)}
                        </span>
                        {b.shift_ad && (
                          <span
                            className="block truncate"
                            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                          >
                            {b.shift_ad}
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              ))}
            </div>
          </div>
        </div>

        {suzulmus.length === 0 && (
          <p
            className="pt-2"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-3)" }}
            data-test="vardiya-bos-liste"
          >
            {t("vardiyaKisiYok")}
          </p>
        )}
      </Kart>

      {/* --------------------- 2.3 BLOK AYRINTISI ------------------------ */}
      {secili && (
        <BlokAyrinti
          kisi={secili.kisi}
          blok={secili.blok}
          bekliyor={bekliyor}
          onKapat={() => setSecili(null)}
          onKaydet={(govde) =>
            void calistir(async () => {
              await apiSend(
                `/api/vardiya-plani/${secili.blok.plan_id}`,
                "PATCH",
                govde,
              );
              toast.success(t("vardiyaGuncellendi"));
              setSecili(null);
            })
          }
          onSil={(sebep) =>
            void calistir(async () => {
              const qs = sebep ? `?not_metni=${encodeURIComponent(sebep)}` : "";
              await apiSend(`/api/vardiya-plani/${secili.blok.plan_id}${qs}`, "DELETE");
              toast.success(t("vardiyaCikarildi"));
              setSecili(null);
            })
          }
        />
      )}

      {/* ---------------- (P207 §1) KALIP UYGULA ------------------------ */}
      <KalipModali
        acik={kalipAcik}
        gunler={Array.from(seciliGunler).sort()}
        personel={(personel?.items ?? []).filter((p) => p.role !== "resident")}
        onKapat={() => setKalipAcik(false)}
        onUygulandi={(partiId) => {
          setSonParti(partiId);
          setKalipAcik(false);
          setSeciliGunler(new Set());
          void mutate();
        }}
      />

      {/* --------------------- 2.2 HIZLI VARDIYA EKLE -------------------- */}
      <HizliEkle
        acik={ekleAcik}
        personel={(personel?.items ?? []).filter((p) => p.role !== "resident")}
        varsayilanTarih={baslangic}
        onKapat={() => setEkleAcik(false)}
        onBitti={() => {
          setEkleAcik(false);
          void mutate();
        }}
      />
    </div>
  );
}

/** (§2.3) Blok ayrintisi — saat/gun degistir, cikar. */
function BlokAyrinti({
  kisi,
  blok,
  bekliyor,
  onKapat,
  onKaydet,
  onSil,
}: {
  kisi: CizelgeKisi;
  blok: Blok;
  bekliyor: boolean;
  onKapat: () => void;
  onKaydet: (govde: Record<string, string>) => void;
  onSil: (sebep: string) => void;
}) {
  const t = useT();
  const [tarih, setTarih] = useState(blok.tarih);
  const [bas, setBas] = useState(ss(blok.baslar));
  const [son, setSon] = useState(ss(blok.biter));
  const [sebep, setSebep] = useState("");

  return (
    <Kart>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm font-medium text-metin-body" data-test="vardiya-ayrinti">
          {kisi.ad} · {blok.tarih} {ss(blok.baslar)}–{ss(blok.biter)}
          {blok.gece_asiyor ? ` · ${t("vardiyaGeceAsiyor")}` : ""}
        </p>
        <Dugme type="button" boy="kucuk" tur="ikincil" onClick={onKapat}>
          {t("ortakKapat")}
        </Dugme>
      </div>

      <div className="mt-3 flex flex-wrap items-end gap-2">
        <AlanSarmal etiket={t("vardiyaTarih")}>
          {(baglar) => (
            <Alan
              {...baglar}
              type="date"
              value={tarih}
              data-test="vardiya-ayrinti-tarih"
              onChange={(e) => setTarih(e.target.value)}
            />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("vardiyaBaslangicSaati")}>
          {(baglar) => (
            <Alan
              {...baglar}
              type="time"
              value={bas}
              data-test="vardiya-ayrinti-bas"
              onChange={(e) => setBas(e.target.value)}
            />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("vardiyaBitisSaati")}>
          {(baglar) => (
            <Alan
              {...baglar}
              type="time"
              value={son}
              data-test="vardiya-ayrinti-son"
              onChange={(e) => setSon(e.target.value)}
            />
          )}
        </AlanSarmal>
        <Dugme
          type="button"
          boy="kucuk"
          disabled={bekliyor}
          data-test="vardiya-ayrinti-kaydet"
          onClick={() =>
            onKaydet({ tarih, baslangic_saat: bas, bitis_saat: son })
          }
        >
          {t("ortakKaydet")}
        </Dugme>
      </div>

      <div className="mt-3 flex flex-wrap items-end gap-2">
        {/* SEBEP ALANI: gun ici degisiklik denetime yaziliyor ve "neden"
            bos kalirsa kayit sonradan hicbir soruyu yanitlamaz. */}
        <AlanSarmal etiket={t("vardiyaCikarSebep")}>
          {(baglar) => (
            <Alan
              {...baglar}
              value={sebep}
              data-test="vardiya-cikar-sebep"
              onChange={(e) => setSebep(e.target.value)}
            />
          )}
        </AlanSarmal>
        <Dugme
          type="button"
          boy="kucuk"
          tur="tehlike"
          disabled={bekliyor}
          data-test="vardiya-cikar"
          onClick={() => onSil(sebep)}
        >
          {t("vardiyaCikar")}
        </Dugme>
      </div>
    </Kart>
  );
}

/**
 * (§2.2) HIZLI VARDIYA EKLE.
 *
 * CAKISAN GUNLER SESSIZCE ATLANMAZ: sunucu once `uygulandi=false` ve
 * cakisan gunlerin listesiyle doner; kullanici "cakisanlar haric ekle"
 * ya da "iptal" der. Kullaniciya "bir yerde cakisma var" deyip onu tek
 * tek aramaya gondermek, ekledigini sandigi gunlerin eksik oldugunu
 * sahada fark etmesi demekti.
 */
function HizliEkle({
  acik,
  personel,
  varsayilanTarih,
  onKapat,
  onBitti,
}: {
  acik: boolean;
  personel: Personel[];
  varsayilanTarih: string;
  onKapat: () => void;
  onBitti: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const [userId, setUserId] = useState("");
  const [ara, setAra] = useState("");
  const [basTarih, setBasTarih] = useState(varsayilanTarih);
  const [sonTarih, setSonTarih] = useState(varsayilanTarih);
  const [basSaat, setBasSaat] = useState("08:00");
  const [sonSaat, setSonSaat] = useState("16:00");
  const [not, setNot] = useState("");
  const [cakisanlar, setCakisanlar] = useState<string[] | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  const secenekler = useMemo(() => {
    const a = ara.trim().toLocaleLowerCase("tr");
    return a
      ? personel.filter((p) => p.ad.toLocaleLowerCase("tr").includes(a))
      : personel;
  }, [personel, ara]);

  async function gonder(atla: boolean) {
    setBekliyor(true);
    setHata(null);
    try {
      const y = (await apiSend("/api/vardiya-plani/toplu", "POST", {
        user_id: userId,
        baslangic_tarih: basTarih,
        bitis_tarih: sonTarih,
        baslangic_saat: basSaat,
        bitis_saat: sonSaat,
        not_metni: not || null,
        cakisanlari_atla: atla,
      })) as TopluSonuc;
      if (!y.uygulandi) {
        // KARAR KULLANICININ: hangi gunlerde cakisma oldugunu GORUR.
        setCakisanlar(
          y.gunler.filter((g) => g.durum === "cakisma").map((g) => g.tarih),
        );
        return;
      }
      for (const u of y.uyarilar ?? []) {
        toast.info(
          u === "gunluk_sinir_asildi"
            ? t("vardiyaUyariGunluk")
            : t("vardiyaUyariHaftalik"),
        );
      }
      toast.success(t("vardiyaEklendiSayi", { n: y.eklenen }));
      setCakisanlar(null);
      onBitti();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  return (
    <Modal
      acik={acik}
      onKapat={onKapat}
      baslik={t("vardiyaYeni")}
      eylemler={
        <>
          <Dugme type="button" tur="ikincil" onClick={onKapat}>
            {t("ortakIptal")}
          </Dugme>
          <Dugme
            type="button"
            disabled={!userId || bekliyor}
            data-test="vardiya-ekle-gonder"
            onClick={() => void gonder(false)}
          >
            {t("vardiyaEkleGonder")}
          </Dugme>
        </>
      }
    >
      <div className="space-y-3">
        <HataDurumu mesaj={hata} />

        <AlanSarmal etiket={t("vardiyaSuzgecKisi")}>
          {(baglar) => (
            <Alan
              {...baglar}
              value={ara}
              data-test="vardiya-ekle-ara"
              onChange={(e) => setAra(e.target.value)}
            />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("vardiyaPersonel")}>
          {(baglar) => (
            <Secim
              {...baglar}
              value={userId}
              data-test="vardiya-ekle-kisi"
              onChange={(e) => setUserId(e.target.value)}
            >
              <option value="">{t("ortakSeciniz")}</option>
              {secenekler.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.ad}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>

        <div className="flex flex-wrap gap-2">
          <AlanSarmal etiket={t("vardiyaBaslangicTarihi")}>
            {(baglar) => (
              <Alan
                {...baglar}
                type="date"
                value={basTarih}
                data-test="vardiya-ekle-bas-tarih"
                onChange={(e) => setBasTarih(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("vardiyaBitisTarihi")}>
            {(baglar) => (
              <Alan
                {...baglar}
                type="date"
                value={sonTarih}
                data-test="vardiya-ekle-son-tarih"
                onChange={(e) => setSonTarih(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("vardiyaBaslangicSaati")}>
            {(baglar) => (
              <Alan
                {...baglar}
                type="time"
                value={basSaat}
                data-test="vardiya-ekle-bas-saat"
                onChange={(e) => setBasSaat(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("vardiyaBitisSaati")}>
            {(baglar) => (
              <Alan
                {...baglar}
                type="time"
                value={sonSaat}
                data-test="vardiya-ekle-son-saat"
                onChange={(e) => setSonSaat(e.target.value)}
              />
            )}
          </AlanSarmal>
        </div>

        <AlanSarmal etiket={t("vardiyaNot")}>
          {(baglar) => (
            <Alan
              {...baglar}
              value={not}
              data-test="vardiya-ekle-not"
              onChange={(e) => setNot(e.target.value)}
            />
          )}
        </AlanSarmal>

        {/* BILGI KUTUSU: iki davranis ONCEDEN soylenir — aralik HER GUN
            icin kayit acar ve bitis saati baslangictan kucukse vardiya
            ERTESI GUNE tasar. Bunlari denedikten sonra ogrenmek,
            yanlislikla 14 kayit acmak demekti. */}
        <p
          data-test="vardiya-ekle-bilgi"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
        >
          {t("vardiyaEkleBilgi")}
        </p>

        {cakisanlar && cakisanlar.length > 0 && (
          <div data-test="vardiya-cakisma-uyarisi">
            <Rozet durum="uyari">
              {t("vardiyaCakisanGunler", { n: cakisanlar.length })}
            </Rozet>
            <p
              className="mt-1 tabular-nums"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {cakisanlar.join(", ")}
            </p>
            <div className="mt-2 flex flex-wrap gap-2">
              <Dugme
                type="button"
                boy="kucuk"
                disabled={bekliyor}
                data-test="vardiya-cakisan-haric"
                onClick={() => void gonder(true)}
              >
                {t("vardiyaCakisanHaric")}
              </Dugme>
              <Dugme
                type="button"
                boy="kucuk"
                tur="ikincil"
                data-test="vardiya-cakisma-iptal"
                onClick={() => {
                  setCakisanlar(null);
                  onKapat();
                }}
              >
                {t("ortakIptal")}
              </Dugme>
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
}
