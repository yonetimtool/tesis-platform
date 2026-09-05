"use client";

// (P132/4b) PANODA KAMERA SERIDI — mobil `kamera_seridi.dart`in web ikizi.
//
// P43'UN KARARI AYNEN GECERLI: karo DURAGAN KARE cizer (`snapshot_url`),
// oynatici ACMAZ. Dort yayini ayni anda oynatmak pil/bant genisligi
// acisindan pahalidir ve mobilde bu yuzden reddedilmisti; tarayicida da
// ayni gerekce gecerli — ustelik burada dort ayri `hls.js` ornegi demek.
//
// TIKLAYINCA P131'IN OYNATICISI: kamera sayfasindaki ile AYNI bilesen.
// Ikinci bir oynatma yolu yazmak, iki farkli hata davranisi demekti.
//
// SERIT PANONUN SONUNDA: kare tazeleme yalniz sekme GORUNURKEN calisir
// (asagida) — arka planda birakilmis bir pano istek atmaz.
import { useEffect, useState } from "react";

import { KameraOynatici } from "@/components/KameraOynatici";
import { BolumBasligi, Kart } from "@/components/tasarim";
import { useT } from "@/lib/i18n/kullan";
import { oynatilabilirMi } from "@/lib/kamera-url";
import type { Kamera } from "@/lib/types";

/** Kare tazeleme araligi — kamera sayfasi ve mobil ile AYNI (8 sn). */
const KARE_ARALIGI_MS = 8000;

/**
 * (P213 §3-4) KARO KAYNAGI — KAMERA TURUNDEN BAGIMSIZ.
 *
 * Yoneticinin girdigi `snapshot_url` varsa o; yoksa SUNUCUNUN cektigi
 * kare (`/api/cameras/{id}/kare`). Eskiden bu yedek YALNIZ `rtsp`
 * kameralardaydi ve HLS kameralar bos kutu gosteriyordu — kullanicinin
 * gordugu davranis kamera TURUNE gore degisiyordu. Sunucu artik ikisini
 * de cekiyor (P213 §3), yani tur ayrimi burada da KALKTI.
 */
export function kareKaynagi(k: Kamera): string | null {
  return k.snapshot_url || `/api/cameras/${k.id}/kare`;
}

export function KameraSeridi({ kameralar }: { kameralar: Kamera[] }) {
  const t = useT();
  const [nesil, setNesil] = useState(0);
  const [oynatilan, setOynatilan] = useState<Kamera | null>(null);

  // (P213 §4) SECIM SUNUCUDA YAPILDI (`ana_ekranda`); burada yalnizca
  // pasif kameralar elenir. `slice(0, 4)` KALDIRILDI: siniri uc
  // uyguluyor (`KAMERA_ANA_EKRAN_SINIR`) ve iki yerde iki farkli sayi
  // tutmak, birini degistirince otekini unutmak demekti.
  const gorunen = kameralar.filter((k) => k.aktif);
  const kareCekilebilir = gorunen.some((k) => !!kareKaynagi(k));

  useEffect(() => {
    if (!kareCekilebilir) return;
    let zamanlayici: ReturnType<typeof setInterval> | null = null;
    const baslat = () => {
      if (!zamanlayici) {
        zamanlayici = setInterval(() => setNesil((n) => n + 1), KARE_ARALIGI_MS);
      }
    };
    const durdur = () => {
      if (zamanlayici) {
        clearInterval(zamanlayici);
        zamanlayici = null;
      }
    };
    const degisti = () => {
      if (document.visibilityState === "visible") {
        setNesil((n) => n + 1);
        baslat();
      } else {
        durdur();
      }
    };
    if (document.visibilityState === "visible") baslat();
    document.addEventListener("visibilitychange", degisti);
    return () => {
      durdur();
      document.removeEventListener("visibilitychange", degisti);
    };
  }, [kareCekilebilir]);

  if (gorunen.length === 0) return null;

  return (
    <section>
      <BolumBasligi baslik={t("panoKameralar")} href="/kameralar" />
      {oynatilan ? (
        <Kart className="mb-3 p-kart">
          <div className="mb-2 flex items-center justify-between gap-3">
            <h3 className="text-kartbaslik text-metin-heading">{oynatilan.ad}</h3>
            <button
              onClick={() => setOynatilan(null)}
              className="kart-kenar rounded-lg border px-3 py-1 text-sm text-metin-body hover:bg-yuzey-divider"
            >
              {t("ortakKapat")}
            </button>
          </div>
          {/* (P213 §2-4) YONETILEN CANLI YOL ONCELIKLI — kameralar
              sayfasindaki ile AYNI kural. `stream_url` kameranin KENDI
              adresidir (kimlik bilgisi tasiyabilir ve rtsp olabilir);
              vekil uzerinden gitmek onu istemciden uzak tutar. */}
          <KameraOynatici
            url={
              oynatilan.canli_yol
                ? `/api${oynatilan.canli_yol}`
                : oynatilan.restream_url || oynatilan.stream_url
            }
            mp4={
              oynatilan.tur === "mp4" &&
              !oynatilan.restream_url &&
              !oynatilan.canli_yol
            }
            poster={oynatilan.snapshot_url}
          />
        </Kart>
      ) : null}
      <div className="grid gap-izgara grid-cols-1 sm:grid-cols-2 lg:grid-cols-4">
        {gorunen.map((k) => {
          const oynar = k.oynatilabilir ?? oynatilabilirMi(k.tur, k.restream_url);
          return (
            <Kart key={k.id} className="overflow-hidden">
              <button
                type="button"
                disabled={!oynar}
                onClick={() => setOynatilan(k)}
                aria-label={oynar ? t("kameraOynat", { ad: k.ad }) : k.ad}
                className="block w-full text-start disabled:cursor-default"
              >
                <span className="relative block aspect-video bg-yuzey-placeholder">
                  {kareKaynagi(k) ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={`${kareKaynagi(k)}${kareKaynagi(k)!.includes("?") ? "&" : "?"}_k=${nesil}`}
                      alt={k.ad}
                      loading="lazy"
                      decoding="async"
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <span className="flex h-full items-center justify-center text-satiralt text-metin-muted">
                      {t("kameraKareYokWeb")}
                    </span>
                  )}
                  {!oynar ? (
                    <span className="absolute end-2 top-2 rounded-chip bg-accent-orange/12 px-2 py-0.5 text-chip text-accent-orange">
                      {t("kameraOynatilamazRozet")}
                    </span>
                  ) : null}
                </span>
                <span className="block truncate px-3 py-2 text-kartbaslik text-metin-heading">
                  {k.ad}
                </span>
              </button>
            </Kart>
          );
        })}
      </div>
    </section>
  );
}
