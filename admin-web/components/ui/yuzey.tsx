"use client";

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
}: KartProps) {
  // UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
  const Etiket = (as ?? (onClick ? ETIKET_DUGME : ETIKET_KUTU)) as ElementType;
  // (P161) TIKLANABILIR KART VARSAYILAN OLARAK YUKSELIR.
  //
  // Brief "kart hover: 2 px yukselme + daha derin golge" der ama `kalkan`
  // opt-in'di ve cogu tiklanabilir kartta unutulmustu: tiklanabildigi
  // ekrandan anlasilmiyordu. Yukselme artik ETKILESIMDEN turer; kapatmak
  // isteyen `kalkan={false}` yazar (karar hala cagiranin).
  const yukselsin = kalkan ?? Boolean(onClick);
  return (
    <Etiket
      onClick={onClick}
      type={Etiket === "button" ? "button" : undefined}
      className={[
        TON_SINIFI[ton],
        yukselsin ? "yz-lift" : "",
        dolgu ? "p-4" : "",
        onClick ? "text-start w-full" : "",
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
