// (P138) ORTAK TABLO ILKELI — 23 sayfa ayni iskeleti elle yaziyordu.
//
// OLCUM: `form.tsx` kart/dugme/girdi icin ortak katman sagliyor ve P132.7
// tam bu yuzden 47 sayfayi TEK degisiklikle tasidi. Ama TABLO icin ortak
// katman YOKTU: `tableCardCls` tanimliydi ve HICBIR sayfa kullanmiyordu
// (0/23). Her sayfa `<table className="w-full text-sm">` iskeletini,
// baslik hucrelerini ve satir ayiricilarini kendi yaziyordu.
//
// Bedeli gorunum degil DEGISTIRILEBILIRLIK: tablo dilinde bir karar
// degistirmek 23 dosyaya dokunmak demekti ve pratikte hicbiri
// degistirilmiyordu. Bu dosya o kaldiraci kurar.
//
// -------------------------------------------------------------------------
// TINT BLOKLAR BURAYA GELMEZ — KAPSAM KARARI
// -------------------------------------------------------------------------
// P133'un onayladigi "tint blok" dili kendi tanimida "pano + tanitim
// yuzeyleri" diyor ve SERT SINIRI (1 kahraman + 4 ikincil) "renk SINYAL
// kalmali" diye var. 23 liste sayfasina tint dagitmak tam olarak o sinirin
// onledigi seyi yapardi. Liste sayfalari ayni TASARIM SISTEMINE oturur
// (yuzey, yaricap, bosluk, cip, tipografi olcegi); kahraman/tint dili
// panoda kalir.
//
// AYRIM DOLGU VE BOSLUKTAN: dikey izgara cizgisi YOK, satir arasi tek bir
// hafif yatay ayirici (`border-yuzey-divider`) ve uzerine gelince yuzey
// dolgusu. Degerlerin hepsi mevcut token'lardan; yeni renk/olcu ICAT
// EDILMEDI.
import type { ReactNode } from "react";

// Tablo kabı — kart yuzeyi + yatay kaydirma.
export function TabloKart({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`kart-kenar overflow-hidden rounded-kart border bg-yuzey-card ${className}`}>
      {/* DAR EKRANDA YATAY KAYDIRMA: tabloyu kirpmak yerine kaydirmak,
          sutun gizlemekten durusttur — kullanici verinin var oldugunu
          gorur. Sayfa govdesi yatay kaymaz, yalniz bu kap kayar. */}
      <div className="overflow-x-auto">{children}</div>
    </div>
  );
}

// `<table>` — tek yerde tanimli olcek.
export function Tablo({ children }: { children: ReactNode }) {
  return <table className="w-full text-sm">{children}</table>;
}

// Baslik satiri — sayfa zemini dolgusu, KENARLIK YOK.
export function TabloBasligi({ children }: { children: ReactNode }) {
  return (
    <thead className="bg-yuzey-bg text-start text-metin-muted">
      <tr>{children}</tr>
    </thead>
  );
}

// Baslik hucresi.
// `sag`/`sayi` sutunlari icin `hizala` verilir; `dar` eylem sutunlari
// icindir (govdede genisligi icerik belirlesin).
export function Th({
  children,
  hizala = "start",
  className = "",
}: {
  children?: ReactNode;
  hizala?: "start" | "end" | "center";
  className?: string;
}) {
  const h =
    hizala === "end" ? "text-end" : hizala === "center" ? "text-center" : "text-start";
  return <th className={`px-4 py-2.5 font-medium ${h} ${className}`}>{children}</th>;
}

// Govde satiri — ayirici ve uzerine gelme dolgusu BURADA.
// `border-t` ILK satirda da cizilir ve baslik zemininin altinda kalir;
// `first:border-t-0` ile kaldirilmaz cunku baslik ile govde arasindaki
// tek cizgi tam olarak istenen ayrimdir.
export function Tr({
  children,
  className = "",
  onClick,
}: {
  children: ReactNode;
  className?: string;
  onClick?: () => void;
}) {
  return (
    <tr
      onClick={onClick}
      className={`border-t border-yuzey-divider transition-colors hover:bg-yuzey-bg ${className}`}
    >
      {children}
    </tr>
  );
}

// Govde hucresi. `sayi` tabular rakam kullanir (sutun kaymasin).
export function Td({
  children,
  hizala = "start",
  sayi = false,
  className = "",
}: {
  children?: ReactNode;
  hizala?: "start" | "end" | "center";
  sayi?: boolean;
  className?: string;
}) {
  const h =
    hizala === "end" ? "text-end" : hizala === "center" ? "text-center" : "text-start";
  return (
    <td className={`px-4 py-2.5 ${h} ${sayi ? "tabular-nums" : ""} ${className}`}>
      {children}
    </td>
  );
}

// BOS TABLO SATIRI — "kayit yok" hucresi.
// Ayri bir bilesen cunku her sayfa `colSpan`i elle yaziyordu ve biri
// eksik kalinca hucre tablonun altina tasiyordu.
export function BosSatir({
  sutun,
  children,
}: {
  sutun: number;
  children: ReactNode;
}) {
  return (
    <tr className="border-t border-yuzey-divider">
      <td colSpan={sutun} className="px-4 py-8 text-center text-metin-muted">
        {children}
      </td>
    </tr>
  );
}
