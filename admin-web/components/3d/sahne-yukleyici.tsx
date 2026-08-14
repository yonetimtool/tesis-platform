"use client";

/**
 * (P160 / Asama 5) 3D SARMALAYICI — tembel yukleme + zarif geri dusus.
 *
 * Brief'in tartismasiz kurallari BURADA uygulanir; sahne dosyasi yalniz
 * cizimle ilgilenir:
 *   * TEMBEL YUKLEME + KOD BOLME — 3D paketi ana pakete GIRMEZ,
 *   * WEBGL YOKSA ZARIF GERI DUSUS — ekran BOS KALMAZ,
 *   * MOBILDE SADELESTIRILMIS/DURAGAN gorsellestirme,
 *   * `prefers-reduced-motion` aciksa sahne STATIK.
 *
 * =========================================================================
 * NEDEN AYRI DOSYA
 * =========================================================================
 * `next/dynamic(... , { ssr: false })` cagrisi, ice aktarilan modulun
 * sunucu paketine girmemesini saglar. Bu karari sahnenin KENDI icinde
 * vermek imkansiz: modul zaten yuklenmis olurdu.
 */
import dynamic from "next/dynamic";
import { useEffect, useState } from "react";

import { useT } from "@/lib/i18n/kullan";

import { Iskelet } from "../ui/durumlar";
import type { BinaSahnesiProps } from "./bina-sahnesi";

/**
 * WebGL destegi — BIR KEZ olculur.
 *
 * `canvas.getContext("webgl")` cagrisi pahalidir ve her cizimde
 * yapilirsa GPU baglami sizdirir; sonuc modul duzeyinde onbelleklenir.
 */
let webglDestegi: boolean | null = null;
function webglVar(): boolean {
  if (webglDestegi !== null) return webglDestegi;
  try {
    const c = document.createElement("canvas");
    webglDestegi = Boolean(
      c.getContext("webgl2") ?? c.getContext("webgl"),
    );
  } catch {
    webglDestegi = false;
  }
  return webglDestegi;
}

const Sahne = dynamic(() => import("./bina-sahnesi"), {
  ssr: false,
  loading: () => <Iskelet className="h-full w-full" />,
});

export function BinaSahnesiYukleyici(
  props: Omit<BinaSahnesiProps, "koyu" | "hareketVar"> & {
    /** Sahne yuksekligi (CSS). */
    yukseklik?: string;
  },
) {
  const t = useT();
  const { yukseklik = "320px", ...sahneProps } = props;
  const [hazir, setHazir] = useState(false);
  const [destek, setDestek] = useState(true);
  const [koyu, setKoyu] = useState(false);
  const [hareket, setHareket] = useState(true);
  const [mobil, setMobil] = useState(false);

  // TUM OLCUMLER ISTEMCIDE: `window` sunucuda yok ve ilk kare sunucuda
  // ciziliyor. `hazir` bayragi olmadan sunucu/istemci farki hidrasyon
  // uyusmazligi uretirdi.
  useEffect(() => {
    setDestek(webglVar());
    setKoyu(document.documentElement.classList.contains("dark"));
    setHareket(
      !window.matchMedia?.("(prefers-reduced-motion: reduce)").matches,
    );
    // MOBIL: sahne cizilir ama DURAGAN (brief). Dokunmatik cihazda
    // surekli render pil tuketir ve kucuk ekranda maket zaten okunmaz.
    setMobil(window.matchMedia?.("(max-width: 768px)").matches ?? false);
    setHazir(true);
  }, []);

  if (!hazir) {
    return <Iskelet className="w-full" {...{ style: { height: yukseklik } }} />;
  }

  // WEBGL YOKSA EKRAN BOS KALMAZ: sahnenin tasidigi bilgi (kac blok,
  // kac isaretci ve durumlari) METIN olarak verilir. Bu, ayni zamanda
  // sahnenin ekran okuyucu karsiligidir.
  if (!destek) {
    return (
      <div
        className="flex h-full w-full flex-col items-center justify-center gap-2 p-6 text-center"
        style={{
          height: yukseklik,
          borderRadius: "var(--yz-radius-card)",
          background: "var(--yz-surface-sunken)",
          boxShadow: "var(--yz-sunken)",
        }}
      >
        <p style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
          {t("sahneBlokSayisi", { n: String(sahneProps.bloklar.length) })}
        </p>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("sahneWebglYok")}
        </p>
      </div>
    );
  }

  return (
    <div
      style={{ height: yukseklik, borderRadius: "var(--yz-radius-card)" }}
      className="overflow-hidden"
      // SAHNE DEKORDUR, BILGI DEGIL: tasidigi her sey zaten sayfadaki
      // KPI ve listelerde metin olarak var. Ekran okuyucuya bir tuval
      // okutmanin faydasi yok; ozet metni `sr-only` olarak veriliyor.
      role="img"
      aria-label={t("sahneBlokSayisi", { n: String(sahneProps.bloklar.length) })}
    >
      <Sahne {...sahneProps} koyu={koyu} hareketVar={hareket && !mobil} />
    </div>
  );
}
