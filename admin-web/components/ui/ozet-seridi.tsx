"use client";

// (P244 §3) OZET SERIDI — referansin dikdortgen KPI karti.
//
// ===========================================================================
// OLCULEN BOSLUK
// ===========================================================================
// 79 korumali sayfanin **3'unde** KPI var. Referansta ise neredeyse her
// operasyon ekraninin ustunde 3-5 karttan olusan bir ozet seridi duruyor
// (Araç Geçişleri 5, Acil Durum 4, Devriye 4, Aidat 3...).
//
// "Sayfalar bos gorunuyor" sikayetinin en buyuk tek kaynagi bu: cogu
// ekranda baslik ile tablo arasinda HICBIR sey yok, yani kullanici
// sayfanin ne anlattigini ancak tabloyu okuyarak anliyor.
//
// ===========================================================================
// NEDEN MEVCUT `Kpi` KULLANILMADI
// ===========================================================================
// `Kpi` bir HALKA (116 px cember, glow'lu). Referansin karti dikdortgen:
// solda tonlu ikon kutusu, sonra etiket, buyuk sayi ve bir alt satir;
// sag ustte istege bagli trend rozeti. Ikisi farkli SEKIL; halkayi
// dikdortgene zorlamak, panoda calisan bir bileseni bozmak olurdu.
//
// `Kpi` duruyor ve panoda kullanilmaya devam ediyor (asama 5'te ele
// alinacak). Bu bilesen LISTE EKRANLARI icin.
import Link from "next/link";
import type { ReactNode } from "react";

export type OzetDurumu = "notr" | "bilgi" | "olumlu" | "uyari" | "kritik";
export type TrendYonu = "iyi" | "kotu" | "sabit";

/** Ikon kutusunun zemini — HAM ton, uzerinde METIN YOK (dekor). */
const ZEMIN: Record<OzetDurumu, string> = {
  notr: "var(--yz-surface-2)",
  bilgi: "color-mix(in srgb, var(--yz-accent) 14%, transparent)",
  olumlu: "color-mix(in srgb, var(--yz-success) 16%, transparent)",
  uyari: "color-mix(in srgb, var(--yz-warning) 20%, transparent)",
  kritik: "color-mix(in srgb, var(--yz-danger) 16%, transparent)",
};

/** Ikonun KENDISI — anlamli grafik, 3.0 esigi icin `-edge` varyanti. */
const IKON: Record<OzetDurumu, string> = {
  notr: "var(--yz-text-2)",
  bilgi: "var(--yz-accent-edge)",
  olumlu: "var(--yz-success-edge)",
  uyari: "var(--yz-warning-edge)",
  kritik: "var(--yz-danger-edge)",
};

/**
 * TREND RENGI YONE DEGIL ANLAMA BAGLI.
 *
 * Referansta (`ui5.png`) "Açık Talepler ↓%20" KIRMIZI cizilmis — oysa acik
 * talebin azalmasi IYI haberdir. Ok yonu ile iyi/kotu ayni sey degildir:
 * borc duserse iyi, tahsilat duserse kotu. Bu yuzden cagiran taraf
 * `trendYonu`nu ANLAM olarak verir (`iyi`/`kotu`), ok yonunu degil.
 */
const TREND_RENK: Record<TrendYonu, string> = {
  iyi: "var(--yz-success-ink)",
  kotu: "var(--yz-danger-ink)",
  sabit: "var(--yz-text-2)",
};

export interface OzetKartiProps {
  etiket: string;
  /** Bicimlenmis deger — para/yuzde birimi cagiranin isi. */
  deger: string;
  /** Kartin altindaki bir satirlik baglam ("12 dairede borç var"). */
  altBilgi?: ReactNode;
  ikon?: ReactNode;
  durum?: OzetDurumu;
  /** Trend metni ("%5"). Yon `trendYonu` ile ANLAM olarak verilir. */
  trend?: string;
  trendYonu?: TrendYonu;
  href?: string;
}

export function OzetKarti({
  etiket,
  deger,
  altBilgi,
  ikon,
  durum = "notr",
  trend,
  trendYonu = "sabit",
  href,
}: OzetKartiProps) {
  const govde = (
    <>
      <div className="flex items-start gap-3">
        {ikon ? (
          <span
            aria-hidden="true"
            className="flex h-10 w-10 shrink-0 items-center justify-center"
            style={{
              borderRadius: "var(--yz-radius-sm)",
              background: ZEMIN[durum],
              color: IKON[durum],
            }}
          >
            {ikon}
          </span>
        ) : null}
        <div className="min-w-0 flex-1">
          {/* (E2E 2026-09) KESILMEZ, SARAR. Olculen: finans ozet
              kartlarinda "onay bekleyen hareketler" ve "odenmis
              faturalar" etiketleri kesiliyordu; Buyuk modda yazi buyuyor,
              kart genisligi ayni kaliyordu. Etiketin iki satira dusmesi,
              okunmamasindan iyidir. */}
          <p
            className="break-words"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {etiket}
          </p>
          <p
            className="mt-0.5 tabular-nums"
            style={{
              fontSize: "var(--yz-fs-h1)",
              fontWeight: "var(--yz-fw-kpi)" as unknown as number,
              lineHeight: "var(--yz-lh-tight)",
              color: "var(--yz-text)",
            }}
          >
            {deger}
          </p>
        </div>
        {trend ? (
          // TREND ROZETI: ok YONU okunur, renk ANLAMI soyler. Ikisi
          // birlikte — renk tek tasiyici degil.
          <span
            className="shrink-0 tabular-nums"
            style={{ fontSize: "var(--yz-fs-xs)", color: TREND_RENK[trendYonu] }}
          >
            {trend}
          </span>
        ) : null}
      </div>
      {altBilgi ? (
        <p
          className="mt-2"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
        >
          {altBilgi}
        </p>
      ) : null}
    </>
  );

  const stil = {
    background: "var(--yz-surface-1)",
    border: "var(--yz-border-w) solid var(--yz-border)",
    borderRadius: "var(--yz-radius-card)",
  } as const;

  // TIKLANABILIRSE BAGLANTI, DEGILSE KUTU: "tiklanabilir gorunen ama
  // tiklanmayan kart" kullaniciyi bir kez aldatir, ikinci kez denemez.
  return href ? (
    <Link href={href} className="odak-ic yz-lift block px-4 py-3.5" style={stil}>
      {govde}
    </Link>
  ) : (
    <div className="px-4 py-3.5" style={stil}>
      {govde}
    </div>
  );
}

/**
 * Serit: kartlari esit genislikte dizer.
 *
 * SUTUN SAYISI SABIT DEGIL: uc kart 3, dort kart 4 sutundur. Sabit bir
 * `lg:grid-cols-4`, uc kartli bir ekranda sagda bos bir kolon birakirdi —
 * P244'un kacinmak istedigi "olu bosluk" tam olarak budur.
 */
export function OzetSeridi({ children }: { children: ReactNode }) {
  return (
    <div
      className="mb-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-[repeat(auto-fit,minmax(13rem,1fr))]"
      data-test="ozet-seridi"
    >
      {children}
    </div>
  );
}
