// (P250 §4) YOUTUBE IFRAME PLAYER API — tek yukleyici + kimlik ayiklama.
//
// NEDEN IFRAME API (duz <iframe> DEGIL): video BITINCE (ENDED) adim
// "izlendi" isaretlenir ve "Simdi bu adimi yap" one cikar. Duz iframe bu
// olayi vermez; API verir. Oynatici `youtube-nocookie.com` uzerinden
// yerlesir (gizlilik/KVKK): cerez yalniz kullanici oynat'a basinca.
//
// CSP (next.config.mjs): betik yalniz `https://www.youtube.com` (API),
// cerceve yalniz `https://www.youtube-nocookie.com`.

export type YtOynatici = {
  loadVideoById(id: string): void;
  cueVideoById(id: string): void;
  destroy(): void;
};

type YtNamespace = {
  Player: new (
    el: HTMLElement,
    ayar: {
      host?: string;
      videoId: string;
      width?: string | number;
      height?: string | number;
      playerVars?: Record<string, number | string>;
      events?: {
        onReady?: () => void;
        onStateChange?: (e: { data: number }) => void;
        onError?: (e: { data: number }) => void;
      };
    },
  ) => YtOynatici;
  PlayerState: { ENDED: number };
};

declare global {
  interface Window {
    YT?: YtNamespace;
    onYouTubeIframeAPIReady?: () => void;
  }
}

export const YT_API = "https://www.youtube.com/iframe_api";
export const YT_HOST = "https://www.youtube-nocookie.com";
/** Oynatici durumu: video bitti (YT.PlayerState.ENDED). */
export const YT_BITTI = 0;
/** API bu surede gelmezse "YouTube erisilemiyor" (ag kisitli). */
export const YT_ZAMAN_ASIMI_MS = 10_000;

let yukleme: Promise<YtNamespace> | null = null;

/** IFrame API'yi BIR KEZ yukler. Basarisizsa sonraki cagri yeniden dener. */
export function ytYukle(): Promise<YtNamespace> {
  if (typeof window === "undefined") return Promise.reject(new Error("ssr"));
  if (window.YT?.Player) return Promise.resolve(window.YT);
  if (yukleme) return yukleme;
  yukleme = new Promise<YtNamespace>((coz, reddet) => {
    const zaman = setTimeout(() => {
      yukleme = null;
      reddet(new Error("youtube_zaman_asimi"));
    }, YT_ZAMAN_ASIMI_MS);
    const onceki = window.onYouTubeIframeAPIReady;
    window.onYouTubeIframeAPIReady = () => {
      onceki?.();
      clearTimeout(zaman);
      if (window.YT) coz(window.YT);
    };
    const betik = document.createElement("script");
    betik.src = YT_API;
    betik.async = true;
    betik.onerror = () => {
      clearTimeout(zaman);
      yukleme = null;
      betik.remove();
      reddet(new Error("youtube_yuklenemedi"));
    };
    document.head.appendChild(betik);
  });
  return yukleme;
}

/**
 * Oynatici hata kodlari (IFrame API `onError`):
 *   2   gecersiz kimlik
 *   5   HTML5 oynatici hatasi
 *   100 video bulunamadi / GIZLI (private) ya da silinmis
 *   101, 150 sahibi YERLESTIRMEYE izin vermiyor
 * 100/101/150 kullaniciya ayni seyi soyler: "gizli olabilir ya da
 * yerlestirmeye izin verilmemis".
 */
export function ytHataTuru(kod: number): "kapali" | "genel" {
  return kod === 100 || kod === 101 || kod === 150 ? "kapali" : "genel";
}

const KIMLIK = /^[A-Za-z0-9_-]{11}$/;
const ALANLAR = new Set([
  "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
  "youtube-nocookie.com", "www.youtube-nocookie.com",
]);

/** Sunucudaki `egitim_video.youtube_kimligi`nin ikizi (panel onizlemesi). */
export function youtubeKimligi(baglanti: string): string | null {
  const ham = (baglanti ?? "").trim();
  if (KIMLIK.test(ham)) return ham;
  let u: URL;
  try {
    u = new URL(ham.includes("://") ? ham : `https://${ham}`);
  } catch {
    return null;
  }
  const alan = u.hostname.toLowerCase();
  const yol = u.pathname.split("/").filter(Boolean);
  let aday: string | null = null;
  if (alan === "youtu.be") aday = yol[0] ?? null;
  else if (ALANLAR.has(alan)) {
    if (u.pathname === "/watch") aday = u.searchParams.get("v");
    else if (yol.length >= 2 && ["shorts", "embed", "live", "v"].includes(yol[0])) aday = yol[1];
  }
  return aday && KIMLIK.test(aday) ? aday : null;
}
