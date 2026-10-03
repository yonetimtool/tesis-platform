"use client";

/**
 * (P253 A2) TEK NOKTA HARITASI — tesis konumu.
 *
 * Adres aramasi ILCE duzeyinde bir aday verir; yonetici igneyi haritada
 * SURUKLEYEREK (ya da haritaya dokunarak) binanin uzerine tasir. Mobil
 * ekran ayni davranisi ayni karo dosyasiyla verir.
 *
 * Isaretci PNG degil `DivIcon`: Leaflet'in varsayilan isaretcisi dosyaya
 * baglidir ve paketleyici altinda kirilir (bkz. konum-haritasi.tsx).
 */
import "leaflet/dist/leaflet.css";

import { divIcon, type LeafletMouseEvent } from "leaflet";
import { useMemo } from "react";
import { MapContainer, Marker, useMap, useMapEvents } from "react-leaflet";

import { useT } from "@/lib/i18n/kullan";
import { useKaroUrl } from "@/lib/ozellikler";

import { KaroKatmani } from "./karo-katmani";

const SITE_ZOOM = 16;
const AZAMI_ZOOM = 19;
const IGNE_BOYU = 28;
const IGNE_SINIFI = "yz-harita-igne";

export interface TekNoktaHaritasiProps {
  lat: number;
  lon: number;
  /** Verilirse igne SURUKLENIR ve haritaya dokunmak igneyi tasir. */
  onTasi?: (lat: number, lon: number) => void;
  yukseklik?: string;
}

function Ortala({ lat, lon }: { lat: number; lon: number }) {
  const harita = useMap();
  useMemo(() => harita.setView([lat, lon], Math.max(harita.getZoom(), SITE_ZOOM)), [harita, lat, lon]);
  return null;
}

function DokununcaTasi({ onTasi }: { onTasi: (lat: number, lon: number) => void }) {
  useMapEvents({ click: (e: LeafletMouseEvent) => onTasi(e.latlng.lat, e.latlng.lng) });
  return null;
}

export default function TekNoktaHaritasi({ lat, lon, onTasi, yukseklik = "280px" }: TekNoktaHaritasiProps) {
  const t = useT();
  const url = useKaroUrl();
  const igne = useMemo(
    () =>
      divIcon({
        className: IGNE_SINIFI,
        iconSize: [IGNE_BOYU, IGNE_BOYU],
        iconAnchor: [IGNE_BOYU / 2, IGNE_BOYU],
        html: "<span></span>",
      }),
    [],
  );

  if (!url) {
    return (
      <p data-test="harita-kapali" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("haritaKapali")}
      </p>
    );
  }
  return (
    <div
      data-test="tek-nokta-haritasi"
      style={{
        isolation: "isolate",
        position: "relative",
        height: yukseklik,
        borderRadius: "var(--yz-radius-card)",
        overflow: "hidden",
        border: "var(--yz-border-w) solid var(--yz-border)",
      }}
    >
      <MapContainer
        center={[lat, lon]}
        zoom={SITE_ZOOM}
        maxZoom={AZAMI_ZOOM}
        scrollWheelZoom
        style={{ width: "100%", height: "100%" }}
        aria-label={t("haritaKonumEtiketi")}
      >
        <KaroKatmani url={url} />
        <Ortala lat={lat} lon={lon} />
        {onTasi && <DokununcaTasi onTasi={onTasi} />}
        <Marker
          position={[lat, lon]}
          icon={igne}
          draggable={!!onTasi}
          eventHandlers={
            onTasi
              ? {
                  dragend: (e) => {
                    const p = e.target.getLatLng();
                    onTasi(p.lat, p.lng);
                  },
                }
              : undefined
          }
        />
      </MapContainer>
    </div>
  );
}
