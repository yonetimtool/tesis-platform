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
    <div className={`kart-kenar overflow-hidden rounded-kart border bg-yuzey-card ${className}`}>
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
  return <table className={`w-full text-sm ${className}`}>{children}</table>;
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
      className={`${zeminsiz ? "" : "bg-yuzey-bg"} text-start text-metin-muted ${className}`}
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
      className={`border-t border-yuzey-divider transition-colors hover:bg-yuzey-bg ${className}`}
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
    <tr className="border-t border-yuzey-divider">
      <td colSpan={sutun} className="px-4 py-8 text-center text-metin-muted">
        {children}
      </td>
    </tr>
  );
}
