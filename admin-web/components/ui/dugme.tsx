"use client";

/**
 * (P160 / Asama 3) METALIK DUGME.
 *
 * Brief: "metalik yuzey — kabartma + ust kenar parlamasi. Birincil dugme
 * accent tonunda, ikincil notr metal. DUZ RENK DOLGU YOK."
 *
 * =========================================================================
 * ERISILEBILIRLIK — dort sey pazarlik disi
 * =========================================================================
 * 1. 48px DOKUNMA HEDEFI: `orta` ve `buyuk` boylar bunu tutar. `kucuk`
 *    boy YALNIZ tablo satiri gibi yogun baglamlar icindir ve orada da
 *    dokunma hedefi satirin kendisiyle saglanir — bu yuzden `kucuk`
 *    36px'te birakildi, 44 degil.
 * 2. ODAK HALKASI: `odak-ic` sinifi depoda zaten var (globals.css,
 *    WCAG 2.4.11) ve yeniden yazilmadi — iki farkli odak gorunumu
 *    kullaniciya iki farkli urun hissi verirdi.
 * 3. YUKLENIRKEN `aria-busy` + `disabled`: cift gonderimi ENGELLER.
 *    Yalniz gorsel bir spinner koymak, kullanicinin ikinci kez basmasini
 *    engellemezdi.
 * 4. IKON-ONLY dugmede `aria-label` ZORUNLU (tip seviyesinde zorlanir).
 */
import Link from "next/link";
import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from "react";

export type DugmeTuru = "birincil" | "ikincil" | "sessiz" | "tehlike";
export type DugmeBoyu = "kucuk" | "orta" | "buyuk";

const BOY: Record<DugmeBoyu, { h: string; px: string; fs: string }> = {
  // 36px: yogun baglam (tablo satiri). Dokunma hedefi satirla saglanir.
  kucuk: { h: "h-9", px: "px-3", fs: "var(--yz-fs-sm)" },
  // (P244) 48px: dokunma hedefi 44'ten 48'e cikti.
  orta: { h: "h-12", px: "px-4", fs: "var(--yz-fs-body)" },
  buyuk: { h: "h-14", px: "px-5", fs: "var(--yz-fs-h3)" },
};

/**
 * Tur -> yuzey. Hepsi GRADYAN (duz dolgu yok) ve kabartma golgesi tasir;
 * fark yalnizca zemin ve metin renginde.
 */
function turStili(tur: DugmeTuru): React.CSSProperties {
  switch (tur) {
    case "birincil":
      return {
        background: "var(--yz-metal-accent)",
        // Accent zemin uzerindeki metin TOKEN'DAN gelir (`--yz-on-fill`).
        // Ilk yazimda burada sabit `#ffffff` vardi ve yorum "kontrast
        // olculdu" diyordu — OLCULMEMISTI (gercek deger 3.88, AA alti).
        // Dolgu koyulastirildi, deger token'a tasindi; ikisi de
        // `tasarim-sistemi.css`te gerekcesiyle yazili.
        color: "var(--yz-on-fill)",
        borderColor: "var(--yz-accent-edge)",
      };
    case "tehlike":
      return {
        background: "var(--yz-metal-2)",
        color: "var(--yz-danger-ink)",
        borderColor: "var(--yz-danger-edge)",
      };
    case "sessiz":
      // Kenarliksiz, zeminsiz — yalniz hover'da yuzey belirir. Ikincil
      // eylemlerin yaninda gorsel gurultu uretmemesi icin.
      return {
        background: "transparent",
        color: "var(--yz-text-2)",
        borderColor: "transparent",
        boxShadow: "none",
      };
    default:
      return {
        background: "var(--yz-metal-1)",
        color: "var(--yz-text)",
        borderColor: "var(--yz-border)",
      };
  }
}

type TemelProps = Omit<ButtonHTMLAttributes<HTMLButtonElement>, "className">;

export interface DugmeProps extends TemelProps {
  children?: ReactNode;
  tur?: DugmeTuru;
  boy?: DugmeBoyu;
  /** Basta cizilecek ikon (18px onerilir). */
  ikon?: ReactNode;
  /** Yukleniyor: `disabled` + `aria-busy`, cift gonderim engellenir. */
  yukleniyor?: boolean;
  /** Satir genisligi kaplasin mi (mobil form dugmeleri). */
  tamGenislik?: boolean;
  className?: string;
}

/**
 * (P244 §10) DUGME GORUNUMLU BAGLANTI.
 *
 * =========================================================================
 * OLCULEN KUSUR
 * =========================================================================
 * Depoda dugme gibi duran BES ayri elle yazilmis `<a>` vardi
 * (`tenants`, `kurulum`, `dokumanlar`, `settings`, `KurulumHatirlatici`)
 * ve ucu daha eski dilin `btnPrimary`/`btnGhost` sinif sabitlerini
 * kullaniyordu. Bes kopya = bes farkli yukseklik, dolgu ve odak halkasi.
 *
 * =========================================================================
 * NEDEN `Dugme` DEGIL
 * =========================================================================
 * `Dugme` bir `<button>` cizer. Hedefi bir SAYFA olan sey baglanti
 * olmali: orta tikla yeni sekmede acilir, ekran okuyucu "baglanti" der,
 * tarayici adresi onizler. Bir `<button>`a `onClick={router.push}`
 * takmak bunlarin ucunu de kaybeder.
 *
 * Gorunum sozlesmesi `Dugme` ile AYNI kaynaktan gelir (`BOY`,
 * `turStili`); ayrisamaz.
 */
