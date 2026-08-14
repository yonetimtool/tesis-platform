"use client";

// (P126.3) SİTE KURALLARI — sakin görünümü (SALT OKUMA).
//
// `sira` alanına göre sunucu sıralar; ekran o sırayı BOZMAZ — kurallar
// numaralandırılmış bir metindir ve yönetimin verdiği sıra anlamlıdır.
import useSWR from "swr";

import {
  BosDurum,
  HataDurumu,
  IskeletMetin,
  Kart,
} from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

type Kural = {
  id: string;
  baslik: string;
  icerik: string;
  sira: number;
};

export default function SiteKurallariPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Kural[] }>(
    "/api/site-rules?limit=50&offset=0",
    jsonFetcher,
  );
  const kurallar = data?.items ?? [];

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("sakinKurallarBaslik")}
      </h1>
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && kurallar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("sakinKurallarYok")} />
        </Kart>
      ) : null}
      <ol className="space-y-3">
        {kurallar.map((k) => (
          <li key={k.id} className="space-y-1">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{k.baslik}</h2>
            <p className="whitespace-pre-line" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>{k.icerik}</p>
          </li>
        ))}
      </ol>
    </div>
  );
}
