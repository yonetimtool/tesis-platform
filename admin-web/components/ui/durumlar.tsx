"use client";

/**
 * (P160 / Asama 3) UC EKRAN DURUMU — YUKLENIYOR · BOS · HATA.
 *
 * Envanterde olculdu: 52 korumali sayfanin SIFIRINDA iskelet yukleme
 * durumu yok. Brief: "her sayfanin skeleton yukleme durumu olacak
 * (spinner degil), anlamli bos durum, hata durumu + Tekrar Dene".
 *
 * =========================================================================
 * NEDEN ISKELET, NEDEN FIRILDAK DEGIL
 * =========================================================================
 * Firildak "bir sey oluyor" der ama NE oldugunu soylemez; iskelet gelecek
 * duzeni gosterir, dolayisiyla algilanan bekleme suresi kisalir ve icerik
 * gelince ZIPLAMA olmaz (yerlesim ayni). Sayfa basina ayri firildak
 * yazmak, ayni kalitesizligi 52 kez tekrarlamakti.
 *
 * =========================================================================
 * ERISILEBILIRLIK
 * =========================================================================
 * * Iskelet `aria-hidden` + kapsayicida `aria-busy`: ekran okuyucu sahte
 *   kutulari okumaz, ama "mesgul" oldugunu bilir.
 * * Hata `role="alert"`: odak degistirmeden duyurulur.
 * * Bos durum `role="status"` DEGIL duz metin — sayfa ilk kez bosken bir
 *   duyuru yapmak gereksiz gurultudur; bos durum bir OLAY degil, bir HAL.
 */
import type { ReactNode } from "react";

import { useT } from "@/lib/i18n/kullan";

import { Dugme } from "./dugme";
import { Kart } from "./yuzey";

/** Hata simgesinin halkasi. Sablon dizgesi DEGIL sabit — bkz. kpi.tsx. */
const HATA_HALKASI = "inset 0 0 0 2px var(--yz-danger-edge)";

/* ========================================================================
   ISKELET
   ======================================================================== */

/**
 * Tek iskelet parcasi. Genislik/yukseklik cagirandan gelir ki gelecek
 * icerigin OLCUSUNU taklit etsin — sabit bir kutu, ziplamayi onlemez.
 */
export function Iskelet({
  className = "",
  yuvarlak = false,
}: {
  className?: string;
  yuvarlak?: boolean;
}) {
  return (
    <span
      aria-hidden="true"
      className={`block motion-safe:animate-pulse ${className}`}
      style={{
        background: "var(--yz-surface-sunken)",
        borderRadius: yuvarlak
          ? "var(--yz-radius-ring)"
          : "var(--yz-radius-btn)",
      }}
    />
  );
}

/** Metin satirlari iskeleti — liste/kart govdeleri icin. */
export function IskeletMetin({ satir = 3 }: { satir?: number }) {
  return (
    <div aria-busy="true" className="space-y-2">
      {Array.from({ length: satir }).map((_, i) => (
        <Iskelet
          key={i}
          className="h-3"
          // Son satir kisa: gercek metin blogu boyle biter, esit satirlar
          // "yukleniyor" degil "bozuk tablo" gibi gorunur.
          {...{ style: { width: i === satir - 1 ? "60%" : "100%" } }}
        />
      ))}
    </div>
  );
}

/**
 * Tablo iskeleti — `VeriTablosu` yuklenirken. Kolon sayisi verilir ki
 * iskelet gercek tablonun genisligini taklit etsin.
 */
