"use client";

/**
 * (P253 A2) HARITA KARO KATMANI — KENDI PMTiles DOSYAMIZ.
 *
 * Karolar ucuncu bir firmadan DEGIL, kendi depomuzdaki tek bir Turkiye
 * kesitinden (`karo` kovasi, Protomaps PMTiles, HTTP range) gelir. Adres
 * sunucunun `GET /ozellikler` yanitindadir (`harita_karo_url`): dosya
 * yenilenince web'de kod degismez. Mobil AYNI dosyayi okur.
 *
 * KVKK: kullanicinin IP'si ve baktigi koordinat ucuncu tarafa gitmez
 * (eskiden `tile.openstreetmap.org`a gidiyordu).
 *
 * ATIF ZORUNLU (ODbL): "© OpenStreetMap katkicilari" haritanin kosesinde
 * HER ZAMAN gorunur; metin sozlukten gelir.
 *
 * Vektor karo istemcide cizilir (`protomaps-leaflet`); Leaflet ve mevcut
 * isaretciler AYNEN kalir. Tema koyuysa koyu cesit.
 */
import type { Layer } from "leaflet";
import { leafletLayer } from "protomaps-leaflet";
import { useEffect, useState } from "react";
import { useMap } from "react-leaflet";

import { useT } from "@/lib/i18n/kullan";

/** Kesitin azami yakinlastirmasi — ustu istemcide buyutulur. */
export const KARO_AZAMI_VERI_ZOOM = 15;
const ACIK = "light";
const KOYU = "dark";

function koyuTema(): boolean {
  return typeof document !== "undefined" && document.documentElement.classList.contains("dark");
}

export function KaroKatmani({ url }: { url: string }) {
  const harita = useMap();
  const t = useT();
  const [koyu, setKoyu] = useState(koyuTema);

  useEffect(() => {
    const kok = document.documentElement;
    const gozcu = new MutationObserver(() => setKoyu(kok.classList.contains("dark")));
    gozcu.observe(kok, { attributes: true, attributeFilter: ["class"] });
    return () => gozcu.disconnect();
  }, []);

  useEffect(() => {
    // Paketin donus tipi Leaflet `GridLayer` alt sinifidir ama tip
    // bildirimi `Layer` olarak yazilmamis; calisma zamaninda Layer'dir.
    const katman = leafletLayer({
      url,
      flavor: koyu ? KOYU : ACIK,
      lang: t("haritaKaroDili"),
      maxDataZoom: KARO_AZAMI_VERI_ZOOM,
      attribution: t("haritaOsmKatki"),
    }) as unknown as Layer;
    katman.addTo(harita);
    return () => {
      harita.removeLayer(katman);
    };
  }, [harita, url, koyu, t]);

  return null;
}