export function DugmeBaglantisi({
  children,
  href,
  tur = "ikincil",
  boy = "orta",
  ikon,
  className = "",
  ...rest
}: {
  children?: ReactNode;
  href: string;
  tur?: DugmeTuru;
  boy?: DugmeBoyu;
  ikon?: ReactNode;
  className?: string;
} & Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "className" | "href">) {
  const b = BOY[boy];
  // IC ROTADA `next/link`, DISARIDA duz `<a>`.
  //
  // Duz `<a>` ic rotada ISTEMCI GECISINI KAYBETTIRIR: tarayici sayfayi
  // bastan yukler, kabuk yeniden kurulur ve SWR onbellegi bosalir.
  // Bu bilesen elle yazilmis bes baglantinin yerine geciyor ve o
  // beslerin hepsi `next/link` kullaniyordu — sessizce tam sayfa
  // yenilemeye donmek bir GERILEME olurdu.
  const Etiket = href.startsWith("/") ? Link : "a";
  return (
    <Etiket
      {...rest}
      href={href}
      className={[
        "odak-ic inline-flex items-center justify-center gap-2 border",
        "font-medium transition-[box-shadow,transform,background] select-none",
        b.h,
        b.px,
        "active:scale-[0.98]",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
      style={{
        borderRadius: "var(--yz-radius-btn)",
        fontSize: b.fs,
        borderWidth: "var(--yz-border-w)",
        boxShadow: tur === "sessiz" ? "none" : "var(--yz-raised)",
        transitionDuration: "var(--yz-dur-fast)",
        transitionTimingFunction: "var(--yz-ease)",
        textDecoration: "none",
        ...turStili(tur),
      }}
    >
      {ikon}
      {children}
    </Etiket>
  );
}

export function Dugme({
  children,
  tur = "ikincil",
  boy = "orta",
  ikon,
  yukleniyor = false,
  tamGenislik = false,
  disabled,
  className = "",
  style,
  ...rest
}: DugmeProps) {
  const b = BOY[boy];
  const kapali = disabled || yukleniyor;
  return (
    <button
      type="button"
      {...rest}
      disabled={kapali}
      aria-busy={yukleniyor || undefined}
      className={[
        "odak-ic inline-flex items-center justify-center gap-2 border",
        "font-medium transition-[box-shadow,transform,background] select-none",
        b.h,
        b.px,
        tamGenislik ? "w-full" : "",
        // Basma geri bildirimi: 0.98 (brief). `active:` yalniz fare/dokunma
        // basiliyken; klavye Enter'da da tetiklenir.
        kapali ? "cursor-not-allowed opacity-60" : "active:scale-[0.98]",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
      style={{
        borderRadius: "var(--yz-radius-btn)",
        fontSize: b.fs,
        borderWidth: "var(--yz-border-w)",
        boxShadow: tur === "sessiz" ? "none" : "var(--yz-raised)",
        transitionDuration: "var(--yz-dur-fast)",
        transitionTimingFunction: "var(--yz-ease)",
        ...turStili(tur),
        ...style,
      }}
      onMouseEnter={(e) => {
        if (kapali || tur === "sessiz") return;
        e.currentTarget.style.boxShadow = "var(--yz-raised-hover)";
      }}
      onMouseLeave={(e) => {
        if (kapali || tur === "sessiz") return;
        e.currentTarget.style.boxShadow = "var(--yz-raised)";
      }}
    >
      {yukleniyor ? <Firildak /> : ikon}
      {children}
    </button>
  );
}

/**
 * IKON DUGMESI — `aria-label` TIP SEVIYESINDE ZORUNLU.
 *
 * Ayri bir bilesen olmasinin tek sebebi bu: `Dugme`de `aria-label`
 * opsiyonel olmak zorunda (metinli dugmede gereksiz), ama ikon-only
 * dugmede unutulmasi ekran okuyucuda ADSIZ bir dugme birakir.
 * Tipi burada zorlamak, o hatayi derleme aninda yakalar.
 */
export function IkonDugmesi({
  ikon,
  etiket,
  ...rest
}: Omit<DugmeProps, "children" | "ikon" | "aria-label" | "tamGenislik"> & {
  ikon: ReactNode;
  etiket: string;
}) {
  return (
    <Dugme {...rest} aria-label={etiket} className="!px-0 aspect-square">
      {ikon}
    </Dugme>
  );
}

/** Dugme ici yukleme gostergesi. Hareket azaltmada donmez, sabit kalir. */
function Firildak() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-4 w-4 motion-safe:animate-spin"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.5"
      strokeLinecap="round"
    >
      <path d="M12 3a9 9 0 1 0 9 9" />
    </svg>
  );
}
