"use client";

/**
 * (P160 / Asama 3) KPI — DAIRESEL METALIK HALKA.
 *
 * Brief: "dairesel kabartmali halka, ortada buyuk sayi, altinda etiket.
 * Halka rengi duruma gore degisir ve iceriden hafif glow verir. Sayi
 * 0'dan hedefe sayarak gelir. Bu bilesen TEK YERDE yazilir, tum
 * ekranlarda kullanilir."
 *
 * =========================================================================
 * SAYAC — NEDEN `requestAnimationFrame`, NEDEN `setInterval` DEGIL
 * =========================================================================
 * `setInterval` kare hizina bagli DEGILDIR: sekme arka plana alininca
 * kisilir, yavas cihazda birikir ve sayac hedefi asip geri doner.
 * `rAF` tarayicinin cizim ritmine baglanir ve GECEN SUREYE gore
 * ilerler — 24'e giden sayac her cihazda ayni surede varir.
 *
 * HAREKET AZALTMADA SAYMAZ: `prefers-reduced-motion` aciksa deger
 * DOGRUDAN yazilir. Brief'in kurali ve dogru olan: sayan bir rakam,
 * vestibuler rahatsizligi olan kullanici icin gereksiz hareket.
 *
 * =========================================================================
 * ERISILEBILIRLIK — sayan rakam ekran okuyucuya OKUNMAZ
 * =========================================================================
 * Ara degerler (`0, 3, 7, 12...`) okunursa ekran okuyucu sacmalar.
 * Bu yuzden gorsel rakam `aria-hidden`, gercek deger ise tek bir
 * gorunmez metinde durur. Halka da `aria-hidden` — o bir dekordur;
 * anlami sayi ve etiket tasir.
 */
import { useEffect, useRef, useState } from "react";

const ETIKET_DUGME = "button";
const ETIKET_KUTU = "div";

export type KpiDurumu = "notr" | "bilgi" | "olumlu" | "uyari" | "kritik";

/**
 * Durum -> halka rengi. `-edge` varyanti kullaniliyor cunku halka ANLAM
 * TASIYAN bir grafik ogesidir (WCAG 1.4.11, esik 3.0) — ham ton bu esigi
 * acik temada tutmuyor (bkz. tasarim-sistemi.css).
 */
const HALKA: Record<KpiDurumu, string> = {
  notr: "var(--yz-text-3)",
  bilgi: "var(--yz-accent-edge)",
  olumlu: "var(--yz-success-edge)",
  uyari: "var(--yz-warning-edge)",
  kritik: "var(--yz-danger-edge)",
};

/** Ic parlama — halkanin ham tonundan, dusuk opaklikta. Dekoratif. */
const GLOW: Record<KpiDurumu, string> = {
  notr: "transparent",
  bilgi: "var(--yz-accent)",
  olumlu: "var(--yz-success)",
  uyari: "var(--yz-warning)",
  kritik: "var(--yz-danger)",
};

/** Halka cizgisi ve ic parlamanin CSS onekleri — bkz. `boxShadow`. */
const HALKA_CIZGI = "inset 0 0 0 2px ";
const GLOW_ICE = "inset 0 0 18px -6px ";