export function IskeletTablo({
  satir = 6,
  kolon = 4,
}: {
  satir?: number;
  kolon?: number;
}) {
  return (
    <div aria-busy="true" className="space-y-2 p-4">
      {Array.from({ length: satir }).map((_, s) => (
        <div key={s} className="flex gap-3">
          {Array.from({ length: kolon }).map((_, k) => (
            <Iskelet
              key={k}
              className="h-4 flex-1"
              // Ilk kolon genis (ad), sonrakiler dar — gercek tablolarin
              // tipik ritmi.
              {...{ style: { maxWidth: k === 0 ? ILK_KOLON : DAR_KOLON } }}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

const ILK_KOLON = "none";
const DAR_KOLON = "120px";

/** KPI seridi iskeleti — dashboard icin. */
export function IskeletKpi({ adet = 3, cap = 116 }: { adet?: number; cap?: number }) {
  return (
    <div aria-busy="true" className="flex flex-wrap gap-8">
      {Array.from({ length: adet }).map((_, i) => (
        <div key={i} className="flex flex-col items-center gap-3">
          <Iskelet yuvarlak {...{ style: { width: cap, height: cap } }} />
          <Iskelet className="h-3" {...{ style: { width: 72 } }} />
        </div>
      ))}
    </div>
  );
}

/* ========================================================================
   BOS DURUM
   ======================================================================== */

export function BosDurum({
  baslik,
  aciklama,
  ikon,
  eylem,
}: {
  /** i18n'den gelen baslik. */
  baslik: string;
  aciklama?: string;
  /** Minimal ikon/illustrasyon. Verilmezse notr bir kutu cizilir. */
  ikon?: ReactNode;
  /** "Yeni ekle" gibi bir cikis yolu — bos ekrani cikmaz sokak birakma. */
  eylem?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 px-6 py-12 text-center">
      <span
        aria-hidden="true"
        className="flex h-12 w-12 items-center justify-center"
        style={{
          borderRadius: "var(--yz-radius-card)",
          background: "var(--yz-surface-sunken)",
          color: "var(--yz-text-3)",
          boxShadow: "var(--yz-sunken)",
        }}
      >
        {ikon ?? <VarsayilanIkon />}
      </span>
      <p style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
        {baslik}
      </p>
      {aciklama && (
        <p
          className="max-w-sm"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
        >
          {aciklama}
        </p>
      )}
      {eylem && <div className="mt-1">{eylem}</div>}
    </div>
  );
}

function VarsayilanIkon() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-6 w-6"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3.5" y="5" width="17" height="14" rx="2" />
      <path d="M3.5 10h17" />
    </svg>
  );
}

/* ========================================================================
   HATA DURUMU
   ======================================================================== */

/**
 * Brief: "Veriler yuklenemedi" + "Tekrar Dene".
 *
 * `onTekrar` VERILMEZSE dugme CIZILMEZ: calismayan bir "tekrar dene"
 * dugmesi, kullaniciyi ayni duvara ikinci kez carptirmaktan baska bir
 * sey yapmaz.
 *
 * =========================================================================
 * (P175) `mesaj === null` ISE HICBIR SEY CIZILMEZ
 * =========================================================================
 * OLCULEN OLAY: kurulum sihirbazi her acilista "Veriler yuklenemedi."
 * gosteriyordu — VERI DOGRU GELDIGI HALDE. Ekran hem 3/8 ilerlemeyi hem
 * de hata kartini birlikte ciziyordu (gercek govdeyle uretildi).
 *
 * SEBEP BU BILESENDEYDI: `mesaj` null olsa bile kart CIZILIYOR ve
 * `{mesaj || t("ortakVeriYuklenemedi")}` genel metne dusuyordu. Yani
 * "hata yok" demenin bir yolu YOKTU.
 *
 * Cagiranlarin cogu su kalibi kullaniyor ve bilesenden GORUNMEMESINI
 * bekliyor:
 *
 *     <HataDurumu mesaj={hata ?? (error ? t("...") : null)} />
 *
 * Tarandi: 28 dosyada 39 yer boyle cagiriyordu, yani o ekranlarin hepsi
 * KALICI bir sahte hata kartI tasiyordu (formlar, modallar, finans
 * ekranlari dahil). Kusur P160'tan, yani bilesenin ilk gununden beri
 * duruyordu.
 *
 * AYRIM `null` ile `undefined` ARASINDA ve bu bilincli:
 *   * `mesaj={null}`   -> HATA YOK, hicbir sey cizme.
 *   * `mesaj` VERILMEZ -> "hata var ama metni yok", genel metin cizilir.
 * Uc cagri yeri ikinci bicimi kullaniyor ve onlar KORUNUYOR. Ikisini tek
 * davranisa indirmek, "hata yok"u anlatmanin yolunu ya da genel metni
 * yok ederdi.
 */
export function HataDurumu({
  mesaj,
  onTekrar,
  yukleniyor = false,
}: {
  /**
   * Sunucudan gelen metin varsa O gosterilir; ALAN HIC VERILMEZSE genel
   * i18n metni. `null` VERILIRSE bilesen HICBIR SEY CIZMEZ.
   */
  mesaj?: string | null;
  onTekrar?: () => void;
  yukleniyor?: boolean;
}) {
  const t = useT();
  // ACIKCA `null`: cagiran "su an hata yok" diyor.
  if (mesaj === null) return null;
  return (
    <Kart ton="girintili" className="flex flex-col items-center gap-3 py-10 text-center">
      <span
        aria-hidden="true"
        className="flex h-11 w-11 items-center justify-center"
        style={{
          borderRadius: "var(--yz-radius-ring)",
          color: "var(--yz-danger-edge)",
          boxShadow: HATA_HALKASI,
        }}
      >
        <svg
          viewBox="0 0 24 24"
          className="h-5 w-5"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
        >
          <path d="M12 8v5" />
          <path d="M12 16.5v.01" />
        </svg>
      </span>
      <p role="alert" style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
        {mesaj || t("ortakVeriYuklenemedi")}
      </p>
      {onTekrar && (
        <Dugme boy="kucuk" onClick={onTekrar} yukleniyor={yukleniyor}>
          {t("ortakTekrarDene")}
        </Dugme>
      )}
    </Kart>
  );
}
