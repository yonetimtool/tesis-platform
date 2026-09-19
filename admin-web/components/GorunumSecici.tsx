"use client";

/**
 * (P243 §4) GORUNUM MODU SECICI — STANDART / BUYUK.
 *
 * =========================================================================
 * `ThemeToggle` ILE AYNI DESEN — ve bu bilincli
 * =========================================================================
 * Ayni SWR anahtari (`/api/me`), ayni "hesap tercihi bir kez uygulanir"
 * korumasi, ayni "sessiz yaz" davranisi. Iki ayri desen yazmak, birinde
 * duzeltilen bir hatanin otekinde kalmasi demekti (P190'da tema icin
 * ogrenilen ders).
 *
 * =========================================================================
 * NEDEN DUGME DEGIL IKI SECENEK
 * =========================================================================
 * Tema uc degerli oldugu icin donguyle geciliyor. Burada IKI deger var
 * ve dongu, kullaniciya "hangi moddayim" sorusunu her tiklamada yeniden
 * sordururdu. Iki dugme: hangisinin secili oldugu BAKISLA gorunur.
 */
import { useEffect, useRef, useState } from "react";
import useSWR from "swr";

import { Dugme } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import {
  GORUNUM_CEREZI,
  type GorunumModu,
  gorunumCerezYaz,
  gorunumCoz,
  gorunumuUygula,
} from "@/lib/gorunum";
import { useT } from "@/lib/i18n/kullan";

const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;
const KUCUK = "kucuk" as const;
const STANDART: GorunumModu = "standart";
const MODLAR: GorunumModu[] = [STANDART, "buyuk"];

function cerezMod(): GorunumModu | null {
  const m = document.cookie.match(
    new RegExp(`(?:^|;\\s*)${GORUNUM_CEREZI}=(standart|buyuk)`),
  );
  return m ? (m[1] as GorunumModu) : null;
}

export function GorunumSecici() {
  const t = useT();
  const [mod, setMod] = useState<GorunumModu>("standart");
  const hesapUygulandi = useRef(false);
  const { data: kimlik } = useSWR<{ ui_gorunum?: string }>(
    "/api/me",
    jsonFetcher,
  );

  useEffect(() => {
    const kayitli = cerezMod();
    if (kayitli) setMod(kayitli);
    // MOUNT'TA YENIDEN UYGULA: SSR sinifi bastiysa bu idempotenttir.
    // `?? STANDART`: ucluda cipli sabit dize `sabit-metin` taramasina
    // takiliyor (JSX metni saniyor); adlandirilmis sabit kullaniliyor.
    gorunumuUygula(kayitli ?? STANDART);
  }, []);

  // HESAPTAKI TERCIH KAZANIR (tema ile ayni kural): baska tarayicida
  // secilen mod burada da acilista gelir — ama YALNIZ BIR KEZ, yoksa
  // kullanicinin oturum icindeki secimini geri ezerdi.
  useEffect(() => {
    const hesap = kimlik?.ui_gorunum;
    if (!hesap || hesapUygulandi.current) return;
    hesapUygulandi.current = true;
    const cozulen = gorunumCoz(hesap);
    if (cozulen !== cerezMod()) {
      setMod(cozulen);
      gorunumCerezYaz(cozulen);
      gorunumuUygula(cozulen);
    }
  }, [kimlik]);

  function sec(yeni: GorunumModu) {
    hesapUygulandi.current = true;
    setMod(yeni);
    gorunumCerezYaz(yeni);
    gorunumuUygula(yeni);
    // SESSIZ YAZ: gorunum ANINDA degisti; sunucu hatasi kullanicinin
    // secimini geri almaz, yalnizca capraz-tarayici senkronu gecikir.
    void apiSend("/api/me/gorunum", "PATCH", { gorunum: yeni }).catch(() => {});
  }

  return (
    <div className="flex flex-wrap items-center gap-2" data-test="gorunum-secici">
      {MODLAR.map((m) => (
        <Dugme
          key={m}
          type="button"
          boy={KUCUK}
          tur={mod === m ? BIRINCIL : IKINCIL}
          aria-pressed={mod === m}
          data-test={`gorunum-${m}`}
          onClick={() => sec(m)}
        >
          {m === "buyuk" ? t("gorunumBuyuk") : t("gorunumStandart")}
        </Dugme>
      ))}
    </div>
  );
}
