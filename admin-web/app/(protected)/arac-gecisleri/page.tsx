"use client";

// (P126.4) ARAÇ GEÇİŞLERİ — SALT OKUMA.
//
// Kayıtlar ANPR ile OTOMATİK oluşur (P16). Elle giriş formu bilerek yok:
// plakayı elle yazmak, otomatik kayıtla çelişen ikinci bir gerçek üretirdi
// ve "hangisi doğru?" sorusunu operasyona bırakırdı. BFF proxy'si de
// yalnız `GET` açıyor.
import useSWR from "swr";

import {
  BosDurum,
  HataDurumu,
  IskeletMetin,
  Kart,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Gecis = {
  id: string;
  plaka: string;
  arac_tanim: string | null;
  giris_zamani: string;
  cikis_zamani: string | null;
  unit_no: string | null;
  ziyaretci_mi: boolean;
};

export default function AracGecisleriPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Gecis[] }>(
    "/api/vehicle-passes?limit=50&offset=0",
    jsonFetcher,
  );
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("aracBaslik")}
      </h1>
      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("aracOtomatikNot")}</p>
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("aracYok")} />
        </Kart>
      ) : null}
      {kayitlar.map((g) => (
        <Kart key={g.id} className="space-y-1">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 className="font-medium tabular-nums">{g.plaka}</h2>
            <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{g.unit_no ?? "—"}</span>
          </div>
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {tarihSaatUzun(g.giris_zamani)}
            {g.cikis_zamani ? ` → ${tarihSaatUzun(g.cikis_zamani)}` : ""}
          </p>
          {g.arac_tanim ? <p className="text-sm">{g.arac_tanim}</p> : null}
        </Kart>
      ))}
    </div>
  );
}
