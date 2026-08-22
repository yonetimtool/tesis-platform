"use client";

import { APP_ADRESI, SSO_APPLE, SSO_GOOGLE, SSO_MICROSOFT } from "@/config/site";

/**
 * (P177 §4) TEKIL OTURUM ACMA — UC DUGME DE YERLESIR.
 *
 * =========================================================================
 * KAPALI SAGLAYICI: GORUNUR, TIKLANAMAZ, "YAKINDA" ROZETLI
 * =========================================================================
 * Sartnamenin acik maddesi. `disabled` + `aria-disabled` birlikte:
 * `disabled` fareyi ve klavyeyi keser, `aria-disabled` ekran okuyucuya
 * dugmenin VAR ama su an kullanilamaz oldugunu soyler. Dugmeyi hic
 * cizmemek, "yakinda gelecek" bilgisini yok ederdi.
 *
 * SAGLAYICI HAZIR OLDUGUNDA YALNIZ BAYRAK ACILIR: `NEXT_PUBLIC_SSO_APPLE=1`
 * yeter, bu dosya degismez.
 *
 * =========================================================================
 * SOSYAL YOL NEDEN TANITIM SITESINDE BITMIYOR
 * =========================================================================
 * OAuth donusu bir OTURUM uretir. Oturumu tanitim alan adinda acmak
 * demek: yeni bir `redirect_uri`yi Google/Microsoft/Apple konsollarina
 * kaydetmek, yeni bir CORS kokeni acmak ve jetonlari bir PAZARLAMA
 * alan adinda saklamak. Uc yeni guvenlik yuzeyi, sifir kazanc.
 *
 * Bu yuzden dugmeler kimlik yuzeyine (app-test) DEVREDER; oradaki akis
 * bugun de calisan akistir ve DEGISTIRILMEDI. Sartnamenin "MEVCUT KIMLIK
 * SISTEMI BOZULMAYACAK" maddesiyle dogrudan ilgili.
 *
 * ZORUNLU ONAYLAR BURADA DA GECERLI: iki kutu isaretlenmeden hicbir
 * dugme calismaz (`kilitli`). Parola yolunda onay arayip sosyal yolda
 * aramamak, onayi bir formalite hâline getirirdi.
 */
type Saglayici = { kod: string; ad: string; acik: boolean };

const SAGLAYICILAR: Saglayici[] = [
  { kod: "google", ad: "Google", acik: SSO_GOOGLE },
  { kod: "microsoft", ad: "Microsoft", acik: SSO_MICROSOFT },
  { kod: "apple", ad: "Apple", acik: SSO_APPLE },
];

export function SsoDugmeleri({ kilitli }: { kilitli: boolean }) {
  return (
    <div className="space-y-2.5">
      {SAGLAYICILAR.map((s) => {
        const kullanilabilir = s.acik && !kilitli;
        const ortak =
          "flex w-full items-center justify-center gap-2.5 rounded-[10px] border-2 border-cizgiDenetim bg-white px-4 py-3 text-[0.95rem] font-bold text-baslik";
        if (!kullanilabilir) {
          return (
            <button
              key={s.kod}
              type="button"
              disabled
              aria-disabled="true"
              className={`${ortak} cursor-not-allowed opacity-60`}
            >
              {s.ad} ile devam et
              {!s.acik ? (
                <span className="rounded-chip bg-zemin px-2 py-0.5 text-[0.7rem] font-bold uppercase tracking-wider text-soluk">
                  Yakında
                </span>
              ) : null}
            </button>
          );
        }
        return (
          <a
            key={s.kod}
            href={`${APP_ADRESI}/login?saglayici=${s.kod}`}
            className={`${ortak} hover:border-mavi hover:text-mavi`}
          >
            {s.ad} ile devam et
          </a>
        );
      })}
    </div>
  );
}
