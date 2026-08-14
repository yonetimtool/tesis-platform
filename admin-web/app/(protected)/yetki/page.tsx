"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  AramaAlani,
  HataDurumu,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * P41 — YETKI MATRISI gorunumu.
 *
 * SAYFA HICBIR YETKI BILGISI TASIMAZ: satirlar da sutunlar da sunucudan
 * gelir. Panelde bir kopya tutmak, bir uc `require_role`unu degistirdiginde
 * burasinin YANLIS bir tablo gostermesi demekti — ve "kim neye erisiyor"
 * sorusunda yanlis yanit, yanit vermemekten daha kotudur.
 *
 * `roller: null` ROZETI AYRIDIR: "rol kapisi yok" ile "herkese acik" AYNI
 * SEY DEGILDIR (kimlik dogrulamasi yine gerekebilir); ikisini ayni gostermek
 * kimliksiz erisilebilir bir uc varmis gibi gosterirdi.
 */

interface Satir {
  metot: string;
  yol: string;
  roller: string[] | null;
  moda_bagli: boolean;
}
interface Matris {
  roller: string[];
  items: Satir[];
}

export default function YetkiPage() {
  const t = useT();
  const { data, error } = useSWR<Matris>("/api/panel/yetki-matrisi", jsonFetcher);
  const [ara, setAra] = useState("");

  const satirlar = (data?.items ?? []).filter(
    (s) => !ara || s.yol.toLowerCase().includes(ara.toLowerCase()),
  );

  // Kolonlar SUNUCUDAN gelen rol listesine gore kurulur: panelde sabit
  // bir rol dizisi tutmak, sunucuya rol eklendiginde matrisin EKSIK
  // gorunmesi demekti.
  const kolonlar: Kolon<Satir>[] = useMemo(() => {
    const temel: Kolon<Satir>[] = [
      {
        id: "metot",
        baslik: t("yetkiMetot"),
        gizlenebilir: false,
        deger: (s) => s.metot,
        hucre: (s) => <span className="font-mono">{s.metot}</span>,
      },
      {
        id: "yol",
        baslik: t("yetkiYol"),
        gizlenebilir: false,
        deger: (s) => s.yol,
        hucre: (s) => (
          <span className="font-mono">
            {s.yol}
            {s.moda_bagli ? (
              <span
                className="ms-1"
                style={{ color: "var(--yz-warning-ink)" }}
                title={t("yetkiModaBagliIpucu")}
              >
                {t("yetkiModaBagli")}
              </span>
            ) : null}
          </span>
        ),
      },
    ];
    for (const r of data?.roller ?? []) {
      temel.push({
        id: r,
        // Rol adlari SOZLUKTEN: sunucu wire degerini doner, panel onu
        // kullanicinin dilinde cizer.
        baslik: t(`rol_${r}` as never),
        hucre: (s) =>
          s.roller === null ? (
            // "rol kapisi yok" ile "herkese acik" AYNI SEY DEGILDIR.
            <span style={{ color: "var(--yz-text-3)" }} title={t("yetkiKapisizIpucu")}>
              {t("yetkiKapisiz")}
            </span>
          ) : s.roller.includes(r) ? (
            <span style={{ color: "var(--yz-success-ink)" }}>{t("yetkiIzin")}</span>
          ) : (
            <span style={{ color: "var(--yz-text-3)" }}>{t("yetkiRed")}</span>
          ),
      });
    }
    return temel;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [t, data]);

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("yetkiBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("yetkiAlt")}</p>
      </div>

      {error && <HataDurumu mesaj={t("yetkiHata")} />}

      <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("yetkiNotu")}</p>

      <VeriTablosu<Satir>
        kolonlar={kolonlar}
        satirlar={satirlar}
        satirId={(s) => `${s.metot} ${s.yol}`}
        yukleniyor={!data && !error}
        araclar={
          <div className="w-full sm:w-72">
            {/* (P63) Yer tutucu tek basina erisilebilir AD saglamaz. */}
            <AramaAlani
              etiket={t("yetkiAra")}
              yerTutucu={t("yetkiAra")}
              temizleEtiketi={t("ortakKapat")}
              deger={ara}
              onDegisim={setAra}
            />
          </div>
        }
      />
    </div>
  );
}
