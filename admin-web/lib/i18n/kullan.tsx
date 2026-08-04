"use client";

// Panel i18n baglami — `t("anahtar")` ve dil degistirme (tur 17).
//
// NEDEN KUTUPHANE YOK: sozluk duz bir TypeScript nesnesidir ve tipi `tr`
// sozlugunden turer (`type Sozluk = typeof tr`). Eksik/fazla anahtar
// DERLEME HATASIDIR — mobil tarafta `switch`in `default` dalini yazmamakla
// elde ettigimiz zorlamanin TypeScript karsiligi. Bir kutuphane bunu
// calisma anina ("missing key" uyarisi) erteleyecekti.

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import {
  DIL_COOKIE,
  DIL_COOKIE_MAX_AGE,
  VARSAYILAN_DIL,
  dilMi,
  kayitliDil,
  yon,
  type Dil,
} from "./diller";
import { SOZLUKLER, type Sozluk, type SozlukAnahtari } from "./sozluk";

interface I18n {
  dil: Dil;
  dir: "rtl" | "ltr";
  /** Anahtar -> aktif dildeki metin; `{alan}` yer tutuculari doldurulur. */
  t: (anahtar: SozlukAnahtari, params?: Record<string, string | number>) => string;
  dilDegistir: (yeni: Dil) => void;
}

const Ctx = createContext<I18n | null>(null);

function metin(
  sozluk: Sozluk,
  anahtar: SozlukAnahtari,
  params?: Record<string, string | number>,
): string {
  // Sozluk tipi tam oldugu icin anahtar HER ZAMAN vardir; yine de calisma
  // aninda bos metin gostermektense anahtarin kendisini dondururuz
  // (orn. eski bir sekme acikken sozluk degistiyse).
  const ham = sozluk[anahtar] ?? anahtar;
  if (!params) return ham;
  return ham.replace(/\{(\w+)\}/g, (tam, alan) =>
    alan in params ? String(params[alan]) : tam,
  );
}

export function I18nProvider({
  baslangicDili,
  children,
}: {
  baslangicDili: Dil;
  children: ReactNode;
}) {
  const [dil, setDil] = useState<Dil>(baslangicDili);

  const dilDegistir = useCallback((yeni: Dil) => {
    setDil(yeni);
    // Cookie: sunucu bileseni (`<html lang>`, `dir`) ve BFF'in
    // `Accept-Language` basligi bunu okur. `SameSite=Lax` + path=/ ile
    // sonraki gezinmelerde de gecerli.
    document.cookie = `${DIL_COOKIE}=${yeni}; path=/; max-age=${DIL_COOKIE_MAX_AGE}; samesite=lax`;
    // `<html>` ozniteliklerini ANINDA guncelle: sayfa yenilenmeden yon ve
    // dil degisir (sunucu ayni degerleri bir sonraki istekte uretir).
    document.documentElement.lang = yeni;
    document.documentElement.dir = yon(yeni);
  }, []);

  // (P126 sonrasi) `?lang=xx` — PAYLASILAN BAGLANTI icin acik dil secimi.
  //
  // SIRA: kayitli tercih > `?lang` > tarayici > Turkce. Yani kullanicinin
  // KENDI secimi bir baglantiyla EZILMEZ; birinin gonderdigi `?lang=ar`,
  // dilini Turkce yapmis birinin arayuzunu degistiremez.
  //
  // NEDEN ISTEMCIDE: kok duzen bir Server Component'tir ve App Router'da
  // duzenler `searchParams` ALMAZ. Middleware'e koymak `/login` ve genel
  // portal sayfalarini matcher'a sokmayi gerektirirdi — o matcher oturum
  // kapisini da tasiyor ve genel sayfalarin ACIK kalmasi bir kuraldir
  // (tests/portal-public.test.ts). Bedeli: secim ilk boyamadan SONRA
  // uygulanir; cerez yazildigi icin sonraki her istek sunucuda dogru dille
  // boyanir.
  useEffect(() => {
    if (typeof window === "undefined") return;
    const istenen = new URLSearchParams(window.location.search).get("lang");
    if (!dilMi(istenen)) return;
    if (kayitliDil() !== null) return; // kayitli tercih ONCE
    dilDegistir(istenen);
  }, [dilDegistir]);

  const deger = useMemo<I18n>(() => {
    const sozluk = SOZLUKLER[dil] ?? SOZLUKLER[VARSAYILAN_DIL];
    return {
      dil,
      dir: yon(dil),
      t: (anahtar, params) => metin(sozluk, anahtar, params),
      dilDegistir,
    };
  }, [dil, dilDegistir]);

  return <Ctx.Provider value={deger}>{children}</Ctx.Provider>;
}

export function useI18n(): I18n {
  const ctx = useContext(Ctx);
  if (!ctx) {
    throw new Error("useI18n yalniz <I18nProvider> altinda kullanilir");
  }
  return ctx;
}

/** Kisayol: yalniz `t` gereken bilesenler icin. */
export function useT() {
  return useI18n().t;
}
