"use client";

/**
 * (P161) `useOnay` — YIKICI ISLEM ONAYI, tarayicinin `confirm()`'u yerine.
 *
 * =========================================================================
 * NEDEN: `OnayDiyalogu` VARDI, HIC KULLANILMIYORDU
 * =========================================================================
 * Envanterde olculdu: `components/ui/modal.tsx` icindeki `OnayDiyalogu`
 * hicbir sayfada cagrilmiyordu; buna karsilik 17 yerde tarayicinin yerel
 * `confirm()`'u vardi. Yerel diyalogun somut kusurlari:
 *
 *  1. TEMAYI TANIMAZ — koyu temada beyaz bir isletim sistemi kutusu acar.
 *  2. TEHLIKEYI ANLATMAZ — "Sil" ile "Kaydet" ayni gorunur; brief'in
 *     istedigi "ayri tehlikeli renk" yerel diyalogda IMKANSIZDIR.
 *  3. BICIMLENDIRME TASIMAZ — "ne silinecek" yalnizca duz cumleyle
 *     anlatilabilir; baslik/govde ayrimi yoktur.
 *  4. ANA IS PARCACIGINI BLOKLAR ve otomasyon/test ortamlarinda sessizce
 *     `true` ya da `false` doner.
 *
 * =========================================================================
 * NEDEN KANCA, NEDEN PROMISE
 * =========================================================================
 * Cagri yerlerinin hepsi `if (!confirm(...)) return;` seklindeydi. Kanca
 * `Promise<boolean>` dondurunce satir `if (!(await onayla(...))) return;`
 * olur — akis AYNI kalir. Her sayfaya bes ayri `useState` ekletmek yerine
 * tek satir (`const { onayla, diyalog } = useOnay();`) yeter.
 *
 * SOZ TEK SEFER COZULUR: diyalog kapanirken bekleyen cozucu her durumda
 * cagrilir; yoksa iptal edilen bir onay, cagiran tarafi sonsuza dek
 * bekletirdi.
 */
import { useCallback, useRef, useState, type ReactNode } from "react";

import { OnayDiyalogu } from "./modal";

export interface OnayIstegi {
  baslik: string;
  mesaj: string;
  onayMetni: string;
  /** Yikici mi? Onay dugmesi tehlike rengine gecer. */
  tehlikeli?: boolean;
}

/** Kancanin sozlesmesi. Metot bicimi bilincli: `=> Promise<...>` yazimi
 *  `sabit-metin` tarayicisinin `>metin<` kalibina takiliyor (`=>` ile
 *  `<boolean>` arasinda kalan " Promise" JSX metni sanilir). */
export interface OnayKancasi {
  onayla(istek: OnayIstegi): Promise<boolean>;
  diyalog: ReactNode;
}

export function useOnay(): OnayKancasi {
  const [istek, setIstek] = useState<OnayIstegi | null>(null);
  const cozucuRef = useRef<((sonuc: boolean) => void) | null>(null);

  const kapat = useCallback((sonuc: boolean) => {
    // ONCE COZ, SONRA KAPAT: cozucuyu temizlemeden state'i degistirirsek
    // yeniden cizim sirasinda bekleyen soz kaybolabilirdi.
    const coz = cozucuRef.current;
    cozucuRef.current = null;
    setIstek(null);
    coz?.(sonuc);
  }, []);

  const onayla = useCallback((yeni: OnayIstegi) => {
    return new Promise<boolean>((coz) => {
      // ONCEKI ISTEK ACIKSA REDDEDILIR: iki diyalog ust uste binemez ve
      // eski cagiran bekletilemez.
      cozucuRef.current?.(false);
      cozucuRef.current = coz;
      setIstek(yeni);
    });
  }, []);

  const diyalog = (
    <OnayDiyalogu
      acik={istek !== null}
      baslik={istek?.baslik ?? ""}
      mesaj={istek?.mesaj ?? ""}
      onayMetni={istek?.onayMetni ?? ""}
      tehlikeli={istek?.tehlikeli ?? false}
      onOnay={() => kapat(true)}
      onIptal={() => kapat(false)}
    />
  );

  return { onayla, diyalog };
}
