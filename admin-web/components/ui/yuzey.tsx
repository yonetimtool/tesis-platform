"use client";

import Link from "next/link";

/**
 * (P160 / Asama 3) METALIK YUZEY PRIMITIFLERI — `Kart`, `Panel`, `Bolum`.
 *
 * =========================================================================
 * BU DOSYADA SABIT RENK YOK
 * =========================================================================
 * Her deger `app/tasarim-sistemi.css`teki `--yz-*` token'larindan gelir.
 * Eski Tailwind renk siniflari (yuzey/metin/kenar aileleri) BILEREK
 * KULLANILMIYOR: onlar eski dile ait ve `globals.css`te `.dark` ile
 * yeniden eslenmis durumda — yeni yuzeylerde kullanmak iki dili
 * birbirine karistirirdi.
 *
 * Tailwind yalniz OLCU/YERLESIM icin kullanilir (`flex`, `gap-3`, `p-4`);
 * renk ve golge `style` uzerinden token okur. Bu ayrim testte de
 * kilitleniyor (`tests/yz-bilesen.test.tsx`).
 *
 * =========================================================================
 * NEDEN `style` PROP, NEDEN AYRI CSS SINIFI DEGIL
 * =========================================================================
 * `yz-raised` gibi yardimci siniflar CSS'te DURUYOR ve yuzeyin govdesini
 * onlar veriyor. Buradaki `style` yalnizca DEGISKEN bagliyor
 * (`background: var(--yz-metal-1)`) — yani deger yine tek kaynaktan
 * geliyor, bilesen onu tasimiyor.
 */
import type { CSSProperties, ElementType, ReactNode } from "react";
import { useT } from "@/lib/i18n/kullan";

const ETIKET_DUGME = "button";
const ETIKET_KUTU = "div";

export type YuzeyTonu = "kart" | "yukseltilmis" | "girintili";

const TON_SINIFI: Record<YuzeyTonu, string> = {
  kart: "yz-raised",
  yukseltilmis: "yz-raised-2",
  girintili: "yz-sunken",
};

export interface KartProps {
  children: ReactNode;
  /** Yuzey tonu — kabartma yonunu ve gradyani belirler. */
  ton?: YuzeyTonu;
  /** Hover'da 2px yukselme (brief). Tiklanabilir kartlarda `true`. */
  kalkan?: boolean;
  /** Ic bosluk; `false` ise cagiran kendi verir (tablo govdesi gibi). */
  dolgu?: boolean;
  className?: string;
  style?: CSSProperties;
  /** Semantik etiket — kart bir `section`/`article` olabilmeli. */
  as?: ElementType;
  onClick?: () => void;
  /**
   * (P168 §1.1) BAGLANTI KARTI — `href` verilince kart bir Next `Link`
   * olur ve istemci tarafi gezinme yapar.
   *
   * NEDEN PROP OLDU: cagiranlar `as="a"` + `{...{href}}` yaziyordu ve
   * `href` BU BILESENE HIC ULASMIYORDU — `Kart` fazladan prop'lari
   * yaymaz. JSX spread'i TypeScript'in fazla-ozellik denetiminden
   * kactigi icin derleyici de susuyordu. Sonuc: `<a>` etiketi HREF'SIZ
   * ciziliyor, yani ne tiklanabiliyor ne klavyeyle odaklanilabiliyordu
   * (widget seridi + finansal ozet kartlari).
   *
   * Artik `href` TIPLI: yanlis kullanim derleme hatasi verir.
   */
  href?: string;
}

/**
 * Temel metalik yuzey. Radius token'dan (`--yz-radius-card` = 12px),
 * brief'in "asiri yuvarlak kart YOK" kuralina uyar.
 */
