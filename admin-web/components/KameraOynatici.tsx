"use client";

// (P131) KAMERA OYNATICI — HLS + MP4, tarayıcı farkı gizlenmeden.
//
// P126.5'te oynatma BİLEREK yapılmamıştı: `stream_url` HLS'tir; Safari
// `.m3u8`i yerel oynatır ama Chrome/Firefox oynatmaz ve `<video>` sessizce
// siyah kalır. `hls.js` bir BAĞIMLILIK KARARIYDI ve tek başına
// alınmamıştı. P131 ile karar geldi: eklendi.
//
// ÜÇ YOL, HANGİSİNİN SEÇİLDİĞİ GÖRÜNÜR OLMALI:
//   1. Tarayıcı HLS'i YERELDEN oynatıyorsa (Safari/iOS) `hls.js` HİÇ
//      yüklenmez — 400 KB'lık kütüphaneyi gereksiz indirmek, mobil veriyle
//      giren bir yöneticiye fatura kesmektir.
//   2. Oynatmıyorsa `hls.js` DİNAMİK import edilir (sayfa açılışında değil,
//      oynat'a basınca) — kamera sayfasını hiç açmayan kullanıcı bu
//      maliyeti ödemez.
//   3. MP4 doğrudan `<video src>`.
//
// HATA YUTULMAZ: yayın açılmazsa kullanıcı "siyah kare" değil, NE olduğunu
// söyleyen bir kutu görür. Sessiz siyah ekran, teşhisi kameraya
// gönderirdi — oysa sorun ağ/adres/kodek olabilir.
import { useEffect, useRef, useState } from "react";

import { useT } from "@/lib/i18n/kullan";

type Props = {
  // Oynatılacak adres — restream varsa ÇAĞIRAN onu geçirir (P17).
  url: string;
  // `mp4` ise doğrudan `<video src>`; değilse HLS yolu denenir.
  mp4: boolean;
  poster?: string | null;
};

// Tarayıcı HLS'i YERELDEN oynatabiliyor mu? (Safari/iOS)
function yerelHlsVar(video: HTMLVideoElement): boolean {
  return video.canPlayType("application/vnd.apple.mpegurl") !== "";
}

export function KameraOynatici({ url, mp4, poster }: Props) {
  const t = useT();
  const ref = useRef<HTMLVideoElement | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [yol, setYol] = useState<"mp4" | "yerel-hls" | "hlsjs" | null>(null);

  useEffect(() => {
    const video = ref.current;
    if (!video) return;
    setHata(null);

    if (mp4) {
      video.src = url;
      setYol("mp4");
      return;
    }

    if (yerelHlsVar(video)) {
      // Safari: kütüphane YOK. `hls.js` de zaten burada kendini devre dışı
      // bırakırdı; erken dönmek indirmeyi de engelliyor.
      video.src = url;
      setYol("yerel-hls");
      return;
    }

    // Chrome/Firefox: kütüphane İSTENDİĞİNDE gelir.
    let iptal = false;
    let yikici: (() => void) | null = null;
    (async () => {
      try {
        const { default: Hls } = await import("hls.js");
        if (iptal || !ref.current) return;
        if (!Hls.isSupported()) {
          setHata(t("kameraOynatilamiyor"));
          return;
        }
        const hls = new Hls({ enableWorker: true });
        hls.loadSource(url);
        hls.attachMedia(ref.current);
        hls.on(Hls.Events.ERROR, (_olay, veri) => {
          // YALNIZ ÖLÜMCÜL hata gösterilir: hls.js geçici ağ/parça
          // hatalarını kendi kurtarır ve her birini kullanıcıya
          // göstermek, oynayan bir yayında sürekli uyarı demekti.
          if (veri.fatal) setHata(t("kameraYayinAcilamadi"));
        });
        setYol("hlsjs");
        yikici = () => hls.destroy();
      } catch {
        // Kütüphane indirilemedi (ağ/CSP). Sessiz kalmak siyah kare
        // demekti.
        if (!iptal) setHata(t("kameraYayinAcilamadi"));
      }
    })();

    return () => {
      iptal = true;
      yikici?.();
    };
  }, [url, mp4, t]);

  // HANGİ YOLUN SEÇİLDİĞİ GÖRÜNÜR: destek sorusunda ("bende açılmıyor")
  // ilk sorulacak şey budur. `MP4` bir MARKA/BİÇİM ADIDIR ve çevrilmez —
  // sözlüğe koymak yedi dilde aynı değeri tutmak ve "TR kopyası" taramasına
  // gerekçe yazmak demekti.
  const yolEtiketi: Record<string, string> = {
    mp4: "MP4",
    "yerel-hls": t("kameraHlsYerel"),
    hlsjs: t("kameraHlsKutuphane"),
  };

  return (
    <div className="space-y-2">
      <video
        ref={ref}
        poster={poster ?? undefined}
        controls
        playsInline
        muted
        className="w-full rounded-lg bg-black"
        onError={() => setHata(t("kameraYayinAcilamadi"))}
      />
      {hata && (
        <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {hata}
        </p>
      )}
      {yol && !hata && (
        <p className="text-xs text-metin-muted" data-yol={yol}>
          {yolEtiketi[yol]}
        </p>
      )}
    </div>
  );
}
