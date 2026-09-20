"use client";

// (P244 §2) KANONIK SAYFA BASLIGI.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// 79 korumali sayfanin **71'i kendi `<h1>`ini yaziyor.** Ortak bir baslik
// deseni YOK: eski dilde bir `SayfaBasligi` (tasarim.tsx) ve bir
// `PageHeader` (form.tsx) var ama ikisi TOPLAM 4 sayfada kullaniliyor.
//
// Sonuc: baslik boyutu, alt aciklamanin olup olmadigi, eylemlerin nereye
// hizalandigi ve baslik-ile-icerik arasindaki bosluk sayfadan sayfaya
// degisiyor. "Her sayfa ayni sablon" sikayetinin YANINDA duran ikinci
// gercek: sayfalar ayni sablonda DEGIL, ama tutarli da degil.
//
// ===========================================================================
// NEDEN UCUNCU BIR BILESEN DEGIL — YERINE GECEN BIR BILESEN
// ===========================================================================
// Bu bilesen eski ikisinin YERINE gecer; modul turlarinda (asama 5-9)
// sayfalar buna tasinir ve eski ikisi asama 10'da silinir. Uc desenin
// kalici olarak yan yana yasamasi, bugunku dagiiniklik demekti.
//
// ===========================================================================
// NEDEN `eylem` BIR YUVA
// ===========================================================================
// Kabuk zaten bir sayfa-eylem yuvasi tasiyor (`SayfaEylemYuvasi`, genis
// bantta ust cubuga portallanir). Bu bilesen onunla YARISMAZ: dar bantta
// eylemler basligin yaninda kalir, genis bantta sayfa isterse yuvayi
// kullanir. Karar sayfanin.
import type { ReactNode } from "react";

export function SayfaBasligi({
  baslik,
  aciklama,
  eylem,
  ustBilgi,
  altCubuk,
}: {
  baslik: string;
  /** Bir cumlelik baglam. Gereksizse VERILMEZ — bos bir satir birakmaz. */
  aciklama?: string;
  /** Sag taraftaki birincil/ikincil eylemler. */
  eylem?: ReactNode;
  /** Basligin USTUNDE: kirinti yolu, geri baglantisi, durum rozeti. */
  ustBilgi?: ReactNode;
  /** Basligin ALTINDA: filtre cubugu, sekmeler. */
  altCubuk?: ReactNode;
}) {
  return (
    <div className="mb-6">
      {ustBilgi ? <div className="mb-2">{ustBilgi}</div> : null}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1
            style={{
              fontSize: "var(--yz-fs-h1)",
              lineHeight: "var(--yz-lh-tight)",
              color: "var(--yz-text)",
              fontWeight: 600,
            }}
          >
            {baslik}
          </h1>
          {aciklama ? (
            <p
              className="mt-1 max-w-2xl"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {aciklama}
            </p>
          ) : null}
        </div>
        {/* EYLEMLER SARILABILIR: dar bantta basligin ALTINA iner, ustune
            binmez. `shrink-0` degil `ms-auto`: tek dugme sagda kalir, uc
            dugme gerekirse alt satira gecer. */}
        {eylem ? <div className="flex flex-wrap items-center gap-2">{eylem}</div> : null}
      </div>
      {altCubuk ? <div className="mt-4">{altCubuk}</div> : null}
    </div>
  );
}
