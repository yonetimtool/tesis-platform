"use client";

// (P126.3) DUYURULAR — sakin görünümü (SALT OKUMA).
//
// Paneldeki `/announcements` yönetim ekranıdır: duyuru yazar, siler.
// Burası okuyan tarafın ekranı; aynı uçtan beslenir çünkü duyuru zaten
// tesise açıktır — kendi-kapsam kuralı gerekmez.
//
// YAZMA DÜĞMESİ YOK: sunucu yönetici olmayanı zaten reddeder, ama
// kullanıcıya basıp 403 alacağı bir düğme göstermek "yetkim var sandım"
// demektir.
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

type Duyuru = {
  id: string;
  baslik: string;
  govde: string;
  created_at: string;
};

export default function DuyurularPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Duyuru[] }>(
    "/api/announcements?limit=50&offset=0",
    jsonFetcher,
  );
  const kayitlar = data?.items ?? [];

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("sakinDuyurularBaslik")}
      </h1>
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && kayitlar.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("sakinDuyurularYok")} />
        </Kart>
      ) : null}
      {kayitlar.map((d) => (
        <Kart key={d.id} className="space-y-1">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{d.baslik}</h2>
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{tarihSaatUzun(d.created_at)}</p>
          <p className="whitespace-pre-line" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>{d.govde}</p>
        </Kart>
      ))}
    </div>
  );
}
