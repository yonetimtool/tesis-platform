"use client";

/**
 * (P235 §1) VARDIYA EKLEME — TEK MODAL, MOBILDEKI AKIS.
 *
 * =========================================================================
 * OLCULEN KUSUR: WEB'DE IKI AYRI EKRAN
 * =========================================================================
 * Vardiya planı sayfasında IKI giris vardi ve FARKLI seyler aciyorlardi:
 *
 *   * ustteki "Vardiya ekle" -> `page.tsx` icindeki modal: kisi ->
 *     BASLANGIC/BITIS TARIHI -> saatler -> not. TAKVIM YOK, COK GRUP YOK.
 *   * alttaki "Kalip uygula" -> `kalip-modali.tsx`: takvimden gun SECILMIS
 *     OLMALI; kalip dilimleri + dilim basina personel + rotasyon.
 *
 * Mobilde ise TEK akis var (`_HizliEkleDialogu`): takvim -> kisi/saat ->
 * gruba ekle -> onizleme. Yani ayni isin uc farkli hali vardi ve
 * kullanici hangisinin "gercek" oldugunu bilmiyordu.
 *
 * =========================================================================
 * NEDEN MOBILIN AKISI KAZANDI
 * =========================================================================
 * Cunku TAKVIM ONCE geliyor. Vardiya planlamak gun secmekle baslar;
 * "baslangic-bitis tarihi" alani duzensiz secimi (pazartesi + persembe)
 * ANLATAMIYOR — sunucu semasi bunu P207'de zaten kabul etmisti
 * (`gunler: list[date]`, aralik DEGIL). Web'in ust modali o gercege
 * ragmen aralik soruyordu.
 *
 * =========================================================================
 * KALIP VE ROTASYON KAYBOLMADI — BILINCLI
 * =========================================================================
 * `kalip-modali.tsx` SILINDI ama iki yetenegi buraya TASINDI:
 *   * KAYITLI KALIP (gun icinde birden cok dilim, orn. gunduz+gece),
 *   * ROTASYON (haftalik kaydirma).
 * Bunlari atmak "birlestirme" degil OZELLIK SILME olurdu; istek
 * ekranlarin birlesmesiydi, yeteneklerin azalmasi degil.
 *
 * MOBILDE ROTASYON YOK ve bu ONCEDEN VAR OLAN bir bosluk (bu tur
 * uretmedi) — teslimde acikca yaziliyor.
 */
