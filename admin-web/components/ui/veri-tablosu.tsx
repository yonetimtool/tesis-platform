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

import { useT } from "@/lib/i18n/kullan";

import { Dugme } from "./dugme";
import { BosDurum, HataDurumu, IskeletTablo } from "./durumlar";
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
  sunucuTarafli = false,
  toplam,
  durum,
  onDurumDegisti,
}: VeriTablosuProps<T>) {
  const t = useT();
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
      ) : (
        // DUYARLI: dar ekranda yatay kaydirma. `role=region` + `tabindex`
        // olmadan klavye kullanicisi kaydiramaz (WCAG 2.1.1).
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
              {gosterilen.map((satir) => {
                const id = satirId(satir);
                const bu = secili.includes(id);
                return (
                  <tr
                    key={id}
                    style={{
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
