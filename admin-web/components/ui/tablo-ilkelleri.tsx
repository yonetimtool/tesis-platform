// (P244 §4) BASIT TABLO ILKELLERI — `components/tablo.tsx`ten TASINDI.
//
// ===========================================================================
// NEDEN TASINDI
// ===========================================================================
// Dosya ESKI tasarim dilinin siniflarini kullaniyordu (`kart-kenar`,
// `rounded-kart`, `bg-yuzey-card`, `text-metin-muted`) ve 8 sayfa ondan
// ithal ediyordu — yani o sayfalar "karma dil" olarak olculuyordu.
// Degerler token'a cevrildi ve dosya YENI katmana (`components/ui/`)
// tasindi: modul siniri artik tasarim dili siniriyla ayni yerde.
//
// ===========================================================================
// NEDEN `VeriTablosu`YA CEVRILMEDI
// ===========================================================================
// Ikisi FARKLI iki sey: `VeriTablosu` siralama, sayfalama, secim, kolon
// gizleme ve dar-ekran kart gorunumu tasiyan bir VERI TABLOSU; buradakiler
// ise duz bir tabloyu token diliyle cizen ILKELLER. Sekiz sayfayi
// `VeriTablosu`ya tasimak, her birinin hucrelerini kolon dizisine
// cevirmek demekti — yapisal bir donusum, gorsel bir temizlik degil.
// Ustelik alti satirlik bir tanim defterine sayfalama eklemek, ozellik
// degil gurultu olurdu.

"use client";

// (P138) ORTAK TABLO ILKELI — 23 sayfa ayni iskeleti elle yaziyordu.
//
// OLCUM: `form.tsx` kart/dugme/girdi icin ortak katman sagliyor ve P132.7
// tam bu yuzden 47 sayfayi TEK degisiklikle tasidi. Ama TABLO icin ortak
// katman YOKTU: `tableCardCls` tanimliydi ve HICBIR sayfa kullanmiyordu
// (0/23). Her sayfa `<table className="w-full text-sm">` iskeletini,
// baslik hucrelerini ve satir ayiricilarini kendi yaziyordu.
//
// Bedeli gorunum degil DEGISTIRILEBILIRLIK: tablo dilinde bir karar
// degistirmek 23 dosyaya dokunmak demekti ve pratikte hicbiri
// degistirilmiyordu. Bu dosya o kaldiraci kurar.
//
// -------------------------------------------------------------------------
// TINT BLOKLAR BURAYA GELMEZ — KAPSAM KARARI
// -------------------------------------------------------------------------
// P133'un onayladigi "tint blok" dili kendi tanimida "pano + tanitim
// yuzeyleri" diyor ve SERT SINIRI (1 kahraman + 4 ikincil) "renk SINYAL
// kalmali" diye var. 23 liste sayfasina tint dagitmak tam olarak o sinirin
// onledigi seyi yapardi. Liste sayfalari ayni TASARIM SISTEMINE oturur
// (yuzey, yaricap, bosluk, cip, tipografi olcegi); kahraman/tint dili
// panoda kalir.
//
// AYRIM DOLGU VE BOSLUKTAN: dikey izgara cizgisi YOK, satir arasi tek bir
// hafif yatay ayirici (`border-yuzey-divider`) ve uzerine gelince yuzey
// dolgusu. Degerlerin hepsi mevcut token'lardan; yeni renk/olcu ICAT
// EDILMEDI.
import type { ReactNode } from "react";
import { useT } from "@/lib/i18n/kullan";

import { Dugme } from "./dugme";

