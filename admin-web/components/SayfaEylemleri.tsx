"use client";

// (P168 §1.3) UST BARDAKI "SAYFA EYLEMLERI" YUVASI.
//
// =========================================================================
// NEDEN PORTAL, NEDEN KABUGA SABIT KOD DEGIL
// =========================================================================
// Brief "Paneli duzenle dugmesi sag ustte, BILDIRIM IKONUNUN SOLUNA"
// diyor. Bildirim ikonu KABUGUN ust barinda; dugme ise YALNIZ ozet
// sayfasina ait ve o sayfanin durumunu (`duzenlemede`) tasiyor.
//
// Iki kolay ama yanlis yol vardi:
//   1. Dugmeyi `AppShell`e tasimak → kabuk, ozet sayfasinin durumunu
//      bilmek zorunda kalirdi. Yarin ikinci bir sayfa kendi eylemini
//      isteyince kabuk o sayfayi da tanimak zorunda kalir ve kabuk
//      yavas yavas butun sayfalarin mantigini toplardi.
//   2. Dugmeyi sayfada birakip CSS ile sag uste itmek → gorunurde ayni,
//      ama kaydirmada ve dar ekranda ayrisir; ustelik iki ayri yigin
//      ustuste biner.
//
// Bunun yerine kabuk BOS BIR YUVA aciyor, sayfa icerigini oraya
// PORTAL'liyor. Kabuk hangi dugmenin gelecegini bilmez; sayfa kendi
// dugmesini kendi tasir. Yuva bossa hicbir sey cizilmez.
//
// SSR GUVENLIGI: portal yalnizca yuva DOM'da varken kurulur.
//
// YUVA YOKSA EYLEMLER YERINDE CIZILIR, YOK OLMAZ.
// Ilk yazimda yuva bulunamayinca `null` donuyordu ve bu SESSIZ bir kayipti:
// kabuk bir gun yuvayi kaldirsa ya da sayfa kabuksuz bir baglamda cizilse
// (testler, gomulu gorunum) dugmeler EKRANDAN TAMAMEN SILINIRDI — ve
// kimse "dugmem yok" demeden once fark etmezdi. Geri cekilme davranisi
// dugmeyi sayfanin kendi akisinda birakir: yeri degisir, VARLIGI degismez.

import { useEffect, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";

/** Yuvanin DOM kimligi — kabuk ve sayfa ARASINDAKI TEK sozlesme. */
export const SAYFA_EYLEM_YUVASI = "yz-sayfa-eylemleri";

/** Kabugun cizdigi bos yuva. Icerik gelmezse gorunmez kalir. */
export function SayfaEylemYuvasi() {
  return <div id={SAYFA_EYLEM_YUVASI} className="flex items-center gap-2" />;
}

/** Sayfanin ust bara koydugu eylemler. */
export function SayfaEylemleri({ children }: { children: ReactNode }) {
  const [hedef, setHedef] = useState<HTMLElement | null>(null);
  // SUNUCUDA cizim YAPILMAZ: portal hedefi yalnizca tarayicida vardir ve
  // sunucuda `children`i basmak, montajda ikinci bir kopya birakirdi.
  const [binildi, setBinildi] = useState(false);

  useEffect(() => {
    setHedef(document.getElementById(SAYFA_EYLEM_YUVASI));
    setBinildi(true);
  }, []);

  if (!binildi) return null;
  return hedef ? createPortal(children, hedef) : <>{children}</>;
}
