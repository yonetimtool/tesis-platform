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
import { useBantEnAz, useMedya } from "@/lib/kirilma-kullan";

import { DokunmaKapisi } from "../ui/dokunma-kapisi";
import { Iskelet } from "../ui/durumlar";
import type { BinaSahnesiProps } from "./bina-sahnesi";
import type { RotaSahnesiProps } from "./rota-sahnesi";

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

// (P160 / Asama 5) IKINCI SAHNE, AYNI YUKLEYICI. `3d-yol-haritasi.md` §4:
// "BinaSahnesi ile AYNI yukleyiciyi kullanir — ikinci bir tembel yukleme
// mekanizmasi yazilmayacak." Asagidaki `useSahneOrtami` da o yuzden
// paylasiliyor: WebGL olcumu, tema, hareket tercihi ve mobil karari
// sahne basina TEKRARLANMAZ.
const RotaSahne = dynamic(() => import("./rota-sahnesi"), {
  ssr: false,
  loading: () => <Iskelet className="h-full w-full" />,
});

/**
 * Sahne ORTAMI — iki sahnenin de ihtiyac duydugu istemci olcumleri.
 *
 * TUM OLCUMLER ISTEMCIDE: `window` sunucuda yok ve ilk kare sunucuda
 * ciziliyor. `hazir` bayragi olmadan sunucu/istemci farki hidrasyon
 * uyusmazligi uretirdi.
 */
function useSahneOrtami() {
  const [hazir, setHazir] = useState(false);
  const [destek, setDestek] = useState(true);
  const [koyu, setKoyu] = useState(false);

  // (P169 §4) OLCUMLER ARTIK CANLI VE TEK KAYNAKTAN.
  //
  // Eski surum ikisini de `useEffect` icinde BIR KEZ okuyordu: telefonu
  // yatay cevirmek ya da pencereyi buyutmek sahneyi ESKI kararda
  // birakiyordu — 380 px'te acilip masaustune buyutulen bir pencerede
  // maket duragan kaliyor, tersinde ise dar ekranda tam sahne calisip
  // pili yakiyordu. `useMedya` sorguyu DINLER.
  //
  // ESIK 768'DEN 1024'E TASINDI. 768 bu projede baska hicbir yerde
  // gecmeyen bir sayiydi; `lib/kirilma-noktasi.ts` kirilma sinirlarinin
  // TEK kaynagi ve 1024 = "tablet dikeyin ustu". Degisen aralik
  // (768-1023) tanim geregi TABLET DIKEYDIR, masaustu degil; masaustu
  // bandinda (>=1024) sahne oldugu gibi kaliyor.
  const dar = !useBantEnAz("lg");
  const hareket = !useMedya("(prefers-reduced-motion: reduce)");

  useEffect(() => {
    setDestek(webglVar());
    setKoyu(document.documentElement.classList.contains("dark"));
    setHazir(true);
  }, []);

  // (P161) TEMA ARTIK CANLI IZLENIYOR. Eski surum temayi BIR KEZ okuyordu;
  // basliktaki anahtar temayi cevirince sahne eski isikta kaliyordu —
  // brief §4'un "3D sahne isiklandirmasi da temaya baglanacak" maddesi
  // tam olarak bunu kastediyor. `MutationObserver` kok siniftaki degisimi
  // dinler; olay yayini icin ayri bir kanal acmaya gerek yok.
  useEffect(() => {
    const kok = document.documentElement;
    const gozcu = new MutationObserver(() => setKoyu(kok.classList.contains("dark")));
    gozcu.observe(kok, { attributes: true, attributeFilter: ["class"] });
    return () => gozcu.disconnect();
  }, []);

  // `sade`: mobil VEYA hareket azaltma. Ikisinde de yumusak golge,
  // yansima ve isik seridi kapanir — biri pil, digeri rahatsizlik icin.
  return { hazir, destek, koyu, hareketVar: hareket && !dar, sade: dar || !hareket };
}

export function BinaSahnesiYukleyici(
  props: Omit<BinaSahnesiProps, "koyu" | "hareketVar" | "sade"> & {
    /** Sahne yuksekligi (CSS). */
    yukseklik?: string;
  },
) {
  const t = useT();
  const { yukseklik = "320px", ...sahneProps } = props;
  const { hazir, destek, koyu, hareketVar, sade } = useSahneOrtami();

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

  // SAHNE DEKORDUR, BILGI DEGIL: tasidigi her sey zaten sayfadaki KPI ve
  // listelerde metin olarak var. Ekran okuyucuya bir tuval okutmanin
  // faydasi yok; ozet metni `aria-label` ile veriliyor.
  return (
    <DokunmaKapisi yukseklik={yukseklik}>
      <div
        className="h-full w-full overflow-hidden"
        style={{ borderRadius: "var(--yz-radius-card)" }}
        role="img"
        aria-label={t("sahneBlokSayisi", { n: String(sahneProps.bloklar.length) })}
      >
        <Sahne {...sahneProps} koyu={koyu} hareketVar={hareketVar} sade={sade} />
      </div>
    </DokunmaKapisi>
  );
}

/* ==================================================================== */

/**
 * ROTA SAHNESI YUKLEYICISI — devriye rotasi / nokta durumu.
 *
 * GERI DUSUS METNI FARKLI ve bu onemli: bina sahnesinde "kac blok" bilgi
 * tasiyordu; burada tasidigi sey ILERLEME. WebGL yoksa kullanici o
 * ilerlemeyi yine gormeli.
 */
export function RotaSahnesiYukleyici(
  props: Omit<RotaSahnesiProps, "koyu" | "hareketVar"> & { yukseklik?: string },
) {
  const t = useT();
  const { yukseklik = "260px", ...sahneProps } = props;
  const { hazir, destek, koyu, hareketVar } = useSahneOrtami();

  const okutulan = sahneProps.noktalar.filter((n) => n.durum === "okutuldu").length;
  const ozet = t("rotaSahneOzet", {
    okutulan: String(okutulan),
    toplam: String(sahneProps.noktalar.length),
  });

  if (!hazir) {
    return <Iskelet className="w-full" {...{ style: { height: yukseklik } }} />;
  }

  if (!destek) {
    return (
      <div
        className="flex w-full flex-col items-center justify-center gap-2 p-6 text-center"
        style={{
          height: yukseklik,
          borderRadius: "var(--yz-radius-card)",
          background: "var(--yz-surface-sunken)",
          boxShadow: "var(--yz-sunken)",
        }}
      >
        <p style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>{ozet}</p>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("sahneWebglYok")}
        </p>
      </div>
    );
  }

  // SAHNE DEKORDUR: her noktanin adi ve durumu sayfadaki listede METIN
  // olarak zaten var. Tuvale okunacak bir sey yok; ozet `aria-label`ta.
  return (
    <DokunmaKapisi yukseklik={yukseklik}>
      <div
        className="h-full w-full overflow-hidden"
        style={{ borderRadius: "var(--yz-radius-card)" }}
        role="img"
        aria-label={ozet}
      >
        <RotaSahne {...sahneProps} koyu={koyu} hareketVar={hareketVar} />
      </div>
    </DokunmaKapisi>
  );
}
