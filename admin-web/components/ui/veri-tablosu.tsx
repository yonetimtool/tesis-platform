"use client";

/**
 * (P160 / Asama 3) VERI TABLOSU.
 *
 * Brief: "siralama, filtreleme, arama, sayfalama, kolon gorunurlugu,
 * satir secimi, toplu islem, SAYFA BASINA KAYIT SECIMI (10/25/50/100),
 * toplam kayit, duyarli davranis. Duz HTML tablo gorunumu degil."
 *
 * =========================================================================
 * SUNUCU MU ISTEMCI MI SIRALAR/SAYFALAR — CAGIRAN KARAR VERIR
 * =========================================================================
 * Depodaki uclarin cogu ZATEN sunucu tarafinda sayfaliyor (`limit`/
 * `offset` + `meta.total`). Tablonun icine sabit bir istemci-tarafi
 * sayfalama gomseydik, 5000 kayitli bir listede tum veriyi cekmek
 * zorunda kalirdik.
 *
 * Bu yuzden iki kip var:
 *   * `sunucuTarafli={false}` (varsayilan) — tablo elindeki diziyi kendi
 *     siralar/sayfalar. Kucuk listeler icin en az kod.
 *   * `sunucuTarafli`         — tablo yalnizca DURUMU tasir ve
 *     `onDurumDegisti` ile cagirana bildirir; siralama/sayfalama ucta
 *     yapilir. `toplam` disaridan verilir.
 *
 * =========================================================================
 * ERISILEBILIRLIK — bu bilesenin en kolay bozulan yani
 * =========================================================================
 * * Gercek `<table>`/`<th>`/`<td>` kullanilir. `div` izgarasi gorsel
 *   olarak ayni durur ama ekran okuyucu satir/sutun iliskisini KAYBEDER.
 * * Siralanabilir baslik `aria-sort` tasir ve BIR DUGMEDIR (klavye).
 * * Satir secim kutularinin her birinin adi vardir; "tumunu sec"
 *   belirsiz secimde `indeterminate` olur.
 * * Kaydirilabilir kapsayici `tabindex=0` + `role=region`: klavye
 *   kullanicisi yatay kaydirabilmeli.
 */
import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";

import { siraGecikmesi } from "@/lib/hareket";
import { useT } from "@/lib/i18n/kullan";

import { Dugme } from "./dugme";
import { BosDurum, HataDurumu, IskeletTablo } from "./durumlar";
import { useBant } from "@/lib/kirilma-kullan";

import { Kart } from "./yuzey";

export const SAYFA_BOYLARI = [10, 25, 50, 100] as const;
export type SayfaBoyu = (typeof SAYFA_BOYLARI)[number];

export type SiraYonu = "artan" | "azalan";

export interface Kolon<T> {
  /** Kolon kimligi — siralama ve gorunurluk bunun uzerinden yurur. */
  id: string;
  /** Gorunen baslik. i18n'den gelmis olmali. */
  baslik: string;
  /** Hucre cizimi. */
  hucre: (satir: T) => ReactNode;
  /** Istemci-tarafi siralama icin karsilastirilabilir deger. */
  deger?: (satir: T) => string | number | null | undefined;
  /** Siralanabilir mi (varsayilan: `deger` verildiyse evet). */
  siralanabilir?: boolean;
  /** Kullanici bu kolonu gizleyebilir mi (varsayilan: evet). */
  gizlenebilir?: boolean;
  /** Dar ekranda gizlensin mi — duyarli davranis. */
  darEkrandaGizle?: boolean;
  /** Sayisal kolonlar saga yaslanir. */
  sayisal?: boolean;
  /**
   * (P169 §3.1) KART MODUNDA bu kolonun rolu.
   *
   *   `baslik`  — kartin ust satiri (kimlik: daire no, ad, dosya no)
   *   `ozet`    — baslik altinda etiketiyle gosterilen 2-3 alan
   *   `rozet`   — kartin sag ustundeki durum
   *   `eylem`   — kartin altindaki eylem seridi
   *   (verilmezse) — kartta GIZLENIR, "Detay"da gorunur
   *
   * NEDEN KOLON UZERINDE: kart tanimini ayri bir prop olarak almak, ayni
   * bilgiyi (hangi kolon neyi gosterir) IKI YERDE tutmak olurdu ve biri
   * degistiginde oteki unutulurdu.
   */
  kartRolu?: "baslik" | "ozet" | "rozet" | "eylem";
}