export function Kart({
  children,
  ton = "kart",
  kalkan,
  dolgu = true,
  className = "",
  style,
  as,
  onClick,
  href,
}: KartProps) {
  // UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
  // HREF VARSA `Link` KAZANIR: `as="a"` yazan eski cagirilar da istemci
  // tarafi gezinmeye tasinsin — ham `<a>` tam sayfa yenilemesi yapar ve
  // panelde her tiklamada oturum kabugu bastan cizilirdi.
  const Etiket = (href ? Link : (as ?? (onClick ? ETIKET_DUGME : ETIKET_KUTU))) as ElementType;
  // (P161) TIKLANABILIR KART VARSAYILAN OLARAK YUKSELIR.
  //
  // Brief "kart hover: 2 px yukselme + daha derin golge" der ama `kalkan`
  // opt-in'di ve cogu tiklanabilir kartta unutulmustu: tiklanabildigi
  // ekrandan anlasilmiyordu. Yukselme artik ETKILESIMDEN turer; kapatmak
  // isteyen `kalkan={false}` yazar (karar hala cagiranin).
  const yukselsin = kalkan ?? Boolean(onClick || href);
  return (
    <Etiket
      onClick={onClick}
      href={href}
      type={Etiket === "button" ? "button" : undefined}
      className={[
        TON_SINIFI[ton],
        yukselsin ? "yz-lift" : "",
        dolgu ? "p-4" : "",
        onClick || href ? "text-start w-full" : "",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
      style={{
        borderRadius: "var(--yz-radius-card)",
        color: "var(--yz-text)",
        ...style,
      }}
    >
      {children}
    </Etiket>
  );
}

const BASLIK_2 = "h2";
const BASLIK_3 = "h3";

/**
 * Sayfa bolumu: baslik + istege bagli sag eylem + govde.
 *
 * BASLIK SEVIYESI CAGIRANDAN GELIR (`baslikSeviyesi`): bir sayfada
 * `h1` tektir ve bolum basliklari `h2`/`h3` olmali. Sabit `h2` yazmak,
 * ekran okuyucu icin bozuk bir baslik agaci uretirdi.
 */
export function Bolum({
  baslik,
  aciklama,
  eylem,
  children,
  baslikSeviyesi = 2,
  className = "",
}: {
  baslik?: ReactNode;
  aciklama?: ReactNode;
  eylem?: ReactNode;
  children: ReactNode;
  baslikSeviyesi?: 2 | 3;
  className?: string;
}) {
  const H = (baslikSeviyesi === 2 ? BASLIK_2 : BASLIK_3) as ElementType;
  return (
    <section className={className}>
      {(baslik || eylem) && (
        <div className="mb-3 flex items-end justify-between gap-4">
          <div className="min-w-0">
            {baslik && (
              <H
                className="truncate"
                style={{
                  fontSize: "var(--yz-fs-h2)",
                  color: "var(--yz-text)",
                  lineHeight: "var(--yz-lh-tight)",
                }}
              >
                {baslik}
              </H>
            )}
            {aciklama && (
              <p
                className="mt-1"
                style={{
                  fontSize: "var(--yz-fs-sm)",
                  color: "var(--yz-text-2)",
                }}
              >
                {aciklama}
              </p>
            )}
          </div>
          {eylem && <div className="shrink-0">{eylem}</div>}
        </div>
      )}
      {children}
    </section>
  );
}

/**
 * Girintili alan — input kutusu, kod bloklari, "sunken" hisli bolgeler.
 * Kabartmanin TERSI golgesini kullanir (bkz. `--yz-sunken`).
 */
export function Girinti({
  children,
  className = "",
  style,
}: {
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <div
      className={`yz-sunken ${className}`}
      style={{ borderRadius: "var(--yz-radius-input)", ...style }}
    >
      {children}
    </div>
  );
}

/**
 * (P244 §4) IKON KUTUSU — `components/tasarim.tsx`ten TASINDI.
 *
 * Eski surum `VURGU_TINT`/`VURGU_IKON` haritalarini kullaniyordu; onlar
 * ESKI dilin Tailwind sinif dizeleriydi (`bg-accent-blue/12` gibi) ve
 * tema degisince token katmanindan bagimsiz davraniyordu.
 *
 * DURUM ADLARI `OzetKarti` ILE AYNI (`notr/bilgi/olumlu/uyari/kritik`):
 * iki bilesen ayni sozlugu kullanmazsa, cagiran taraf her seferinde
 * "burada hangi ad gecerli" diye bakmak zorunda kalir.
 *
 * ZEMIN HAM TON, IKON `-edge` VARYANTI: zemin dekordur (kontrast sarti
 * yok), ikon ANLAMLI GRAFIKTIR ve 3.0 esigini tutmalidir (WCAG 1.4.11).
 */
export function IkonKutu({
  durum = "bilgi",
  kucuk = false,
  children,
}: {
  durum?: "notr" | "bilgi" | "olumlu" | "uyari" | "kritik";
  kucuk?: boolean;
  children: ReactNode;
}) {
  const ZEMIN: Record<string, string> = {
    notr: "var(--yz-surface-2)",
    bilgi: "color-mix(in srgb, var(--yz-accent) 14%, transparent)",
    olumlu: "color-mix(in srgb, var(--yz-success) 16%, transparent)",
    uyari: "color-mix(in srgb, var(--yz-warning) 20%, transparent)",
    kritik: "color-mix(in srgb, var(--yz-danger) 16%, transparent)",
  };
  const IKON: Record<string, string> = {
    notr: "var(--yz-text-2)",
    bilgi: "var(--yz-accent-edge)",
    olumlu: "var(--yz-success-edge)",
    uyari: "var(--yz-warning-edge)",
    kritik: "var(--yz-danger-edge)",
  };
  return (
    <span
      aria-hidden="true"
      className={`inline-flex shrink-0 items-center justify-center ${
        kucuk ? "h-8 w-8" : "h-10 w-10"
      }`}
      style={{
        borderRadius: kucuk ? "var(--yz-radius-ring)" : "var(--yz-radius-sm)",
        background: ZEMIN[durum],
        color: IKON[durum],
      }}
    >
      {children}
    </span>
  );
}

/**
 * (P244 §4) BOLUM BASLIK SATIRI — `components/tasarim.tsx`ten TASINDI.
 *
 * `Bolum` (yukarida) bir SARMALAYICIDIR: baslik + govde. Bu ise yalniz
 * BASLIK SATIRI — pano gibi, govdesi ayri cizilen duzenler icin.
 * Ikisi karistirilirsa `children` zorunlulugu yuzunden derleme hatasi
 * gelir (bu tasima sirasinda tam olarak oldu ve `tsc` yakaladi).
 *
 * `href` verilirse sagda "Tumunu gor" baglantisi cizilir — referansta
 * her kart basliginin sagindaki desen.
 */
export function BolumBasligi({
  baslik,
  href,
  sag,
}: {
  baslik: string;
  href?: string;
  sag?: ReactNode;
}) {
  const t = useT();
  return (
    <div className="mb-3 flex items-center justify-between gap-3">
      <h2
        style={{
          fontSize: "var(--yz-fs-h3)",
          fontWeight: 600,
          color: "var(--yz-text)",
        }}
      >
        {baslik}
      </h2>
      {href ? (
        <Link
          href={href}
          className="odak-ic shrink-0 hover:underline"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }}
        >
          {t("tasarimTumunuGor")}
        </Link>
      ) : (
        sag
      )}
    </div>
  );
}
