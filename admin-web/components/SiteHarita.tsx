"use client";

// (P132/4a) TESIS KONUMU HARITASI — panoda.
//
// UC KARAR, ucu de "yarim gosterme" ilkesinden:
//
// 1. KONUM YOKSA HARITA YOK. `konum_lat/lon` bos bir tesiste dunya
//    haritasi cizmek, ekrani doldurur ama hicbir sey soylemez; yerine
//    konumun NEREDE girilecegini soyleyen bir davet cizilir.
// 2. ANAHTAR KODA GOMULMEZ. Google embed anahtari `NEXT_PUBLIC_MAPS_KEY`
//    ile gelir; TANIMLI DEGILSE OpenStreetMap'in anahtarsiz gomulusune
//    dusulur ve bu ekranda YAZILIR. Sessizce OSM'ye dusmek, "Google
//    haritasi acilmadi mi?" sorusunu operasyona birakirdi.
// 3. TEMBEL YUKLENIR. `loading="lazy"` + gorunurluge kadar `iframe`
//    KURULMAZ: pano acilir acilmaz ucuncu-taraf bir kare yuklemek, ilk
//    boyamayi geciktirir ve harita cogu ziyarette hic goruntulenmez
//    (sayfanin altinda kalir).
import { useEffect, useRef, useState } from "react";

import { Kart } from "@/components/tasarim";
import { useT } from "@/lib/i18n/kullan";

export const MAPS_ANAHTARI = process.env.NEXT_PUBLIC_MAPS_KEY ?? null;

/** Gomulu harita adresi. Anahtar varsa Google, yoksa OSM. */
export function haritaAdresi(lat: number, lon: number, anahtar: string | null): string {
  if (anahtar) {
    return `https://www.google.com/maps/embed/v1/place?key=${encodeURIComponent(anahtar)}&q=${lat},${lon}&zoom=16`;
  }
  // OSM gomulusu anahtarsizdir. Kutu (bbox) ~600m: site olcegi.
  const d = 0.004;
  const bbox = [lon - d, lat - d, lon + d, lat + d].map((n) => n.toFixed(5)).join("%2C");
  return `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&layer=mapnik&marker=${lat}%2C${lon}`;
}

export function SiteHarita({
  lat,
  lon,
  ad,
  chromsuz = false,
}: {
  lat?: number | null;
  lon?: number | null;
  ad?: string | null;
  /**
   * (P133.2) KENDI KABINI CIZME — harita bir bloga GOMULU gelsin.
   *
   * Pano tesis blogunda harita BLOK GENISLIGINI doldurur ve ad/NFC sayisi
   * onun altinda durur; burasi kendi kartini + basligini cizerse ic ice
   * iki kap ve iki baslik olurdu. Diger cagri yerleri (tesis ayarlari)
   * kendi baslikli hâlini kullanmaya DEVAM eder.
   */
  chromsuz?: boolean;
}) {
  const t = useT();
  const ref = useRef<HTMLDivElement | null>(null);
  const [gorundu, setGorundu] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || gorundu) return;
    // IntersectionObserver YOKSA (cok eski tarayici) haritayi HEMEN kur:
    // ozelligi kaybetmektense bir kare erken yuklemek yeglenir.
    if (typeof IntersectionObserver === "undefined") {
      setGorundu(true);
      return;
    }
    const g = new IntersectionObserver(
      (girdiler) => {
        if (girdiler.some((x) => x.isIntersecting)) {
          setGorundu(true);
          g.disconnect();
        }
      },
      { rootMargin: "200px" },
    );
    g.observe(el);
    return () => g.disconnect();
  }, [gorundu]);

  const konumVar = typeof lat === "number" && typeof lon === "number";

  const harita = (
    <>
      <div ref={ref} className="aspect-[16/9] w-full bg-yuzey-placeholder">
        {!konumVar ? (
          <p className="flex h-full items-center justify-center px-6 text-center text-satiralt text-metin-muted">
            {t("panoKonumYok")}
          </p>
        ) : gorundu ? (
          <iframe
            title={t("panoKonumBaslik")}
            src={haritaAdresi(lat as number, lon as number, MAPS_ANAHTARI)}
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
            className="h-full w-full border-0"
          />
        ) : null}
      </div>
      {konumVar && !MAPS_ANAHTARI ? (
        // Hangi saglayicinin cizdigi GORUNUR olmali: "harita farkli
        // gorunuyor" sorusunun cevabi burada.
        <p className="px-kart py-2 text-satiralt text-metin-muted">
          {t("panoKonumOsm")}
        </p>
      ) : null}
    </>
  );

  if (chromsuz) return harita;

  return (
    <Kart className="overflow-hidden">
      <div className="flex items-center justify-between gap-3 p-kart pb-3">
        <h2 className="text-bolum text-metin-heading">{t("panoKonumBaslik")}</h2>
        {ad ? <span className="truncate text-satiralt text-metin-muted">{ad}</span> : null}
      </div>
      {harita}
    </Kart>
  );
}