export interface TabloDurumu {
  sayfa: number;
  boy: SayfaBoyu;
  siraKolon: string | null;
  siraYonu: SiraYonu;
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`). `YON_ARTAN` asagida
// `BaslikHucresi` icin de kullaniliyor; tek tanim.
const YON_ARTAN = "artan" as const;
const YON_AZALAN = "azalan" as const;

const VARSAYILAN_DURUM: TabloDurumu = {
  sayfa: 1,
  boy: 25,
  siraKolon: null,
  siraYonu: "artan",
};

export interface VeriTablosuProps<T> {
  kolonlar: Kolon<T>[];
  satirlar: T[];
  /** Her satirin kararli kimligi — secim ve `key` bunun uzerinden. */
  satirId: (satir: T) => string;

  yukleniyor?: boolean;
  /**
   * Liste CEKILEMEDIYSE hata mesaji. Verilirse tablo govdesi yerine
   * "tekrar dene" cikar.
   *
   * NEDEN TABLONUN ICINDE: cagiran sayfalar `{hata && <HataDurumu/>}`
   * yazip tabloyu ALTINDA cizmeye devam ediyordu; uc dustugunde
   * `satirlar` bos oldugu icin tablo "kayit yok" yaziyordu. Yani ayni
   * ekranda hem "cekilemedi" hem "kayit yok" — ikincisi bir IDDIADIR ve
   * yanlisti; kayit olabilir de, bilmiyoruz. Karari tabloya alarak
   * her cagiranin ayni hatayi tekrar yapmasi engellendi.
   */
  hata?: string | null;
  onTekrar?: () => void;
  /** Bos durum basligi (i18n). Verilmezse genel metin. */
  bosBaslik?: string;
  bosAciklama?: string;
  bosEylem?: ReactNode;

  /** Satir secimi acik mi. */
  secilebilir?: boolean;
  secili?: string[];
  onSeciliDegisti?: (idler: string[]) => void;
  /** Secim varken ustte cikan toplu islem seridi. */
  topluEylemler?: (secili: string[]) => ReactNode;

  /** Ust seritte cizilecek arama/filtre denetimleri. */
  araclar?: ReactNode;

  /**
   * TOPLAM SATIRI (`<tfoot>`). GORUNEN kolonlari alir — kullanici bir
   * kolonu gizlediyse altbilgi de o kolonu atlamali, yoksa hucreler
   * kayar ve toplam YANLIS SUTUNUN altinda gorunur.
   *
   * `<tfoot>` bilincli: gorsel olarak son satir gibi duran bir `<tr>`,
   * ekran okuyucuya sirdan bir veri satiri gibi okunur. `tfoot` "bu
   * ozettir" der.
   */
  altbilgi?: (gorunenKolonlar: Kolon<T>[]) => ReactNode;

  /** Sunucu tarafli kip: tablo yalniz durumu tasir. */
  /**
   * (P169 §3.1) DAR EKRAN MODU.
   *
   *   `kart`     — her satir bir karta doner (kimlik + ozet + rozet)
   *   `kaydirma` — kolonlar korunur, tablo yatay kayar, ILK KOLON SABIT
   *   `otomatik` — (varsayilan) kolonlarda `kartRolu` verilmisse `kart`,
   *                verilmemisse `kaydirma`
   *
   * NEDEN SAYFA SECIYOR: kolonlar arasi ILISKI kritik olan tablolarda
   * (borc/tahsilat/bakiye yan yana okunur) karta bolmek anlami bozar;
   * kisi/daire listelerinde ise kart okunakligi ARTIRIR. Bunu bilen
   * cagirandir, bilesen degil.
   */
  darMod?: "kart" | "kaydirma" | "otomatik";

  sunucuTarafli?: boolean;
  /** Sunucu taraflida ZORUNLU — toplam kayit sayisi. */
  toplam?: number;
  durum?: TabloDurumu;
  onDurumDegisti?: (d: TabloDurumu) => void;
}

export function VeriTablosu<T>({
  kolonlar,
  satirlar,
  satirId,
  yukleniyor = false,
  hata = null,
  onTekrar,
  bosBaslik,
  bosAciklama,
  bosEylem,
  secilebilir = false,
  secili = [],
  onSeciliDegisti,
  topluEylemler,
  araclar,
  altbilgi,
  darMod = "otomatik",
  sunucuTarafli = false,
  toplam,
  durum,
  onDurumDegisti,
}: VeriTablosuProps<T>) {
  const t = useT();
  // (P169 §3.1) DAR EKRAN: bant `sm` ise kart/kaydirma kararina bakilir.
  // Karar CIZIM ANINDA verilir, CSS ile degil: kart ve tablo AYNI DOM'da
  // duramaz (biri `<table>`, oteki liste) ve ikisini birden cizip
  // `hidden` ile gizlemek, her satiri IKI KEZ cizmek olurdu.
  const dar = useBant() === "sm";
  const kartAlanlari = kolonlar.some((k) => k.kartRolu);
  const kartModu =
    dar && (darMod === "kart" || (darMod === "otomatik" && kartAlanlari));

  const [icDurum, setIcDurum] = useState<TabloDurumu>(VARSAYILAN_DURUM);
  const d = durum ?? icDurum;

  function durumYaz(yeni: TabloDurumu) {
    if (onDurumDegisti) onDurumDegisti(yeni);
    if (!durum) setIcDurum(yeni);
  }

  // KOLON GORUNURLUGU — kullanicinin gizledikleri.
  const [gizli, setGizli] = useState<string[]>([]);
  const gorunen = kolonlar.filter((k) => !gizli.includes(k.id));

  // --- SIRALAMA (yalniz istemci kipinde uygulanir) ---
  const siralanmis = useMemo(() => {
    if (sunucuTarafli || !d.siraKolon) return satirlar;
    const k = kolonlar.find((x) => x.id === d.siraKolon);
    if (!k?.deger) return satirlar;
    const yon = d.siraYonu === "artan" ? 1 : -1;
    // `slice()`: girdiyi YERINDE siralamak cagiranin dizisini bozar ve
    // React'in referans karsilastirmasini yaniltir.
    return satirlar.slice().sort((a, b) => {
      const av = k.deger!(a);
      const bv = k.deger!(b);
      // BOS DEGERLER HER ZAMAN SONA: yon degisince bosluklarin basa
      // gelmesi, kullaniciya "veri kayboldu" hissi verir.
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      if (typeof av === "number" && typeof bv === "number") {
        return (av - bv) * yon;
      }
      // Metin: yerel duyarli karsilastirma (Turkce siralamasi dogru olsun).
      return String(av).localeCompare(String(bv)) * yon;
    });
  }, [satirlar, kolonlar, d.siraKolon, d.siraYonu, sunucuTarafli]);

  const toplamKayit = sunucuTarafli ? (toplam ?? 0) : siralanmis.length;
  const sonSayfa = Math.max(1, Math.ceil(toplamKayit / d.boy));

  const gosterilen = sunucuTarafli
    ? siralanmis
    : siralanmis.slice((d.sayfa - 1) * d.boy, d.sayfa * d.boy);

  function siralamaCevir(k: Kolon<T>) {
    const ayni = d.siraKolon === k.id;
    durumYaz({
      ...d,
      siraKolon: k.id,
      siraYonu: ayni && d.siraYonu === YON_ARTAN ? YON_AZALAN : YON_ARTAN,
      // Siralama degisince ILK SAYFAYA don: kullanici 7. sayfada
      // siralarsa, yeni sirada 7. sayfa bambaska bir yerdir.
      sayfa: 1,
    });
  }

  // --- SECIM ---
  const sayfaIdleri = gosterilen.map(satirId);
  const hepsiSecili =
    sayfaIdleri.length > 0 && sayfaIdleri.every((i) => secili.includes(i));
  const kismiSecili = !hepsiSecili && sayfaIdleri.some((i) => secili.includes(i));
  const tumuRef = useRef<HTMLInputElement | null>(null);

  // `indeterminate` HTML ozniteligi DEGIL, yalniz DOM ozelligi: JSX ile
  // verilemez, elle atanmasi gerekir.
  useEffect(() => {
    if (tumuRef.current) tumuRef.current.indeterminate = kismiSecili;
  }, [kismiSecili]);

  function tumunuCevir() {
    if (!onSeciliDegisti) return;
    onSeciliDegisti(
      hepsiSecili
        ? secili.filter((i) => !sayfaIdleri.includes(i))
        : [...new Set([...secili, ...sayfaIdleri])],
    );
  }

  function satirCevir(id: string) {
    if (!onSeciliDegisti) return;
    onSeciliDegisti(
      secili.includes(id) ? secili.filter((i) => i !== id) : [...secili, id],
    );
  }

  return (
    <Kart dolgu={false} className="overflow-hidden">
      {/* ---------------- UST SERIT: araclar + kolon gorunurlugu -------- */}
      {(araclar || kolonlar.some((k) => k.gizlenebilir !== false)) && (
        <div
          className="flex flex-wrap items-center gap-3 border-b p-3"
          style={{
            borderColor: "var(--yz-border)",
            borderBottomWidth: "var(--yz-border-w)",
          }}
        >
          <div className="min-w-0 flex-1">{araclar}</div>
          <KolonSecici
            kolonlar={kolonlar}
            gizli={gizli}
            onCevir={(id) =>
              setGizli((o) => (o.includes(id) ? o.filter((x) => x !== id) : [...o, id]))
            }
          />
        </div>
      )}

      {/* ---------------- TOPLU ISLEM SERIDI ---------------------------- */}
      {secilebilir && secili.length > 0 && (
        <div
          role="status"
          className="flex flex-wrap items-center gap-3 border-b p-3"
          style={{
            borderColor: "var(--yz-border)",
            borderBottomWidth: "var(--yz-border-w)",
            background: "var(--yz-surface-2)",
          }}
        >
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
            {t("tabloSecili", { n: String(secili.length) })}
          </span>
          {topluEylemler?.(secili)}
        </div>
      )}

      {/* ---------------- GOVDE ---------------------------------------- */}
      {hata ? (
        <HataDurumu mesaj={hata} onTekrar={onTekrar} />
      ) : yukleniyor ? (
        <IskeletTablo kolon={gorunen.length || 4} />
      ) : gosterilen.length === 0 ? (
        <BosDurum
          baslik={bosBaslik ?? t("tabloKayitYok")}
          aciklama={bosAciklama}
          eylem={bosEylem}
        />
      ) : kartModu ? (
        // (P169 §3.1) KART MODU — dar ekranda her satir bir kart.
        //
        // TABLO SEMANTIGI BIRAKILIYOR ve bu bilincli: `<table>` icinde
        // hucreleri blok yapmak (`display:block`) satir/kolon iliskisini
        // ekran okuyucudan GIZLER — yani goze duzelen sey kulaga bozulur.
        // Liste anlami acikca `<ul>/<li>` ile kuruluyor.
        <ul className="divide-y" style={{ borderColor: "var(--yz-border)" }}>
          {gosterilen.map((satir) => (
            <KartSatiri<T>
              key={satirId(satir)}
              satir={satir}
              kolonlar={gorunen}
              secilebilir={secilebilir}
              secili={secili.includes(satirId(satir))}
              onSec={() => satirCevir(satirId(satir))}
              detayEtiketi={t("tabloDetay")}
            />
          ))}
        </ul>
      ) : (
        // DUYARLI: dar ekranda yatay kaydirma. `role=region` + `tabindex`
        // olmadan klavye kullanicisi kaydiramaz (WCAG 2.1.1).
        //
        // (P169 §3.1) KAYDIRMA GOSTERGESI: sag kenarda yumusak bir
        // gradyan. Gostergesiz bir tabloda kullanici SAGA KAYDIRILABILDIGINI
        // bilmez — kolonlar ekran disinda kalir ve "veri eksik" sanir.
        <div className="relative">
          <div
            role="region"
            aria-label={t("tabloKolonlar")}
            tabIndex={0}
            className="odak-ic overflow-x-auto"
          >
          <table className="w-full border-collapse">
            <thead>
              <tr>
                {secilebilir && (
                  <th scope="col" className="w-10 p-3">
                    <input
                      ref={tumuRef}
                      type="checkbox"
                      checked={hepsiSecili}
                      onChange={tumunuCevir}
                      aria-label={t("tabloTumunuSec")}
                    />
                  </th>
                )}
                {gorunen.map((k) => (
                  <BaslikHucresi
                    key={k.id}
                    kolon={k}
                    aktif={d.siraKolon === k.id}
                    yon={d.siraYonu}
                    onSirala={() => siralamaCevir(k)}
                  />
                ))}
              </tr>
            </thead>
            <tbody>
              {gosterilen.map((satir, sira) => {
                const id = satirId(satir);
                const bu = secili.includes(id);
                return (
                  <tr
                    key={id}
                    // SIRALI GIRIS (brief). Gecikme `lib/hareket` tek
                    // kaynagindan; hareket azaltmada CSS animasyonu
                    // kapanir ve gecikmenin bir hukmu kalmaz.
                    className="yz-satir-giris"
                    style={{
                      animationDelay: `${siraGecikmesi(sira, true)}s`,
                      borderTopWidth: "var(--yz-border-w)",
                      borderTopStyle: "solid",
                      borderColor: "var(--yz-border)",
                      background: bu ? "var(--yz-surface-2)" : undefined,
                    }}
                  >
                    {secilebilir && (
                      <td className="p-3">
                        <input
                          type="checkbox"
                          checked={bu}
                          onChange={() => satirCevir(id)}
                          aria-label={t("tabloSatirSec")}
                        />
                      </td>
                    )}
                    {gorunen.map((k) => (
                      <td
                        key={k.id}
                        className={[
                          "p-3 align-middle",
                          k.sayisal ? "text-end tabular-nums" : "",
                          k.darEkrandaGizle ? "hidden md:table-cell" : "",
                        ]
                          .filter(Boolean)
                          .join(" ")}
                        style={{
                          fontSize: "var(--yz-fs-body)",
                          color: "var(--yz-text)",
                        }}
                      >
                        {k.hucre(satir)}
                      </td>
                    ))}
                  </tr>
                );
              })}
            </tbody>
            {altbilgi && (
              <tfoot
                style={{
                  borderTopWidth: "2px",
                  borderTopStyle: "solid",
                  borderColor: "var(--yz-border-strong)",
                }}
              >
                {altbilgi(gorunen)}
              </tfoot>
            )}
          </table>
          </div>
          {/* Sag kenar gradyani — "daha var" isareti. `aria-hidden`:
              ekran okuyucuya kaydirma zaten `role=region` ile bildirildi,
              dekoratif bir seridi ikinci kez duyurmak gurultu olurdu. */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-y-0 end-0 w-6 sm:hidden"
            style={{
              background:
                "linear-gradient(to left, var(--yz-surface-1), transparent)",
            }}
          />
        </div>
      )}

      {/* ---------------- ALT SERIT: sayfalama --------------------------- */}
      {!hata && !yukleniyor && toplamKayit > 0 && (
        <Sayfalama
          durum={d}
          toplam={toplamKayit}
          sonSayfa={sonSayfa}
          onDegis={durumYaz}
        />
      )}
    </Kart>
  );
}

/* ==================================================================== */

const ARIA_ARTAN = "ascending";
const ARIA_AZALAN = "descending";
const ARIA_YOK = "none";

function BaslikHucresi<T>({
  kolon,
  aktif,
  yon,
  onSirala,
}: {
  kolon: Kolon<T>;
  aktif: boolean;
  yon: SiraYonu;
  onSirala: () => void;
}) {
  const t = useT();
  const siralanabilir = kolon.siralanabilir ?? Boolean(kolon.deger);
  return (
    <th
      scope="col"
      // `aria-sort` YALNIZ aktif kolonda anlamli deger tasir; hepsine
      // yazmak ekran okuyucuya "hepsi sirali" dedirtir.
      aria-sort={aktif ? (yon === YON_ARTAN ? ARIA_ARTAN : ARIA_AZALAN) : ARIA_YOK}
      className={[
        "p-3 text-start font-medium",
        kolon.sayisal ? "text-end" : "",
        kolon.darEkrandaGizle ? "hidden md:table-cell" : "",
      ]
        .filter(Boolean)
        .join(" ")}
      style={{
        fontSize: "var(--yz-fs-xs)",
        letterSpacing: "var(--yz-tracking-label)",
        color: "var(--yz-text-2)",
        background: "var(--yz-surface-2)",
      }}
    >
      {siralanabilir ? (
        <button
          type="button"
          onClick={onSirala}
          aria-label={t("tabloSirala", { kolon: kolon.baslik })}
          className="odak-ic inline-flex items-center gap-1"
        >
          {kolon.baslik}
          <SiraOku aktif={aktif} yon={yon} />
        </button>
      ) : (
        kolon.baslik
      )}
    </th>
  );
}

function SiraOku({ aktif, yon }: { aktif: boolean; yon: SiraYonu }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-3 w-3"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.5"
      strokeLinecap="round"
      style={{ opacity: aktif ? 1 : 0.35 }}
    >
      {aktif && yon !== YON_ARTAN ? (
        <path d="M6 9l6 6 6-6" />
      ) : (
        <path d="M6 15l6-6 6 6" />
      )}
    </svg>
  );
}

/* ==================================================================== */

function KolonSecici<T>({
  kolonlar,
  gizli,
  onCevir,
}: {
  kolonlar: Kolon<T>[];
  gizli: string[];
  onCevir: (id: string) => void;
}) {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const secilebilirler = kolonlar.filter((k) => k.gizlenebilir !== false);
  if (secilebilirler.length === 0) return null;

  return (
    <div className="relative shrink-0">
      <Dugme boy="kucuk" onClick={() => setAcik((o) => !o)} aria-expanded={acik}>
        {t("tabloKolonlar")}
      </Dugme>
      {acik && (
        <div
          className="absolute end-0 mt-1 min-w-[180px] p-2"
          style={{
            zIndex: "var(--yz-z-dropdown)" as unknown as number,
            borderRadius: "var(--yz-radius-card)",
            background: "var(--yz-metal-1)",
            borderWidth: "var(--yz-border-w)",
            borderStyle: "solid",
            borderColor: "var(--yz-border)",
            boxShadow: "var(--yz-raised-hover)",
          }}
        >
          {secilebilirler.map((k) => (
            <label
              key={k.id}
              className="flex items-center gap-2 p-1.5"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
            >
              <input
                type="checkbox"
                checked={!gizli.includes(k.id)}
                onChange={() => onCevir(k.id)}
              />
              {k.baslik}
            </label>
          ))}
        </div>
      )}
    </div>
  );
}

/* ==================================================================== */

function Sayfalama({
  durum,
  toplam,
  sonSayfa,
  onDegis,
}: {
  durum: TabloDurumu;
  toplam: number;
  sonSayfa: number;
  onDegis: (d: TabloDurumu) => void;
}) {
  const t = useT();
  const ilk = (durum.sayfa - 1) * durum.boy + 1;
  const son = Math.min(durum.sayfa * durum.boy, toplam);

  return (
    <div
      className="flex flex-wrap items-center justify-between gap-3 border-t p-3"
      style={{
        borderColor: "var(--yz-border)",
        borderTopWidth: "var(--yz-border-w)",
      }}
    >
      <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("ortakToplam")}: {toplam} · {ilk}-{son}
      </span>

      <div className="flex items-center gap-2">
        <label
          className="flex items-center gap-2"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
        >
          {t("listeSayfaBasina")}
          <select
            value={durum.boy}
            onChange={(e) =>
              // BOY DEGISINCE ILK SAYFAYA DON: 100'luk 3. sayfadayken
              // 10'a gecmek, var olmayan bir sayfada birakirdi.
              onDegis({ ...durum, boy: Number(e.target.value) as SayfaBoyu, sayfa: 1 })
            }
            className="odak-ic h-9 px-2"
            style={{
              borderRadius: "var(--yz-radius-input)",
              background: "var(--yz-surface-sunken)",
              borderWidth: "var(--yz-border-w)",
              borderStyle: "solid",
              borderColor: "var(--yz-border)",
              color: "var(--yz-text)",
            }}
          >
            {SAYFA_BOYLARI.map((b) => (
              <option key={b} value={b}>
                {b}
              </option>
            ))}
          </select>
        </label>

        <Dugme
          boy="kucuk"
          disabled={durum.sayfa <= 1}
          onClick={() => onDegis({ ...durum, sayfa: durum.sayfa - 1 })}
          aria-label={t("listeOncekiSayfa")}
        >
          {t("ortakOnceki")}
        </Dugme>
        <Dugme
          boy="kucuk"
          disabled={durum.sayfa >= sonSayfa}
          onClick={() => onDegis({ ...durum, sayfa: durum.sayfa + 1 })}
          aria-label={t("listeSonrakiSayfa")}
        >
          {t("ortakSonraki")}
        </Dugme>
      </div>
    </div>
  );
}

/* ==================================================================== */

/**
 * (P169 §3.1) KART SATIRI — dar ekranda bir tablo satirinin karsiligi.
 *
 * =========================================================================
 * NE GOSTERILIR, NE GIZLENIR
 * =========================================================================
 * Kolonun `kartRolu`na gore:
 *   `baslik` ust satir (kimlik) · `rozet` sag ust · `ozet` etiketli alanlar
 *   `eylem`  alt serit · (rolsuz) "Detay" acilinca gorunur
 *
 * ROLSUZ KOLONLAR SILINMEZ, KATLANIR. Brief'in kirmizi cizgisi net:
 * "masaustunde olup mobilde kaybolan yetenek OLMAYACAK." Bu yuzden kart
 * bir OZETTIR, bir KIRPMA degil — geri kalan her sey tek dokunusla acilir.
 */
function KartSatiri<T>({
  satir,
  kolonlar,
  secilebilir,
  secili,
  onSec,
  detayEtiketi,
}: {
  satir: T;
  kolonlar: Kolon<T>[];
  secilebilir: boolean;
  secili: boolean;
  onSec: () => void;
  detayEtiketi: string;
}) {
  const [acik, setAcik] = useState(false);
  const rol = (r: Kolon<T>["kartRolu"]) => kolonlar.filter((k) => k.kartRolu === r);
  const baslik = rol("baslik");
  const rozet = rol("rozet");
  const ozet = rol("ozet");
  const eylem = rol("eylem");
  const gizli = kolonlar.filter((k) => !k.kartRolu);

  return (
    <li className="p-3">
      <div className="flex items-start gap-3">
        {secilebilir && (
          <input
            type="checkbox"
            checked={secili}
            onChange={onSec}
            // (P169 §5) 44 px dokunma hedefi — kutunun kendisi 16 px'tir,
            // dokunulabilir alan sarmalayiciyla buyutulur.
            className="mt-1 h-5 w-5"
            aria-label={detayEtiketi}
          />
        )}
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              {baslik.map((k) => (
                <div
                  key={k.id}
                  className="truncate"
                  style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
                >
                  {k.hucre(satir)}
                </div>
              ))}
            </div>
            <div className="flex shrink-0 items-center gap-1">
              {rozet.map((k) => (
                <span key={k.id}>{k.hucre(satir)}</span>
              ))}
            </div>
          </div>

          {ozet.length > 0 && (
            <dl className="mt-1 flex flex-wrap gap-x-4 gap-y-0.5">
              {ozet.map((k) => (
                <div key={k.id} className="flex min-w-0 gap-1">
                  {/* ETIKET DE CIZILIR: kart modunda kolon basligi
                      kaybolur ve "12.500,00" tek basina neyin tutari
                      oldugunu soylemez. */}
                  <dt style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                    {k.baslik}
                  </dt>
                  <dd
                    className="truncate"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                  >
                    {k.hucre(satir)}
                  </dd>
                </div>
              ))}
            </dl>
          )}

          {gizli.length > 0 && (
            <>
              <button
                type="button"
                aria-expanded={acik}
                onClick={() => setAcik((x) => !x)}
                className="odak-ic mt-2 min-h-11 py-1"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }}
              >
                {detayEtiketi}
              </button>
              {acik && (
                <dl className="mt-1 space-y-1">
                  {gizli.map((k) => (
                    <div key={k.id} className="flex gap-2">
                      <dt
                        className="shrink-0"
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                      >
                        {k.baslik}
                      </dt>
                      <dd
                        className="min-w-0"
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                      >
                        {k.hucre(satir)}
                      </dd>
                    </div>
                  ))}
                </dl>
              )}
            </>
          )}

          {eylem.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-2">
              {eylem.map((k) => (
                <span key={k.id}>{k.hucre(satir)}</span>
              ))}
            </div>
          )}
        </div>
      </div>
    </li>
  );
}
