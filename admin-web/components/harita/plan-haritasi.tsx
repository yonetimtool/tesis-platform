"use client";

/**
 * (P160 / Asama 6) PLAN HARITASI — Leaflet, COGRAFI OLMAYAN kipte.
 *
 * =========================================================================
 * NEDEN OSM DEGIL, NEDEN `CRS.Simple`
 * =========================================================================
 * `docs/3d-yol-haritasi.md` §5 "sikayetin konumu cografidir" diyordu.
 * OLCULDU VE YANLISTI: depoda `lat/lng` tasiyan tablolar `tenant` (hava
 * durumu konumu), `checkpoint`, `scan_event`, `task_completion`,
 * `asset_checkout`. `unit_complaint` ve `unit`/`block` HIC koordinat
 * tasimiyor — bir sikayet DAIREYE baglidir, bir noktaya degil.
 *
 * Yani cografi bir harita ancak sikayet basina konum UYDURARAK
 * cizilebilirdi. Bunun yerine Leaflet'in `CRS.Simple` kipi kullaniliyor:
 * kat plani / sema haritalari icin tasarlanmis, DUZLEMSEL bir koordinat
 * sistemi. Girdi gercek veridir — `blok`, `kat`, `sira`.
 *
 * BUNUN IKI SONUCU VAR:
 *   1. KARO SUNUCUSU KARARI DUSTU. §5'te Kerem'e birakilan (a) public
 *      OSM / (b) kendi sunucumuz / (c) karosuz secimi artik gereksiz:
 *      bu haritada karo YOK, dolayisiyla dis istek de yok.
 *   2. Harita "burasi dunyada su nokta" demiyor, "bu daire bu blogun bu
 *      katinda" diyor — kayitla BIREBIR ayni iddia.
 *
 * =========================================================================
 * ERISILEBILIRLIK — harita TEK yuzey degildir
 * =========================================================================
 * Bir tuval uzerindeki dikdortgen, ekran okuyucuya hicbir sey soylemez.
 * Bu yuzden cagiran sayfa AYNI veriyi erisilebilir bir yuzeyde de tutar
 * (`/schematic`te sema izgarasi bir sekme uzaklikta). Harita burada
 * BUYUK SITELERDE pan/zoom kazandiran ALTERNATIF gorunumdur, tek
 * gorunum degil.
 *
 * Yine de harita kendi icinde de klavyeye kapali degil: Leaflet'in
 * kapsayicisi odaklanabilir ve ok tuslariyla kaydirilir; isaretciler
 * `keyboard` ile odaklanabilir ve Enter secer.
 */
import { useMemo } from "react";
import { CRS, type LatLngBoundsExpression } from "leaflet";
import { MapContainer, Rectangle, Tooltip, useMap } from "react-leaflet";

import { useT } from "@/lib/i18n/kullan";

import "leaflet/dist/leaflet.css";

/** Plandaki tek hucre — bir daire. */
export interface PlanHucresi {
  id: string;
  /** Gorunen etiket (daire no). */
  etiket: string;
  /** Duzlemsel konum: x = blok icindeki sira, y = kat. */
  x: number;
  y: number;
  /** Hucre kenar/dolgu tonu — cagiran `--yz-*-edge` degerini verir. */
  ton: string;
  /** Ipucu metni (daire + sayi). */
  ipucu: string;
  secili?: boolean;
}

/** Blok basligi — plan uzerinde bir etiket seridi. */
export interface PlanBlogu {
  ad: string;
  /** Blogun sol kenarinin x'i ve genisligi (hucre biriminde). */
  x: number;
  genislik: number;
}

const HUCRE = 1; // duzlemsel birim: bir daire 1x1

/** Haritayi icerige SIGDIRIR — sabit bir zoom uydurmak yerine olcer. */
function SinirlaraSigdir({ sinir }: { sinir: LatLngBoundsExpression }) {
  const harita = useMap();
  useMemo(() => {
    // `fitBounds` cizimden sonra cagrilmali; `useMemo` ilk cizimde bir
    // kez calisir ve `sinir` degisince tekrarlar.
    harita.fitBounds(sinir, { padding: [16, 16] });
  }, [harita, sinir]);
  return null;
}

export interface PlanHaritasiProps {
  hucreler: PlanHucresi[];
  bloklar: PlanBlogu[];
  onSec?: (id: string) => void;
  /** CSS yuksekligi. */
  yukseklik?: string;
}

export default function PlanHaritasi({
  hucreler,
  bloklar,
  onSec,
  yukseklik = "420px",
}: PlanHaritasiProps) {
  const t = useT();

  const sinir = useMemo<LatLngBoundsExpression>(() => {
    if (hucreler.length === 0) {
      return [
        [0, 0],
        [1, 1],
      ];
    }
    const xs = hucreler.map((h) => h.x);
    const ys = hucreler.map((h) => h.y);
    return [
      [Math.min(...ys), Math.min(...xs)],
      [Math.max(...ys) + HUCRE, Math.max(...xs) + HUCRE],
    ];
  }, [hucreler]);

  return (
    <div
      style={{
        height: yukseklik,
        borderRadius: "var(--yz-radius-card)",
        overflow: "hidden",
        border: "var(--yz-border-w) solid var(--yz-border)",
        background: "var(--yz-surface-sunken)",
      }}
    >
      <MapContainer
        // `CRS.Simple`: enlem/boylam YOK, duz duzlem. Zoom sinirlari
        // hucrelerin okunabilir kaldigi araliga gore.
        crs={CRS.Simple}
        minZoom={-2}
        maxZoom={4}
        center={[0, 0]}
        zoom={0}
        // Karo katmani YOK — attribution da yok. Bos bir "Leaflet"
        // baglantisi birakmak, olmayan bir veri kaynagini anmakti.
        attributionControl={false}
        style={{ width: "100%", height: "100%", background: "transparent" }}
        aria-label={t("haritaPlanEtiketi")}
      >
        <SinirlaraSigdir sinir={sinir} />

        {/* BLOK SERITLERI — hangi sutunun hangi blok oldugunu soyler. */}
        {bloklar.map((b) => (
          <Rectangle
            key={b.ad}
            bounds={[
              [-1.2, b.x],
              [-0.2, b.x + b.genislik],
            ]}
            pathOptions={{
              color: "var(--yz-border)",
              weight: 1,
              fillColor: "var(--yz-metal-2)",
              fillOpacity: 1,
            }}
          >
            <Tooltip direction="center" permanent>
              {b.ad}
            </Tooltip>
          </Rectangle>
        ))}

        {hucreler.map((h) => (
          <Rectangle
            key={h.id}
            bounds={[
              [h.y, h.x],
              [h.y + HUCRE, h.x + HUCRE],
            ]}
            pathOptions={{
              color: h.ton,
              // SECILI hucre KALIN kenar: renk yogunlugu, kalinlik
              // secimi tasir — ikisi ayri kanal (sema izgarasiyla ayni
              // karar).
              weight: h.secili ? 4 : 2,
              fillColor: "var(--yz-metal-1)",
              fillOpacity: 1,
            }}
            eventHandlers={{ click: () => onSec?.(h.id) }}
          >
            {/* Ipucu METINDIR: sayiyi renkten okumak gerekmiyor. */}
            <Tooltip direction="top">{h.ipucu}</Tooltip>
          </Rectangle>
        ))}
      </MapContainer>
    </div>
  );
}
