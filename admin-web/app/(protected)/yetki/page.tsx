"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { ErrorBox, PageHeader, inputCls, panelCls, panelMotion } from "@/components/form";
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

  return (
    <div className="space-y-6">
      <PageHeader title={t("yetkiBaslik")} subtitle={t("yetkiAlt")} />
      <ErrorBox message={error ? t("yetkiHata") : null} />

      <motion.section {...panelMotion} className={panelCls}>
        <input
          className={`${inputCls} mb-3`}
          placeholder={t("yetkiAra")}
          value={ara}
          onChange={(e) => setAra(e.target.value)}
        />
        <p className="mb-3 text-xs text-slate-500">{t("yetkiNotu")}</p>
        {data ? (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-slate-500">
                <tr>
                  <th className="px-2 py-2">{t("yetkiMetot")}</th>
                  <th className="px-2 py-2">{t("yetkiYol")}</th>
                  {data.roller.map((r) => (
                    <th key={r} className="px-2 py-2 text-center">
                      {/* Rol adlari SOZLUKTEN: sunucu wire degerini doner,
                          panel onu kullanicinin dilinde cizer. */}
                      {t(`rol_${r}` as never)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {satirlar.map((s) => (
                  <tr
                    key={`${s.metot} ${s.yol}`}
                    className="border-t border-slate-100 dark:border-slate-800"
                  >
                    <td className="px-2 py-1.5 font-mono">{s.metot}</td>
                    <td className="px-2 py-1.5 font-mono">
                      {s.yol}
                      {s.moda_bagli ? (
                        <span className="ml-1 text-amber-600" title={t("yetkiModaBagliIpucu")}>
                          {t("yetkiModaBagli")}
                        </span>
                      ) : null}
                    </td>
                    {data.roller.map((r) => (
                      <td key={r} className="px-2 py-1.5 text-center">
                        {s.roller === null ? (
                          <span className="text-slate-400" title={t("yetkiKapisizIpucu")}>
                            {t("yetkiKapisiz")}
                          </span>
                        ) : s.roller.includes(r) ? (
                          <span className="text-emerald-600">{t("yetkiIzin")}</span>
                        ) : (
                          <span className="text-slate-300">{t("yetkiRed")}</span>
                        )}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </motion.section>
    </div>
  );
}
