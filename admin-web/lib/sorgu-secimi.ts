"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";

/**
 * (P154 / Asama 7.1) ADRESTEN GELEN SECIM — tek kanca, uc sayfa.
 *
 * Asama 7.1 menuye ayni sayfanin ALT GORUNUMLERINI ekledi:
 * `/finans?tip=gelir`, `/tanimlar?defter=kasalar`, `/mesajlar?kanal=sms`.
 * Bu baglantilarin ise yaramasi icin sayfanin secimi ADRESTEN okumasi
 * gerekir; okumazsa menu satiri dogru yere gider ama sayfa varsayilan
 * gorunumu acar ve baglanti SESSIZCE ise yaramaz.
 *
 * NEDEN ORTAK KANCA: uc sayfada ayni sekiz satiri yazmak, birinde
 * `useEffect` bagimliligini unutmak demekti (bkz. asagidaki tuzak).
 *
 * TUZAK — SADECE ILK KAREDE OKUMAK YETMEZ: kullanici `/finans?tip=gelir`
 * ekranindayken menuden `?tip=gider`e tiklarsa Next.js sayfayi YENIDEN
 * BAGLAMAZ (ayni rota). Yalniz baslangic degerini okuyan bir cozum ikinci
 * tiklamayi yok sayardi. Bu yuzden deger sorgu DEGISTIKCE tazelenir.
 *
 * GECERSIZ DEGER YOK SAYILIR: adres cubuguna elle `?tip=xyz` yazan biri
 * bos bir tablo degil, varsayilan gorunumu gorur.
 */
export function useSorguSecimi<T extends string>(
  ad: string,
  gecerli: readonly T[],
  varsayilan: T,
): [T, (v: T) => void] {
  const sorgu = useSearchParams();
  const ham = sorgu?.get(ad) ?? null;
  const adresteki = (gecerli as readonly string[]).includes(ham ?? "")
    ? (ham as T)
    : null;

  const [deger, setDeger] = useState<T>(adresteki ?? varsayilan);

  useEffect(() => {
    // Sorgu YOKSA kullanicinin sayfa icinde yaptigi secim korunur —
    // her cizimde varsayilana donmek, sekme secimini kullanilamaz kilardi.
    if (adresteki !== null) setDeger(adresteki);
  }, [adresteki]);

  return [deger, setDeger];
}
