"use client";

/**
 * (P160) KONUM HARITASI — Leaflet + OpenStreetMap karolari.
 *
 * =========================================================================
 * NEDEN BURADA COGRAFI HARITA MESRU
 * =========================================================================
 * Sikayet haritasinda (`plan-haritasi.tsx`) cografi kip REDDEDILMISTI:
 * sikayet bir DAIREYE baglidir ve koordinat tasimaz. Burada durum TERSI —
 * `checkpoint.gps_lat/gps_lng` GERCEK alanlardir ve sahada doldurulur.
 * "Bu nokta binanin arkasinda mi, bahcede mi" sorusu gercekten cografidir
 * ve bir plan semasi onu yanitlayamaz.
 *
 * =========================================================================
 * KARO SUNUCUSU: PUBLIC OSM — KERem'IN KARARI
 * =========================================================================
 * `docs/3d-yol-haritasi.md` §5'te uc secenek vardi; secim (a) public OSM.
 * Bunun getirdigi iki YUKUMLULUK kodda karsilaniyor:
 *
 *   1. ATTRIBUTION ZORUNLUDUR. OSM karolarini kullanan her harita
 *      "© OpenStreetMap katkida bulunanlar" ibaresini GORUNUR sekilde
 *      tasimak zorunda (ODbL + karo kullanim politikasi). Bu yuzden
 *      `attributionControl` ACIK ve metin sozlukten geliyor.
 *   2. KARO SUNUCUSU DEGISTIRILEBILIR OLMALI. OSM'nin public karolari bir
 *      NEZAKET hizmetidir; yogun/toplu kullanim politikaya aykiridir.
 *      Panel kullanimi dusuk hacimli (yalniz yonetici) ama bir gun kendi
 *      sunucumuza gecilirse bu TEK SATIRLIK bir ayar olmali —
 *      `NEXT_PUBLIC_KARO_URL` tanimliysa o kullanilir. Kodu yeniden
 *      yazmak gerekmesin diye bastan boyle kuruldu.
 *
 * =========================================================================
 * ISARETCI OLARAK `CircleMarker` — bilincli
 * =========================================================================
 * Leaflet'in varsayilan isaretcisi PNG dosyalarina baglidir ve paketleyici
 * altinda yolu bozulur (klasik `marker-icon.png` 404'u). `CircleMarker`
 * bir VEKTORDUR: dosya istemez, rengi durumdan gelir ve `--yz-*-edge`
 * ailesiyle ayni tonlari kullanir.
 */
import { useMemo } from "react";
import type { LatLngBoundsExpression, LatLngExpression } from "leaflet";
import { CircleMarker, MapContainer, TileLayer, Tooltip, useMap } from "react-leaflet";

import { useT } from "@/lib/i18n/kullan";

import "leaflet/dist/leaflet.css";

/** Haritadaki tek nokta. */
export interface KonumNoktasi {
  id: string;
  ad: string;
  lat: number;
  lon: number;
  /** Kenar/dolgu tonu — cagiran `--yz-*-edge` degerini verir. */
  ton: string;
  /** Ipucu metni (ad + durum). */
  ipucu: string;
}

/** OSM public karo adresi — UCLUDE DIZE YAZILMAZ (depo kurali
 *  `sabit-metin`), sabit modul duzeyinde durur. Cevrilecek bir metin
 *  degil, bir UC ADRESI. */
const OSM_KARO = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
/** Karo sunucusu — ayarla degistirilebilir (bkz. dosya basi). */
const KARO_URL = process.env.NEXT_PUBLIC_KARO_URL ?? OSM_KARO;
/** OSM karolarinin azami yakinlastirmasi. */
const AZAMI_ZOOM = 19;
/** Tek nokta varken kullanilan olcek — site olcegi. */
const TEK_NOKTA_ZOOM = 17;
/** Isaretci halesi — karo uzerinde ayirt edilebilirlik icin. */
const HALE = "var(--yz-on-fill)";

/** Haritayi noktalara SIGDIRIR — sabit bir olcek uydurmak yerine olcer. */
function NoktalaraSigdir({ sinir }: { sinir: LatLngBoundsExpression | null }) {
  const harita = useMap();
  useMemo(() => {
    if (sinir) harita.fitBounds(sinir, { padding: [24, 24], maxZoom: TEK_NOKTA_ZOOM });
  }, [harita, sinir]);
  return null;
}

export interface KonumHaritasiProps {
  noktalar: KonumNoktasi[];
  onSec?: (id: string) => void;
  yukseklik?: string;
}

export default function KonumHaritasi({
  noktalar,
  onSec,
  yukseklik = "420px",
}: KonumHaritasiProps) {
  const t = useT();

  const sinir = useMemo<LatLngBoundsExpression | null>(() => {
    if (noktalar.length === 0) return null;
    const enler = noktalar.map((n) => n.lat);
    const boylar = noktalar.map((n) => n.lon);
    return [
      [Math.min(...enler), Math.min(...boylar)],
      [Math.max(...enler), Math.max(...boylar)],
    ];
  }, [noktalar]);

  // Merkez yalniz ILK cizim icin; `NoktalaraSigdir` hemen ardindan
  // gercek sinirlara oturur.
  const merkez: LatLngExpression = noktalar.length
    ? [noktalar[0].lat, noktalar[0].lon]
    : [0, 0];

  return (
    <div
      style={{
        height: yukseklik,
        borderRadius: "var(--yz-radius-card)",
        overflow: "hidden",
        border: "var(--yz-border-w) solid var(--yz-border)",
      }}
    >
      <MapContainer
        center={merkez}
        zoom={TEK_NOKTA_ZOOM}
        maxZoom={AZAMI_ZOOM}
        scrollWheelZoom
        style={{ width: "100%", height: "100%" }}
        aria-label={t("haritaKonumEtiketi")}
      >
        {/* ATTRIBUTION KALDIRILAMAZ — OSM karolarini kullanmanin sarti. */}
        <TileLayer url={KARO_URL} maxZoom={AZAMI_ZOOM} attribution={t("haritaOsmKatki")} />
        <NoktalaraSigdir sinir={sinir} />

        {noktalar.map((n) => (
          <CircleMarker
            key={n.id}
            center={[n.lat, n.lon]}
            radius={9}
            // BEYAZ HALE + RENKLI DOLGU. Karo goruntusu keyfidir; bir
            // rengin karo uzerindeki kontrasti ONCEDEN OLCULEMEZ. Beyaz
            // cember isaretciyi zeminden ayirir, renk ise durumu tasir —
            // ve durum ipucunda METIN olarak da yaziyor.
            pathOptions={{
              color: HALE,
              weight: 3,
              fillColor: n.ton,
              fillOpacity: 1,
            }}
            eventHandlers={{ click: () => onSec?.(n.id) }}
          >
            {/* Ipucu METINDIR: durumu renkten okumak gerekmiyor. */}
            <Tooltip direction="top">{n.ipucu}</Tooltip>
          </CircleMarker>
        ))}
      </MapContainer>
    </div>
  );
}