import { useEffect, useMemo, useRef, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Modal,
  Rozet,
  Secim,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/** JSX ucluda sabit metin yazilamaz (`sabit-metin` taramasi). */
const IKINCIL = "ikincil" as const;
const ROTASYON_YOK = "yok" as const;
const ROTASYON_HAFTALIK = "haftalik" as const;
/** "Kayitli kalip degil, serbest saat" secimi. */
const SERBEST = "" as const;

type Dilim = { ad: string; baslangic: string; bitis: string };
type Kalip = { id: string; ad: string; dilimler: Dilim[]; aktif: boolean };
type Personel = { id: string; ad: string; role: string };
type Grup = {
  gunler: string[];
  dilimler: Dilim[];
  atamalar: Record<number, string[]>;
};
type Satir = {
  tarih: string;
  dilim: string;
  baslangic: string;
  bitis: string;
  user_id: string;
  ad: string | null;
  durum: string;
};
type Sonuc = {
  uygulandi: boolean;
  parti_id: string | null;
  eklenecek: number;
  eklenen: number;
  /** ADET (sunucu semasi: `cakisan: int`). Satirlarin kendisi `satirlar`da. */
  cakisan: number;
  satirlar: Satir[];
};

function gunEkle(iso: string, n: number): string {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function VardiyaEkleModali({
  acik,
  onKapat,
  onBitti,
  onParti,
  baslangicAyi,
  onSecilenGunler,
  personel,
}: {
  acik: boolean;
  onKapat: () => void;
  onBitti: () => void;
  /** (P235 §1) Olusan PARTI kimligi — sayfadaki "geri al" dugmesi buna
   *  bagli. Birlestirmede bu geri cagriyi dusurmustum ve dugme HIC
   *  cikmiyordu; test yakaladi. Otuz gunluk yanlis plani tek tek silmek
   *  istegin KRITIK sartiydi. */
  onParti?: (partiId: string | null) => void;
  /** Sayfanin ZATEN cektigi personel listesi — ikinci bir istek acmayiz. */
  personel: Personel[];
  /** Takvimin acilacagi ay (sayfadaki gorunumle ayni yer). */
  baslangicAyi: string;
  /** Sayfadaki seritten gelen on-secim; bos olabilir. */
  onSecilenGunler: string[];
}) {
  const t = useT();
  const toast = useToast();

  // KALIPLAR BURADAN CEKILIYOR (sayfadan gecirilmiyor): yalnizca bu
  // modal kullaniyor ve `acik` degilken istek atilmiyor.
  const { data: kaliplar } = useSWR<{ items: Kalip[] }>(
    acik ? "/api/vardiya-plani/kaliplar" : null,
    jsonFetcher,
  );

  const [seciliGunler, setSeciliGunler] = useState<Set<string>>(new Set());

  // (P235 §1) SERIT SECIMI MODAL ACILIRKEN AKTARILIR.
  //
  // OLCULEN KUSUR: baslangic degerini `useState(() => new Set(prop))` ile
  // vermistim. Modal sayfada HEP MONTELI duruyor (`acik` bir prop) —
  // yani o baslatici YALNIZ BIR KEZ, modal KAPALIYKEN ve prop BOSKEN
  // calisiyordu. Sonuc: kullanici cizelgede gunleri isaretleyip "Kalip
  // uygula"ya basinca modal BOS aciliyordu. Test yakaladi.
  //
  // `acik` KENARINDA calisir, her cizimde DEGIL: aksi halde kullanicinin
  // modal icinde yaptigi secim her render'da geri alinirdi.
  const oncekiAcik = useRef(false);
  useEffect(() => {
    if (acik && !oncekiAcik.current) {
      setSeciliGunler(new Set(onSecilenGunler));
      setSonuc(null);
      setCakisanGunler(null);
    }
    oncekiAcik.current = acik;
  }, [acik, onSecilenGunler]);
  const [kalipId, setKalipId] = useState<string>(SERBEST);
  const [userId, setUserId] = useState("");
  // (P235 §1) ARALIK KIPI — mobildeki fallback'in AYNISI.
  //
  // Takvim BOSKEN bas/son tarih kullanilir ve istek `/toplu`ya gider.
  // Iki kipi ayni modalda tutmak mobilde bilincli bir karardi ("ayri bir
  // toplu ekle ekrani, cakisma akisini IKINCI KEZ yazmak demekti");
  // web'de de oyle.
  const [basTarih, setBasTarih] = useState(baslangicAyi);
  const [sonTarih, setSonTarih] = useState(baslangicAyi);
  const [basSaat, setBasSaat] = useState("08:00");
  const [sonSaat, setSonSaat] = useState("16:00");
  const [dilimAtama, setDilimAtama] = useState<Record<number, string>>({});
  const [not, setNot] = useState("");
  const [rotasyon, setRotasyon] = useState<string>(ROTASYON_YOK);
  const [gruplar, setGruplar] = useState<Grup[]>([]);
  const [sonuc, setSonuc] = useState<Sonuc | null>(null);
  const [cakisanGunler, setCakisanGunler] = useState<string[] | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [bekliyor, setBekliyor] = useState(false);

  const kalip = (kaliplar?.items ?? []).find((k) => k.id === kalipId);
  const dilimler: Dilim[] = kalip
    ? kalip.dilimler
    : [{ ad: `${basSaat}-${sonSaat}`, baslangic: basSaat, bitis: sonSaat }];

  /** Takvimde cizilecek gunler — secilen ayin tamami. */
  const ayGunleri = useMemo(() => {
    const ilk = `${baslangicAyi.slice(0, 7)}-01`;
    const d = new Date(`${ilk}T00:00:00Z`);
    const ay = d.getUTCMonth();
    const out: string[] = [];
    for (let i = 0; i < 31; i++) {
      const g = gunEkle(ilk, i);
      if (new Date(`${g}T00:00:00Z`).getUTCMonth() !== ay) break;
      out.push(g);
    }
    return out;
  }, [baslangicAyi]);

  function gunDegistir(g: string) {
    setSeciliGunler((s) => {
      const y = new Set(s);
      if (y.has(g)) y.delete(g);
      else y.add(g);
      return y;
    });
  }

  /** Ekranda kurulmakta olan grup. */
  function buGrup(): Grup | null {
    if (seciliGunler.size === 0) return null;
    const atamalar: Record<number, string[]> = {};
    if (kalip) {
      dilimler.forEach((_, i) => {
        const u = dilimAtama[i];
        if (u) atamalar[i] = [u];
      });
      if (Object.keys(atamalar).length === 0) return null;
    } else {
      if (!userId) return null;
      atamalar[0] = [userId];
    }
    return {
      gunler: Array.from(seciliGunler).sort(),
      dilimler,
      atamalar,
    };
  }

  function grubaEkle() {
    const g = buGrup();
    if (!g) return;
    setGruplar((l) => [...l, g]);
    // Sonraki grup BOS baslar: yoksa kullanici ayni gunleri ikinci gruba
    // da yazar ve kendi kendine cakisma uretirdi (mobildeki ayni not).
    setSeciliGunler(new Set());
    setSonuc(null);
  }

  /** (P235 §1) TEKIL KIP — mobildeki `_gonder`in AYNISI: `/toplu`.
   *
   * Grup YOKKEN ve kalip secilmemisken buraya duser. Aralik alanlari
   * (bas/son tarih) yalniz burada anlamli; takvimden gun secildiyse
   * `gunler` olarak gider ve aralik YOK SAYILIR — sunucu semasi ikisini
   * de kabul ediyor (`VardiyaTopluIstek.gunler`).
   */
  async function tekilGonder(atla: boolean) {
    if (!userId) return;
    setBekliyor(true);
    setHata(null);
    try {
      const y = (await apiSend("/api/vardiya-plani/toplu", "POST", {
        user_id: userId,
        baslangic: basTarih,
        bitis: sonTarih,
        baslangic_saat: basSaat,
        bitis_saat: sonSaat,
        not_metni: not || null,
        cakisanlari_atla: atla,
        gunler:
          seciliGunler.size > 0 ? Array.from(seciliGunler).sort() : null,
      })) as {
        uygulandi: boolean;
        eklenen: number;
        gunler?: { tarih: string; durum: string }[];
      };
      if (!y.uygulandi) {
        // KARAR KULLANICININ: HANGI GUNLERDE cakisma oldugunu GORUR.
        // "Bir yerde cakisma var" demek, kullaniciyi tek tek aramaya
        // gondermek olurdu. Sunucu TUM gunleri durumuyla doner; yalniz
        // `cakisma` olanlar yazilir.
        setCakisanGunler(
          (y.gunler ?? [])
            .filter((g) => g.durum === "cakisma")
            .map((g) => g.tarih),
        );
        return;
      }
      toast.success(t("vardiyaEklendiSayi", { n: y.eklenen }));
      onBitti();
      onKapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setBekliyor(false);
    }
  }

  async function gonder(kuru: boolean, atla: boolean) {
    // Ekranda kurulmakta olan grup da dahil: kullanicinin "gruba ekle"ye
    // basmayi unutmasi, son grubun SESSIZCE kaybolmasi demekti.
    const acik_ = buGrup();
    const hepsi = [...gruplar, ...(acik_ ? [acik_] : [])];
    if (hepsi.length === 0) return;
    setBekliyor(true);
    setHata(null);
    try {
      const y = (await apiSend("/api/vardiya-plani/kalip-uygula", "POST", {
        gruplar: hepsi,
        rotasyon,
        not_metni: not || null,
        kuru,
        cakisanlari_atla: atla,
      })) as Sonuc;
      setSonuc(y);
      if (!kuru && y.uygulandi) {
        toast.success(t("vardiyaKalipUygulandi", { n: y.eklenen }));
        onParti?.(y.parti_id);
        onBitti();
        onKapat();
      }
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setBekliyor(false);
    }
  }

  // MOBILDEKI KOSUL: grup varsa ya da ekranda kurulmus bir secim varsa
  // gonderilebilir. TEKIL KIPTE takvim bos olabilir (aralik kipi) —
  // orada yeterli sart KISININ secilmis olmasi.
  const gonderilebilir =
    gruplar.length > 0 || buGrup() !== null || (!kalip && Boolean(userId));

  return (
    <Modal
      acik={acik}
      onKapat={onKapat}
      baslik={t("vardiyaYeni")}
      eylemler={
        <>
          <Dugme type="button" tur={IKINCIL} onClick={onKapat}>
            {t("ortakIptal")}
          </Dugme>
          <Dugme
            type="button"
            tur={IKINCIL}
            disabled={!gonderilebilir || bekliyor}
            data-test="vardiya-onizle"
            onClick={() => void gonder(true, false)}
          >
            {t("vardiyaOnizle")}
          </Dugme>
          <Dugme
            type="button"
            disabled={!gonderilebilir || bekliyor}
            data-test="vardiya-ekle-gonder"
            // MOBILDEKI KOSULUN AYNISI: grup yoksa `/toplu` (tekil kip),
            // varsa `/kalip-uygula` (cok gruplu). Iki uc de yasiyor;
            // birini kapatmak yayindaki mobil surumleri kirardi.
            onClick={() =>
              void (gruplar.length === 0 && !kalip
                ? tekilGonder(false)
                : gonder(false, false))
            }
          >
            {t("vardiyaEkleGonder")}
          </Dugme>
        </>
      }
    >
      <div className="space-y-3">
        <HataDurumu mesaj={hata} />

        {/* 1) TAKVIM ONCE — mobildeki sira. Vardiya planlamak gun secmekle
            baslar; "baslangic-bitis tarihi" duzensiz secimi anlatamiyordu. */}
        <div>
          <p
            className="mb-1"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("vardiyaTakvimIpucu")}
          </p>
          <div
            className="flex flex-wrap gap-1"
            data-test="vardiya-ekle-takvim"
          >
            {ayGunleri.map((g) => (
              <button
                key={g}
                type="button"
                data-test={`vardiya-ekle-gun-${g}`}
                aria-pressed={seciliGunler.has(g)}
                className="odak-ic tabular-nums"
                style={{
                  minWidth: "2.25rem",
                  minHeight: "2.25rem",
                  fontSize: "var(--yz-fs-xs)",
                  borderRadius: "var(--yz-radius-sm)",
                  border: "var(--yz-border-w) solid var(--yz-border)",
                  color: seciliGunler.has(g)
                    ? "var(--yz-text)"
                    : "var(--yz-text-3)",
                  background: seciliGunler.has(g)
                    ? "var(--yz-surface-2)"
                    : undefined,
                }}
                onClick={() => gunDegistir(g)}
              >
                {Number(g.slice(8, 10))}
              </button>
            ))}
          </div>
          <div className="mt-1 flex items-center gap-2">
            <span
              data-test="vardiya-ekle-secili-sayi"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("vardiyaSeciliGun", { n: seciliGunler.size })}
            </span>
            <Dugme
              type="button"
              boy="kucuk"
              tur={IKINCIL}
              disabled={seciliGunler.size === 0}
              data-test="vardiya-ekle-secim-temizle"
              onClick={() => setSeciliGunler(new Set())}
            >
              {t("vardiyaSecimiTemizle")}
            </Dugme>
          </div>
        </div>

        {/* 2) KALIP — serbest saat ya da kayitli kalip.
            `kalip-modali.tsx`ten TASINDI: gun icinde birden cok dilim
            (gunduz+gece) yalniz orada yapilabiliyordu. */}
        <AlanSarmal etiket={t("vardiyaKalip")}>
          {(baglar) => (
            <Secim
              {...baglar}
              value={kalipId}
              data-test="vardiya-ekle-kalip"
              onChange={(e) => {
                setKalipId(e.target.value);
                setDilimAtama({});
              }}
            >
              <option value={SERBEST}>{t("vardiyaSerbestSaat")}</option>
              {(kaliplar?.items ?? [])
                .filter((k) => k.aktif)
                .map((k) => (
                  <option key={k.id} value={k.id}>
                    {k.ad}
                  </option>
                ))}
            </Secim>
          )}
        </AlanSarmal>

        {/* 3) KISI + SAAT (serbest) ya da DILIM BASINA KISI (kalip) */}
        {kalip ? (
          <div className="space-y-2" data-test="vardiya-ekle-dilimler">
            {dilimler.map((d, i) => (
              <AlanSarmal
                key={`${d.ad}-${i}`}
                etiket={`${d.ad} · ${d.baslangic}-${d.bitis}`}
              >
                {(baglar) => (
                  <Secim
                    {...baglar}
                    value={dilimAtama[i] ?? ""}
                    data-test={`vardiya-ekle-dilim-${i}`}
                    onChange={(e) =>
                      setDilimAtama((a) => ({ ...a, [i]: e.target.value }))
                    }
                  >
                    <option value="">{t("ortakSeciniz")}</option>
                    {personel.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.ad}
                      </option>
                    ))}
                  </Secim>
                )}
              </AlanSarmal>
            ))}
          </div>
        ) : (
          <div className="flex flex-wrap gap-2">
            <AlanSarmal etiket={t("vardiyaPersonel")}>
              {(baglar) => (
                <Secim
                  {...baglar}
                  value={userId}
                  data-test="vardiya-ekle-kisi"
                  onChange={(e) => setUserId(e.target.value)}
                >
                  <option value="">{t("ortakSeciniz")}</option>
                  {personel.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.ad}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
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
        )}

        {/* 4) COK GRUP (P232) — "pazartesi gunduz, sali-carsamba gece" */}
        <div className="flex flex-wrap items-center gap-2">
          <Dugme
            type="button"
            boy="kucuk"
            tur={IKINCIL}
            disabled={buGrup() === null}
            data-test="vardiya-ekle-gruba-ekle"
            onClick={grubaEkle}
          >
            {t("vardiyaGrubaEkle")}
          </Dugme>
          {gruplar.length > 0 && (
            <span
              data-test="vardiya-ekle-grup-sayisi"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {t("vardiyaGrupSayisi", { n: gruplar.length })}
            </span>
          )}
          {gruplar.length > 0 && (
            <Dugme
              type="button"
              boy="kucuk"
              tur={IKINCIL}
              data-test="vardiya-ekle-gruplari-temizle"
              onClick={() => setGruplar([])}
            >
              {t("vardiyaGruplariTemizle")}
            </Dugme>
          )}
        </div>

        <AlanSarmal etiket={t("vardiyaRotasyon")}>
          {(baglar) => (
            <Secim
              {...baglar}
              value={rotasyon}
              data-test="vardiya-ekle-rotasyon"
              onChange={(e) => setRotasyon(e.target.value)}
            >
              <option value={ROTASYON_YOK}>{t("vardiyaRotasyonYok")}</option>
              <option value={ROTASYON_HAFTALIK}>
                {t("vardiyaRotasyonHaftalik")}
              </option>
            </Secim>
          )}
        </AlanSarmal>

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

        <p
          data-test="vardiya-ekle-bilgi"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
        >
          {t("vardiyaEkleBilgi")}
        </p>

        {/* TEKIL KIPTE CAKISMA — gunler YAZILIR, karar kullanicinin. */}
        {cakisanGunler && cakisanGunler.length > 0 && (
          <div data-test="vardiya-cakisma-uyarisi">
            <Rozet durum="uyari">
              {t("vardiyaCakisanGunler", { n: cakisanGunler.length })}
            </Rozet>
            <p
              className="mt-1 tabular-nums"
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
            >
              {cakisanGunler.join(", ")}
            </p>
            <div className="mt-2 flex flex-wrap gap-2">
              <Dugme
                type="button"
                boy="kucuk"
                disabled={bekliyor}
                data-test="vardiya-cakisan-haric"
                onClick={() => void tekilGonder(true)}
              >
                {t("vardiyaCakisanHaric")}
              </Dugme>
              <Dugme
                type="button"
                boy="kucuk"
                tur={IKINCIL}
                data-test="vardiya-cakisma-iptal"
                onClick={() => {
                  setCakisanGunler(null);
                  onKapat();
                }}
              >
                {t("ortakIptal")}
              </Dugme>
            </div>
          </div>
        )}

        {/* 5) ONIZLEME + CAKISMA — `kalip-modali`daki akisin aynisi. */}
        {sonuc && (
          <div data-test="vardiya-ekle-onizleme" className="space-y-2">
            <Rozet durum={sonuc.cakisan > 0 ? "uyari" : "bilgi"}>
              {t("vardiyaKalipOnizleme", { n: sonuc.eklenecek })}
            </Rozet>
            {sonuc.cakisan > 0 && (
              <>
                {/* HANGI gun/dilim/KIM oldugu YAZILIR: "bir yerde cakisma
                    var" demek, kullaniciyi tek tek aramaya gondermekti
                    (P205 kurali). */}
                <p
                  className="tabular-nums"
                  style={{
                    fontSize: "var(--yz-fs-xs)",
                    color: "var(--yz-text-2)",
                  }}
                >
                  {(sonuc.satirlar ?? [])
                    .filter((c) => c.durum === "cakisma")
                    .map((c) => `${c.tarih} ${c.dilim} ${c.ad ?? ""}`.trim())
                    .join(", ")}
                </p>
                <Dugme
                  type="button"
                  boy="kucuk"
                  disabled={bekliyor}
                  data-test="vardiya-cakisan-haric"
                  onClick={() => void gonder(false, true)}
                >
                  {t("vardiyaCakisanHaric")}
                </Dugme>
              </>
            )}
          </div>
        )}
      </div>
    </Modal>
  );
}
