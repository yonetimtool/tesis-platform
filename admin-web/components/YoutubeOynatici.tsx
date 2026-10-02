"use client";

// (P250 §4) YOUTUBE OYNATICI — IFrame API, youtube-nocookie.com, rel=0.
//
//   * Video BITINCE `onBitti` (ENDED): cagiran adimi "izlendi" isaretler.
//     Ortada kapatilan video bu olayi URETMEZ — izlendi sayilmaz.
//   * Gizli / yerlestirmesi kapali video OYNAMAZ: oynatici hatasi yakalanir
//     ve anlasilir uyari gosterilir (panel onizlemesi bunu kullanir).
//   * YouTube erisilemezse (ag kisitli, API gelmedi) sayfa KIRILMAZ; alanda
//     mesaj gorunur.
//   * Video sonunda baska kanallarin onerileri YOK: `rel=0`.
import { useEffect, useRef, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import {
  YT_BITTI,
  YT_HOST,
  type YtOynatici,
  ytHataTuru,
  ytYukle,
} from "@/lib/youtube";

type Hata = "erisilemiyor" | "kapali" | "genel";

export function YoutubeOynatici({
  videoId,
  baslik,
  onBitti,
  onHata,
}: {
  videoId: string;
  baslik: string;
  onBitti?: () => void;
  /** Panel onizlemesi: hatayi ayrica bilmek ister. */
  onHata?: (tur: Hata) => void;
}) {
  const t = useT();
  const kap = useRef<HTMLDivElement | null>(null);
  const oynatici = useRef<YtOynatici | null>(null);
  const [hata, setHata] = useState<Hata | null>(null);
  // Geri cagrilar ref'te: oynatici bir kez kurulur, en guncel islevi cagirir.
  const bittiRef = useRef(onBitti);
  const hataRef = useRef(onHata);
  bittiRef.current = onBitti;
  hataRef.current = onHata;

  useEffect(() => {
    let iptal = false;
    setHata(null);
    ytYukle()
      .then((YT) => {
        if (iptal || !kap.current) return;
        if (oynatici.current) {
          oynatici.current.cueVideoById(videoId);
          return;
        }
        const hedef = document.createElement("div");
        kap.current.appendChild(hedef);
        oynatici.current = new YT.Player(hedef, {
          host: YT_HOST,
          videoId,
          width: "100%",
          height: "100%",
          playerVars: { rel: 0, modestbranding: 1, playsinline: 1 },
          events: {
            onStateChange: (e) => {
              if (e.data === YT_BITTI) bittiRef.current?.();
            },
            onError: (e) => {
              const tur = ytHataTuru(e.data);
              setHata(tur);
              hataRef.current?.(tur);
            },
          },
        });
      })
      .catch(() => {
        if (iptal) return;
        setHata("erisilemiyor");
        hataRef.current?.("erisilemiyor");
      });
    return () => {
      iptal = true;
    };
  }, [videoId]);

  useEffect(
    () => () => {
      oynatici.current?.destroy();
      oynatici.current = null;
    },
    [],
  );

  return (
    <div
      className="relative aspect-video w-full overflow-hidden rounded-lg"
      style={{ background: "var(--yz-surface-sunken)" }}
      data-test="youtube-oynatici"
    >
      <div ref={kap} className="absolute inset-0 [&>iframe]:h-full [&>iframe]:w-full" title={baslik} />
      {hata && (
        <div
          role="alert"
          data-test="youtube-hata"
          className="absolute inset-0 flex items-center justify-center p-6 text-center"
          style={{
            background: "var(--yz-surface-sunken)",
            color: "var(--yz-text)",
            fontSize: "var(--yz-fs-sm)",
          }}
        >
          {hata === "kapali"
            ? t("egitimVideoKapali")
            : hata === "erisilemiyor"
              ? t("egitimVideoErisilemiyor")
              : t("egitimVideoOynatilamadi")}
        </div>
      )}
    </div>
  );
}
