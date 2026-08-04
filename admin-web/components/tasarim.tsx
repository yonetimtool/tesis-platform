"use client";

// (P132) WEB TASARIM SISTEMI — mobil `home_tokens.dart`in bilesen karsiligi.
//
// NEDEN TEK DOSYA: sikayet "web mobilin yaninda yarim kalmis duruyor"du ve
// sebebi sayfa basina yeniden icat edilen kart/rozet/bos-durum kaliplariydi.
// Kart yariçapi bir sayfada 12, otekinde 8; bos durum bir yerde cıplak
// spinner, otekinde duz metin. Burasi o kaliplarin TEK yeridir.
//
// HAM RENK/OLCU YAZILMAZ: hepsi Tailwind token'larindan
// (`rounded-kart`, `bg-yuzey-card`, `text-metin-muted`...) gelir ve o
// token'lar mobil dosyadan kopyalanmistir. Bir deger degisecekse
// `tailwind.config.ts` degisir, burasi degil.
import Link from "next/link";
import type { ReactNode } from "react";

import { useT } from "@/lib/i18n/kullan";

// Vurgu paleti — mobil `HomeTokens` ile AYNI kume. Metin degil KIMLIK.
export type Vurgu = "blue" | "green" | "orange" | "purple" | "red";

// IKON RENGI — HAM vurgu (dolgu/ikon icin dogru; kontrast sorunu METINDE).
const VURGU_IKON: Record<Vurgu, string> = {
  blue: "text-accent-blue",
  green: "text-accent-green",
  orange: "text-accent-orange",
  purple: "text-accent-purple",
  red: "text-accent-red",
};

// METIN RENGI — okunur ton (bkz. tailwind `vurguInk`). Koyu temada
// globals.css'teki ".dark" vurgu kurallariyla acik tona doner.
const VURGU_METIN: Record<Vurgu, string> = {
  blue: "text-vurguInk-blue",
  green: "text-vurguInk-green",
  orange: "text-vurguInk-orange",
  purple: "text-vurguInk-purple",
  red: "text-vurguInk-red",
};

// TINT ZEMIN %12 — mobil `HomeTokens.tint` ile ayni opaklik. Tailwind'in
// alfa sozdizimi derleme aninda cozulur; sinif adlari TAM yazilmali
// (dinamik birlestirme JIT tarafindan goruLMEZ).
const VURGU_TINT: Record<Vurgu, string> = {
  blue: "bg-accent-blue/12",
  green: "bg-accent-green/12",
  orange: "bg-accent-orange/12",
  purple: "bg-accent-purple/12",
  red: "bg-accent-red/12",
};

// Beyaz kart — radius 16 + 1px cok hafif kenarlik, GOLGE YOK (mobil karar).
const KART_VARSAYILAN_ETIKET = "div" as const;

export function Kart({
  children,
  className = "",
  as: Etiket = KART_VARSAYILAN_ETIKET,
}: {
  children: ReactNode;
  className?: string;
  as?: "div" | "section" | "article" | "li";
}) {
  return (
    <Etiket
      className={`kart-kenar rounded-kart border bg-yuzey-card ${className}`}
    >
      {children}
    </Etiket>
  );
}

/** Tint zeminli ikon konteyneri — sistemin imza ogesi.
 *
 *  56x56 / radius 14 / %12 tint zemin / 26px vurgu ikon. Mobilde hizli
 *  erisim kartlarinin, web'de istatistik kartlarinin ve bolum basliklarinin
 *  cipasi. `kucuk` (40px) liste satirlari icindir. */
export function IkonKutu({
  vurgu = "blue",
  kucuk = false,
  children,
}: {
  vurgu?: Vurgu;
  kucuk?: boolean;
  children: ReactNode;
}) {
  const boyut = kucuk ? "h-satirikon w-satirikon" : "h-ikonkutu w-ikonkutu";
  const yaricap = kucuk ? "rounded-full" : "rounded-ikon";
  return (
    <span
      aria-hidden="true"
      className={`inline-flex shrink-0 items-center justify-center ${boyut} ${yaricap} ${VURGU_TINT[vurgu]} ${VURGU_IKON[vurgu]}`}
    >
      {children}
    </span>
  );
}