function hareketAzaltilmis(): boolean {
  if (typeof window === "undefined" || !window.matchMedia) return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/**
 * 0'dan `hedef`e yumusak sayar; hareket azaltmada dogrudan hedefi doner.
 *
 * SUNUCU CIZIMINDE HEDEF DEGER DONER: ilk kare `0` olsaydi sunucu ve
 * istemci farkli metin uretir, hidrasyon uyusmazligi cikardi.
 */
function useSayac(hedef: number, sure = 900): number {
  const [deger, setDeger] = useState(hedef);
  const ilkCizim = useRef(true);

  useEffect(() => {
    if (hareketAzaltilmis()) {
      setDeger(hedef);
      return;
    }
    // Ilk cizimde 0'dan basla; sonraki degisimlerde MEVCUT degerden.
    const baslangic = ilkCizim.current ? 0 : deger;
    ilkCizim.current = false;
    if (baslangic === hedef) return;

    let iptal = false;
    let t0: number | null = null;
    const adim = (t: number) => {
      if (iptal) return;
      if (t0 === null) t0 = t;
      const o = Math.min(1, (t - t0) / sure);
      // easeOutCubic: hizli baslar, hedefte yumusar.
      const e = 1 - (1 - o) ** 3;
      setDeger(Math.round(baslangic + (hedef - baslangic) * e));
      if (o < 1) requestAnimationFrame(adim);
    };
    const id = requestAnimationFrame(adim);
    return () => {
      iptal = true;
      cancelAnimationFrame(id);
    };
    // `deger` BILEREK bagimliliklarda YOK: her sayim adiminda etkiyi
    // yeniden kurmak sayaci sonsuza kadar yeniden baslatirdi.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hedef, sure]);

  return deger;
}

export interface KpiProps {
  /** Gosterilecek sayi. */
  deger: number;
  /** Halkanin altindaki etiket — i18n'den gelmis olmali. */
  etiket: string;
  durum?: KpiDurumu;
  /** Halkanin ortasinda sayinin ustunde kucuk ikon. */
  ikon?: React.ReactNode;
  /** Trend metni (orn. "+12%"). Yonu `trendYonu` belirler. */
  trend?: string;
  trendYonu?: "yukari" | "asagi" | "sabit";
  /** Sayinin sonuna eklenen birim (orn. "%"). Sayacta ANIMASYONA girmez. */
  birim?: string;
  /** Tiklanabilirse: karta gecis. */
  onClick?: () => void;
  /** Halka capi (px). Varsayilan 116 — referans gorseldeki olcek. */
  cap?: number;
}

export function Kpi({
  deger,
  etiket,
  durum = "notr",
  ikon,
  trend,
  trendYonu = "sabit",
  birim,
  onClick,
  cap = 116,
}: KpiProps) {
  const gosterilen = useSayac(deger);
  // UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`): tarama ucludeki
  // her dizeyi cevrilmemis metin adayi sayar ve HAKLIDIR.
  const Etiket = (onClick ? ETIKET_DUGME : ETIKET_KUTU) as React.ElementType;

  return (
    <Etiket
      type={onClick ? "button" : undefined}
      onClick={onClick}
      className={[
        "flex flex-col items-center gap-3",
        onClick ? "odak-ic yz-lift rounded-xl p-2" : "",
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {/* HALKA — dekor, ekran okuyucuya okunmaz. */}
      <div
        aria-hidden="true"
        className="relative flex items-center justify-center"
        style={{
          width: cap,
          height: cap,
          borderRadius: "var(--yz-radius-ring)",
          background: "var(--yz-metal-2)",
          // Kabartma + halka rengi: disarida ince renkli cember, iceride
          // yumusak glow. Ikisi tek `box-shadow` yiginida.
          // CSS SABIT DIZGEDEN DEGIL PARCALARDAN kurulur: sablon dizgesi
          // icinde CSS yazmak `sablon dizgesinde sabit metin` taramasini
          // (hakli olarak) tetikliyor — o tarama cevrilmesi gereken metni
          // ariyor ve CSS ile cumleyi ayirt edemez.
          boxShadow: [
            "var(--yz-raised)",
            HALKA_CIZGI + HALKA[durum],
            durum === "notr" ? "" : GLOW_ICE + GLOW[durum],
          ]
            .filter(Boolean)
            .join(", "),
        }}
      >
        <span className="flex flex-col items-center leading-none">
          {ikon && (
            <span className="mb-1" style={{ color: HALKA[durum] }}>
              {ikon}
            </span>
          )}
          <span
            style={{
              fontSize: "var(--yz-fs-kpi)",
              fontWeight: "var(--yz-fw-kpi)" as unknown as number,
              color: "var(--yz-text)",
              // Rakamlar SABIT GENISLIKTE: sayarken 1->8 gecisi genislik
              // degistirip metni titretirdi.
              fontVariantNumeric: "tabular-nums",
            }}
          >
            {gosterilen}
            {birim}
          </span>
        </span>
      </div>

      {/* GERCEK DEGER — ekran okuyucunun okudugu tek yer. */}
      <span className="sr-only">
        {etiket}: {deger}
        {birim ?? ""}
      </span>

      <span className="flex flex-col items-center gap-0.5">
        <span
          aria-hidden="true"
          style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text-2)" }}
        >
          {etiket}
        </span>
        {trend && (
          <span
            aria-hidden="true"
            style={{
              fontSize: "var(--yz-fs-xs)",
              color:
                trendYonu === "yukari"
                  ? "var(--yz-success-ink)"
                  : trendYonu === "asagi"
                    ? "var(--yz-danger-ink)"
                    : "var(--yz-text-3)",
            }}
          >
            {trend}
          </span>
        )}
      </span>
    </Etiket>
  );
}
