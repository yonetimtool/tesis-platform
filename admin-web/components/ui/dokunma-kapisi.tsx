"use client";

/**
 * (P169 §5) DOKUNMA KAPISI — tuval/harita tuzagina karsi tek mekanizma.
 *
 * =========================================================================
 * SORUN: PARMAK TUVALE DUSUNCE SAYFA KAYMIYORDU
 * =========================================================================
 * Hem `OrbitControls` (3D) hem Leaflet (harita) tek parmak surtmesini
 * KENDI jesti sayar ve dokunusu yutar. Tam genislikte, sayfanin ortasinda
 * duran boyle bir alanin uzerinden asagi kaydirmak isteyen kullanicinin
 * parmagi oraya dustugunde sayfa KAYMIYOR, sahne donuyor ya da harita
 * kayiyordu — sayfanin alt yarisi telefondan ULASILMAZ hale geliyordu.
 *
 * Fare tekerlegi olan bir cihazda bu tuzak YOKTUR; o yuzden masaustunde
 * hic gorulmedi ve gorulmesi de mumkun degildi.
 *
 * =========================================================================
 * COZUM
 * =========================================================================
 * Kaba isaretcide (`pointer: coarse`) icerigin uzerinde SEFFAF bir katman
 * durur. Katman dokunusa MUDAHALE ETMEZ — uzerinde hicbir dokunma isleyicisi
 * yok — dolayisiyla tarayici sayfayi normal kaydirir. Kullanici BILEREK
 * dokunursa katman kalkar ve icerik tam etkilesime acilir.
 *
 * CIKIS DUGMESI ZORUNLU: kapi acildiktan sonra icerik yine dokunuslari
 * yutar. Cikis yolu birakmadan acmak, tuzagi kapiyla birlikte geri kurmak
 * olurdu.
 *
 * TEK KAPI, IKI TUKETICI: 3D yukleyicisi ve harita yukleyicisi ayni
 * bileseni kullanir. Ikinci bir kapi yazmak, ayni davranisi iki yerde
 * tutmak olurdu (bu iki yukleyicinin `ssr:false` karari icin de gecerli
 * olan kural).
 *
 * FARE DEGISMEDI: `useDokunmatik` yanlissa hicbir katman cizilmez.
 */
import { useState, type ReactNode } from "react";

import { useT } from "@/lib/i18n/kullan";
import { useDokunmatik } from "@/lib/kirilma-kullan";

export function DokunmaKapisi({
  children,
  yukseklik,
}: {
  children: ReactNode;
  /** Cocuk `h-full` ise sarmal yuksekligi buradan alir; aksi halde
   *  cocugun kendi yuksekligi gecerlidir. */
  yukseklik?: string;
}) {
  const t = useT();
  const dokunmatik = useDokunmatik();
  const [etkin, setEtkin] = useState(false);

  return (
    <div className="relative" style={yukseklik ? { height: yukseklik } : undefined}>
      {children}

      {dokunmatik && !etkin && (
        <button
          type="button"
          onClick={() => setEtkin(true)}
          className="odak-ic absolute inset-0 flex items-end justify-center pb-3"
          style={{ borderRadius: "var(--yz-radius-card)" }}
        >
          <span
            className="rounded-full px-3 py-2"
            style={{
              fontSize: "var(--yz-fs-sm)",
              color: "var(--yz-text)",
              background: "var(--yz-surface-1)",
              boxShadow: "var(--yz-raised)",
            }}
          >
            {t("sahneDokunAktif")}
          </span>
        </button>
      )}

      {dokunmatik && etkin && (
        <button
          type="button"
          onClick={() => setEtkin(false)}
          // (P214) HAM `z-[400]` KALDIRILDI. Leaflet'in pane degerini
          // (400) asmak icin konmustu ama kontrolleri (1000) zaten
          // asamiyordu — yani sorunu cozmuyor, yalnizca cozuyor gibi
          // duruyordu. Artik harita KENDI yiginlama baglamina hapsedildigi
          // icin (bkz. harita bilesenleri) bu dugme onun disinda kalir ve
          // olcekteki en dusuk "ustte dursun" degeri yeterlidir.
          className="odak-ic absolute end-2 top-2 rounded-full px-3 py-2"
          style={{
            zIndex: "var(--yz-z-sticky)" as unknown as number,
            fontSize: "var(--yz-fs-sm)",
            color: "var(--yz-text)",
            background: "var(--yz-surface-1)",
            boxShadow: "var(--yz-raised)",
          }}
        >
          {t("sahneKaydirmayaDon")}
        </button>
      )}
    </div>
  );
}