// Durum cipi — radius 8, 11pt semibold, tint zemin.
export function Chip({
  vurgu = "blue",
  children,
}: {
  vurgu?: Vurgu;
  children: ReactNode;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-chip px-2 py-0.5 text-chip ${VURGU_TINT[vurgu]} ${VURGU_METIN[vurgu]}`}
    >
      {children}
    </span>
  );
}

// Bolum basligi + istege bagli "tumunu gor" baglantisi.
//
// Baglanti YALNIZ tam listesi olan bolumde cizilir — mobilde hizli ozet
// bolumu bilincli olarak baglantisizdir (gidilecek bir "hepsi" ekrani yok).
export function BolumBasligi({
  baslik,
  href,
  sag,
}: {
  baslik: string;
  href?: string;
  sag?: ReactNode;
}) {
  const t = useT();
  return (
    <div className="mb-3 flex items-center justify-between gap-3">
      <h2 className="text-bolum text-metin-heading">{baslik}</h2>
      {href ? (
        <Link
          href={href}
          className="shrink-0 text-sm font-medium text-primary hover:underline"
        >
          {t("tasarimTumunuGor")}
        </Link>
      ) : (
        sag
      )}
    </div>
  );
}

// Istatistik karti — ikon + deger + etiket (mobil `StatTile`).
export function IstatistikKarti({
  vurgu = "blue",
  ikon,
  deger,
  etiket,
  href,
}: {
  vurgu?: Vurgu;
  ikon: ReactNode;
  deger: string;
  etiket: string;
  href?: string;
}) {
  const govde = (
    <Kart className="flex items-center gap-3 p-kart transition-colors hover:bg-yuzey-divider/60">
      <IkonKutu vurgu={vurgu}>{ikon}</IkonKutu>
      <span className="min-w-0">
        <span className="block truncate text-deger text-metin-heading">{deger}</span>
        <span className="block truncate text-etiket text-metin-muted">{etiket}</span>
      </span>
    </Kart>
  );
  // Rotasi OLMAYAN kutu baglanti YAPILMAZ: tiklanabilir gorunup hicbir sey
  // yapmayan bir kart, "bozuk" izlenimi uretir (mobilde ayni karar).
  return href ? (
    <Link href={href} className="block">
      {govde}
    </Link>
  ) : (
    govde
  );
}

// Liste satiri — kucuk yuvarlak ikon + baslik + alt metin + sag bilgi.
export function HareketSatiri({
  vurgu = "blue",
  ikon,
  baslik,
  alt,
  sag,
}: {
  vurgu?: Vurgu;
  ikon: ReactNode;
  baslik: string;
  alt?: string;
  sag?: ReactNode;
}) {
  return (
    <li className="flex items-center gap-3 border-b border-yuzey-divider px-kart py-3 last:border-b-0">
      <IkonKutu vurgu={vurgu} kucuk>
        {ikon}
      </IkonKutu>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-kartbaslik text-metin-heading">{baslik}</span>
        {alt ? <span className="block truncate text-satiralt text-metin-muted">{alt}</span> : null}
      </span>
      {sag ? <span className="shrink-0 text-satiralt text-metin-muted">{sag}</span> : null}
    </li>
  );
}

// --------------------------------------------------------------------------
// DURUMLAR — bos / yukleniyor / hata. UCU DE AYNI YERDE.
//
// Eskiden her sayfa kendi cozumunu yaziyordu: kimi cıplak bir spinner, kimi
// "Yükleniyor..." metni, kimi hicbir sey. Sonuc: ayni urunun uc farkli
// bekleme deneyimi. Uc bilesen de KART kaligina oturur, yani bekleyen alan
// dolduktan sonraki hâliyle ayni YERI kaplar (zipLama olmaz).
// --------------------------------------------------------------------------

// Iskelet — yuklenirken. `satir` kadar gri seritten olusur.
export function Yukleniyor({ satir = 3, baslik }: { satir?: number; baslik?: string }) {
  const t = useT();
  return (
    <Kart className="p-kart">
      {baslik ? <p className="mb-3 text-bolum text-metin-heading">{baslik}</p> : null}
      {/* Ekran okuyucu icin DURUM, gozle gorunen icin ISKELET: ikisi ayri
          kanal. Yalniz animasyonlu seritler birakmak, gormeyene hicbir sey
          soylemezdi. */}
      <span className="sr-only" role="status">
        {t("ortakYukleniyor")}
      </span>
      <span aria-hidden="true" className="block space-y-2.5">
        {Array.from({ length: satir }).map((_, i) => (
          <span
            key={i}
            className="block h-4 animate-pulse rounded bg-yuzey-placeholder"
            style={{ width: `${100 - i * 12}%` }}
          />
        ))}
      </span>
    </Kart>
  );
}

// Bos durum — "davet", olu ekran degil (yazi kilavuzu).
export function BosDurum({
  baslik,
  aciklama,
  eylem,
}: {
  baslik: string;
  aciklama?: string;
  eylem?: ReactNode;
}) {
  return (
    <Kart className="p-8 text-center">
      <p className="text-kartbaslik text-metin-heading">{baslik}</p>
      {aciklama ? <p className="mt-1 text-satiralt text-metin-muted">{aciklama}</p> : null}
      {eylem ? <div className="mt-4 flex justify-center">{eylem}</div> : null}
    </Kart>
  );
}

// Hata durumu — NE oldugu + NE yapilacagi. Ozur dilemez, belirsiz kalmaz.
export function HataDurumu({
  mesaj,
  onYenile,
}: {
  mesaj?: string | null;
  onYenile?: () => void;
}) {
  const t = useT();
  return (
    <Kart className="p-kart">
      <p role="alert" className="text-kartbaslik text-accent-red">
        {mesaj || t("ortakHataOlustu")}
      </p>
      {onYenile ? (
        <button
          onClick={onYenile}
          className="mt-3 rounded-lg border border-yuzey-divider px-3 py-1.5 text-sm text-metin-body hover:bg-yuzey-divider"
        >
          {t("ortakYenidenDene")}
        </button>
      ) : null}
    </Kart>
  );
}

// Sayfa basligi kalibi: baslik + (istege bagli) aciklama + birincil eylem.
export function SayfaBasligi({
  baslik,
  aciklama,
  eylem,
  suzgec,
}: {
  baslik: string;
  aciklama?: string;
  eylem?: ReactNode;
  suzgec?: ReactNode;
}) {
  return (
    <div className="mb-bolum">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-selam text-metin-heading">{baslik}</h1>
          {aciklama ? (
            // SAYFA ZEMININDE duran ikincil metin: `mutedBg` (kontrast
            // testi `muted`i burada 4.47 ile dusurmustu).
            <p className="mt-1 text-sm text-metin-mutedBg">{aciklama}</p>
          ) : null}
        </div>
        {eylem ? <div className="shrink-0">{eylem}</div> : null}
      </div>
      {suzgec ? <div className="mt-4 flex flex-wrap items-end gap-3">{suzgec}</div> : null}
    </div>
  );
}