// Tablo kabı — kart yuzeyi + yatay kaydirma.
export function TabloKart({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  const t = useT();
  return (
    <div className={`overflow-hidden border ${className}`}
      style={{
        borderColor: "var(--yz-border)",
        borderWidth: "var(--yz-border-w)",
        borderRadius: "var(--yz-radius-card)",
        background: "var(--yz-surface-1)",
      }}>
      {/* DAR EKRANDA YATAY KAYDIRMA: tabloyu kirpmak yerine kaydirmak,
          sutun gizlemekten durusttur — kullanici verinin var oldugunu
          gorur. Sayfa govdesi yatay kaymaz, yalniz bu kap kayar. */}
      <div className="relative">
        {/* (P169 §3.1) `role=region` + `tabIndex` EKLENDI. Kaydirilabilir
            bir kutu bunlar olmadan KLAVYEYLE kaydirilamaz (WCAG 2.1.1):
            faresi olmayan kullanici icin sagdaki kolonlar YOK demekti.
            `VeriTablosu`da vardi, bu kapta YOKTU. */}
        <div
          role="region"
          aria-label={t("tabloKolonlar")}
          tabIndex={0}
          className="odak-ic overflow-x-auto"
        >
          {children}
        </div>
        {/* Sag kenar gradyani — "daha var" isareti; gostergesiz bir
            tabloda kullanici saga kaydirilabildigini BILMEZ ve veriyi
            eksik sanir. Genis ekranda gerek yok, orada tablo zaten sigar. */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-y-0 end-0 w-6 sm:hidden"
          style={{
            background:
              "linear-gradient(to left, var(--yz-surface-1), transparent)",
          }}
        />
      </div>
    </div>
  );
}

// `<table>` — tek yerde tanimli olcek. `className` yalnizca olcek
// gecersiz kilma icindir (bir rapor tablosu `text-xs` kullaniyor).
export function Tablo({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <table
      className={`w-full ${className}`}
      style={{ fontSize: "var(--yz-fs-sm)" }}
    >
      {children}
    </table>
  );
}

// Baslik satiri — sayfa zemini dolgusu, KENARLIK YOK.
//
// `zeminsiz`: 30 tablonun 10'u baslik zeminini BILEREK kullanmiyordu
// (panel icindeki kucuk tablolar). Ortak ilkele tasirken hepsine zemin
// vermek, yapisal birlestirmeyi gorsel bir karara cevirirdi.
export function TabloBasligi({
  children,
  zeminsiz = false,
  className = "",
}: {
  children: ReactNode;
  zeminsiz?: boolean;
  // Uc tablo kendi baslik bicimini tasiyor (kucuk olcek, ust cizgi).
  // Yapiyi birlestirirken o farklari SILMEK gorsel bir karar olurdu.
  className?: string;
}) {
  return (
    <thead
      className={`text-start ${className}`}
      style={{
        background: zeminsiz ? undefined : "var(--yz-surface-2)",
        color: "var(--yz-text-2)",
        fontSize: "var(--yz-fs-xs)",
        letterSpacing: "var(--yz-tracking-label)",
      }}
    >
      <tr>{children}</tr>
    </thead>
  );
}

// Baslik hucresi.
// `sag`/`sayi` sutunlari icin `hizala` verilir; `dar` eylem sutunlari
// icindir (govdede genisligi icerik belirlesin).
// SIK (`px-3 py-2`) BILINCLI BIR VARYANTTIR, kaza degil: rapor ve finans
// tablolari daha yogun yazilmisti ve 22 sayfayi ortak ilkele tasirken o
// yogunlugu SESSIZCE degistirmek, yapisal bir birlestirmeyi gorsel bir
// karara cevirirdi. Yapi birlesir, yogunluk farki KORUNUR.
const _dolgu = (sik: boolean) => (sik ? "px-3 py-2" : "px-4 py-2.5");

// UC TABLO KENDI DOLGUSUNU TASIYOR (`p-2`, `px-2 py-2`, `py-1.5`): panel
// icindeki kucuk/teknik tablolar (yetki matrisi, tanim satirlari, aidat
// ozeti). Yapiyi birlestirirken o dolgulari standarda cekmek GORSEL bir
// karar olurdu ve bu tur yapisal bir birlestirmeydi. `dolgusuz` ile
// hucre kendi dolgusunu `className` uzerinden verir.
const _sinif = (dolgusuz: boolean, sik: boolean) =>
  dolgusuz ? "" : _dolgu(sik);

export function Th({
  children,
  colSpan,
  hizala = "start",
  sik = false,
  dolgusuz = false,
  className = "",
}: {
  children?: ReactNode;
  // Ozet/gruplama satirlari birden fazla sutuna yayilir.
  colSpan?: number;
  hizala?: "start" | "end" | "center";
  sik?: boolean;
  dolgusuz?: boolean;
  className?: string;
}) {
  const h =
    hizala === "end" ? "text-end" : hizala === "center" ? "text-center" : "text-start";
  return (
    <th
      colSpan={colSpan}
      className={`${_sinif(dolgusuz, sik)} font-medium ${h} ${className}`}
    >
      {children}
    </th>
  );
}

// Govde satiri — ayirici ve uzerine gelme dolgusu BURADA.
// `border-t` ILK satirda da cizilir ve baslik zemininin altinda kalir;
// `first:border-t-0` ile kaldirilmaz cunku baslik ile govde arasindaki
// tek cizgi tam olarak istenen ayrimdir.
export function Tr({
  children,
  className = "",
  onClick,
}: {
  children: ReactNode;
  className?: string;
  onClick?: () => void;
}) {
  return (
    <tr
      onClick={onClick}
      // (P244 §4) HOVER ARTIK CSS'TE (`yz-satir`): satir ici `style` ile
      // `:hover` yazilamaz ve dokunmatikte `:hover` YAPISIR — kullanici
      // hangi satira dokundugunu unutunca yanlis bir "secili" izlenimi
      // kalirdi. Kural `@media (hover: hover)` ile sinirli.
      className={`yz-satir border-t transition-colors ${className}`}
      style={{ borderColor: "var(--yz-border)", borderTopWidth: "var(--yz-border-w)" }}
    >
      {children}
    </tr>
  );
}

// Govde hucresi. `sayi` tabular rakam kullanir (sutun kaymasin).
export function Td({
  children,
  colSpan,
  hizala = "start",
  sayi = false,
  sik = false,
  dolgusuz = false,
  className = "",
}: {
  children?: ReactNode;
  colSpan?: number;
  hizala?: "start" | "end" | "center";
  sayi?: boolean;
  sik?: boolean;
  dolgusuz?: boolean;
  className?: string;
}) {
  const h =
    hizala === "end" ? "text-end" : hizala === "center" ? "text-center" : "text-start";
  return (
    <td
      colSpan={colSpan}
      className={`${_sinif(dolgusuz, sik)} ${h} ${sayi ? "tabular-nums" : ""} ${className}`}
    >
      {children}
    </td>
  );
}

// BOS TABLO SATIRI — "kayit yok" hucresi.
// Ayri bir bilesen cunku her sayfa `colSpan`i elle yaziyordu ve biri
// eksik kalinca hucre tablonun altina tasiyordu.
export function BosSatir({
  sutun,
  children,
}: {
  sutun: number;
  children: ReactNode;
}) {
  return (
    <tr
      className="border-t"
      style={{ borderColor: "var(--yz-border)", borderTopWidth: "var(--yz-border-w)" }}
    >
      <td
        colSpan={sutun}
        className="px-4 py-8 text-center"
        style={{ color: "var(--yz-text-2)", fontSize: "var(--yz-fs-sm)" }}
      >
        {children}
      </td>
    </tr>
  );
}

/**
 * (P244 §4) SAYFALAYICI — `components/form.tsx`ten TASINDI.
 *
 * Sayfalama bir FORM kontrolu degil, tablonun parcasi. `VeriTablosu`
 * kendi sayfalayicisini tasiyor; bu, ILKELLERLE cizilmis duz tablolar
 * icindir (2 sayfa).
 */
export function Pager({
  offset,
  limit,
  total,
  onPrev,
  onNext,
}: {
  offset: number;
  limit: number;
  total: number;
  onPrev: () => void;
  onNext: () => void;
}) {
  const t = useT();
  const canPrev = offset > 0;
  const canNext = offset + limit < total;
  return (
    <div
      className="flex items-center justify-between"
      style={{ fontSize: "var(--yz-fs-sm)" }}
    >
      <span style={{ color: "var(--yz-text-2)" }}>
        {t("ortakSayfalayici", {
          toplam: total,
          bas: total === 0 ? 0 : offset + 1,
          son: Math.min(offset + limit, total),
        })}
      </span>
      <div className="flex gap-2">
        <Dugme tur="sessiz" boy="kucuk" disabled={!canPrev} onClick={onPrev}>
          {t("ortakOnceki")}
        </Dugme>
        <Dugme tur="sessiz" boy="kucuk" disabled={!canNext} onClick={onNext}>
          {t("ortakSonraki")}
        </Dugme>
      </div>
    </div>
  );
}
