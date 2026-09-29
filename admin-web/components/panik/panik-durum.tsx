"use client";

/**
 * (P249 §1b) DAIRE BAZINDA DURUM — kim guvende, kim yardim istiyor, kim
 * yanit vermedi. Depremde yoneticinin en degerli bilgisi.
 *
 * Sunucu siralar (`panik_durum.py`): once YARDIM (birinin gitmesi gereken
 * daireler), sonra YANITSIZ (sayimin acik kalan kismi), en son GUVENDE.
 * Istemci yeniden siralamaz: ayni tablonun iki yuzeyde farkli sirada
 * cikmasi, "ilk satir en acil" sozunu bozardi.
 */
import useSWR from "swr";

import { HataDurumu, IskeletMetin, Rozet } from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type Kisi = {
  user_id: string;
  ad: string;
  rol: string;
  yanit: string | null;
  yanit_suresi_sn: number | null;
};
type Daire = {
  unit_id: string | null;
  blok: string | null;
  daire_no: string | null;
  durum: "yardim" | "yanitsiz" | "guvende";
  kisiler: Kisi[];
};
export type PanikDurum = {
  alici: number;
  goruldu: number;
  guvende: number;
  yardim: number;
  yanitsiz: number;
  ortalama_yanit_sn: number | null;
  daireler: Daire[];
  personel: Kisi[];
};

const ETIKET: Record<string, SozlukAnahtari> = {
  guvende: "panikYanitEtiketGuvende",
  yardim: "panikYanitEtiketYardim",
};
const YOK: SozlukAnahtari = "panikYanitEtiketYok";
const ROZET: Record<string, "olumlu" | "kritik" | "notr"> = {
  guvende: "olumlu",
  yardim: "kritik",
};
const NOTR = "notr" as const;

function daireAdi(d: Daire): string {
  const no = d.daire_no ?? "";
  const blok = d.blok ?? "";
  return !blok || no.startsWith(blok) ? no : `${blok} ${no}`;
}

export function PanikDurumPaneli({ alarmId }: { alarmId: string }) {
  const t = useT();
  const { data, error, isLoading } = useSWR<PanikDurum>(
    `/api/panik/${alarmId}/durum`,
    jsonFetcher,
    // Tahliye sirasinda yanitlar dakikalar icinde gelir.
    { refreshInterval: 10_000 },
  );
  if (error) return <HataDurumu mesaj={t("ortakHataOlustu")} />;
  if (isLoading || !data) return <IskeletMetin satir={4} />;
  return (
    <div data-test="panik-durum">
      <p data-test="panik-durum-sayilar">
        {t("panikYanitSayilar", {
          alici: data.alici,
          guvende: data.guvende,
          yardim: data.yardim,
          yanitsiz: data.yanitsiz,
        })}
      </p>
      {data.ortalama_yanit_sn !== null && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("panikOrtalamaYanit", { n: data.ortalama_yanit_sn })}
        </p>
      )}
      <ul className="mt-3 space-y-2">
        {data.daireler.map((d) => (
          <li
            key={d.unit_id ?? daireAdi(d)}
            data-test={`panik-durum-daire-${daireAdi(d)}`}
            className="rounded border p-2"
            style={{ borderColor: "var(--yz-border)" }}
          >
            <div className="flex items-center justify-between gap-2">
              <span className="font-semibold">{daireAdi(d)}</span>
              <Rozet durum={ROZET[d.durum] ?? NOTR}>{t(ETIKET[d.durum] ?? YOK)}</Rozet>
            </div>
            <p style={{ fontSize: "var(--yz-fs-sm)" }}>
              {d.kisiler.map((k) => `${k.ad} — ${t(ETIKET[k.yanit ?? ""] ?? YOK)}`).join(" · ")}
            </p>
          </li>
        ))}
      </ul>
      {data.personel.length > 0 && (
        <>
          <p className="mt-3 font-semibold">{t("panikYanitPersonel")}</p>
          <ul className="mt-1" style={{ fontSize: "var(--yz-fs-sm)" }}>
            {data.personel.map((k) => (
              <li key={k.user_id}>
                {k.ad} — {t(ETIKET[k.yanit ?? ""] ?? YOK)}
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
