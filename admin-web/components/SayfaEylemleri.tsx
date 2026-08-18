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

import { useEffect, useLayoutEffect, useState, type ReactNode } from "react";
import { useBantEnAz } from "@/lib/kirilma-kullan";
import { createPortal } from "react-dom";

/** Yuvanin DOM kimligi — kabuk ve sayfa ARASINDAKI TEK sozlesme. */
export const SAYFA_EYLEM_YUVASI = "yz-sayfa-eylemleri";

/** Kabugun cizdigi bos yuva. Icerik gelmezse gorunmez kalir. */
export function SayfaEylemYuvasi() {
  return <div id={SAYFA_EYLEM_YUVASI} className="flex items-center gap-2" />;
}

/** Sayfanin ust bara koydugu eylemler. */
/**
 * SSR'da `useLayoutEffect` UYARI BASAR: sunucuda yerlesim yoktur. Sunucu
 * dalinda normal etkiye duseriz — orada zaten hicbir sey cizilmiyor.
 */
const useYerlesimEtkisi =
  typeof window === "undefined" ? useEffect : useLayoutEffect;

export function SayfaEylemleri({ children }: { children: ReactNode }) {
  const [hedef, setHedef] = useState<HTMLElement | null>(null);
  // SUNUCUDA cizim YAPILMAZ: portal hedefi yalnizca tarayicida vardir ve
  // sunucuda `children`i basmak, montajda ikinci bir kopya birakirdi.
  const [binildi, setBinildi] = useState(false);

  // (P170 §4.3) YUVA `lg` ALTINDA YOK — ve bu bir DUZELTME.
  //
  // OLCULDU: yuva kabugun `hidden ... lg:flex` cubugunun ICINDEYDI. O
  // cubuk dar ekranda `display:none` ama DOM'da DURUYOR; portal hedefi
  // buluyor, icerigi oraya tasiyor ve dugme GORUNMEZ bir kutuda kaliyordu.
  // Yani "Paneli duzenle" telefonda ve tablette HIC BASILAMIYORDU —
  // ekranda hicbir hata yok, islev sessizce yok.
  //
  // Cozum ikinci bir yuva ACMAK DEGIL (ayni `id` iki kez, ust barda da yer
  // yok — bkz. §3 olcumu): dar ekranda yuva HIC monte edilmiyor ve bilesen
  // zaten var olan geri dususunu kullanip eylemleri SAYFA ICINDE, basligin
  // altinda ciziyor. Orada yer var ve baglami da dogru.
  //
  // Bant bagimliligi SART: kabuk yuvayi bant degisince tasiyor; bagimlilik
  // olmasaydi hedef bir kez okunur ve pencere buyudugunde bayat kalirdi.
  const genis = useBantEnAz("lg");

  // YERLESIM ETKISI, NORMAL ETKI DEGIL — VE BU BIR TITREME DUZELTMESI.
  //
  // Hidrasyondan hemen sonra bant `lg`ye guncellenir ve kabuk yuvayi O
  // KAREDE monte eder. Normal `useEffect` BOYAMADAN SONRA calisir, yani
  // masaustunde dugmeler bir kare sayfa govdesinde gorunup sonra ust bara
  // ziplardi. `useLayoutEffect` boyamadan ONCE calisir; kullanici ara
  // hali HIC gormez.
  //
  // "Genis banttaysa hic cizme" seklinde bir koruma DENENDI VE ELENDI:
  // yuva herhangi bir sebeple yoksa (baska bir kabuk, test, gelecekteki
  // bir duzen) eylemler SESSIZCE kaybolurdu — bu turda duzeltilen kusurun
  // ta kendisi. Satir-ici geri dusus KOSULSUZ kaliyor.
  useYerlesimEtkisi(() => {
    setHedef(document.getElementById(SAYFA_EYLEM_YUVASI));
    setBinildi(true);
  }, [genis]);

  if (!binildi) return null;
  if (hedef) return createPortal(children, hedef);
  // SARMAL GEREKLI: yuvadaki `flex` duzeni burada yok; sarmalsiz iki dugme
  // blok siralanip alt alta duserdi.
  return <div className="flex flex-wrap items-center gap-2">{children}</div>;
}
