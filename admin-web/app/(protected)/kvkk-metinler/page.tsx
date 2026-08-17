"use client";

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  CokSatir,
  Dugme,
  HataDurumu,
  Kart,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P167 §6.1) KVKK AYDINLATMA METNI — Yonetisim sayfasindan TASINDI.
 *
 * Brief "Yonetisim alt basligi tamamen kaldirilsin" diyor ama genel kisit
 * "mevcut islev kaybolmayacak". Bu bolum o sayfanin icindeydi ve gidecek
 * baska bir yeri yoktu: `/kvkk` sayfasi KULLANICININ KENDI pazarlama
 * tercihleridir, tesisin YAYINLADIGI metin degil. Ikisini ayni ekrana
 * koymak, "benim iznim" ile "sitenin metni"ni karistirmak olurdu.
 *
 * DUZENLEME UCU YOK (P36) ve olmamali: yayinlanmis bir metnin govdesini
 * degistirmek, dun verilen onayi bugun BASKA BIR METNE ait gostermek
 * olurdu. Her yayin yeni bir SURUMDUR; ayni govde 409 doner.
 */

interface KvkkMetin {
  id: string;
  surum: number;
  baslik: string;
  govde: string;
  created_at: string;
}

const BOS = "";

export default function KvkkMetinlerPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, mutate } = useSWR<KvkkMetin[]>(
    "/api/panel/kvkk-metinler",
    jsonFetcher,
  );

  const [baslik, setBaslik] = useState(BOS);
  const [govde, setGovde] = useState(BOS);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  async function yayinla(): Promise<void> {
    setHata(null);
    if (!baslik.trim() || !govde.trim()) {
      setHata(t("yonKvkkZorunlu"));
      return;
    }
    setMesgul(true);
    try {
      await apiSend("/api/panel/kvkk-metin", "POST", {
        baslik: baslik.trim(),
        govde: govde.trim(),
      });
      setBaslik(BOS);
      setGovde(BOS);
      toast.success(t("yonKvkkYayinlandi"));
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("yonKvkk")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("yonKvkkNotu")}
        </p>
      </div>

      {hata ? <HataDurumu mesaj={hata} /> : null}

      <Kart>
        <h2
          className="mb-3"
          style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}
        >
          {t("kvkkMetinSurumler")}
        </h2>
        <HataDurumu mesaj={error ? t("yonKvkkHata") : null} />
        {data && data.length === 0 && !error ? (
          <BosDurum baslik={t("yonKvkkYok")} aciklama={t("yonKvkkYokAlt")} />
        ) : null}
        {data && data.length > 0 ? (
          <ul className="space-y-1">
            {data.map((m) => (
              <li
                key={m.id}
                className="flex justify-between gap-3"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
              >
                <span>
                  v{m.surum} · {m.baslik}
                </span>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {formatDateTime(m.created_at)}
                </span>
              </li>
            ))}
          </ul>
        ) : null}
      </Kart>

      <Kart>
        <h2
          className="mb-3"
          style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}
        >
          {t("kvkkMetinYeniSurum")}
        </h2>
        <AlanSarmal etiket={t("yonKvkkBaslik")} zorunlu>
          {(b) => <Alan {...b} value={baslik} onChange={(e) => setBaslik(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("yonKvkkGovde")} zorunlu>
          {(b) => (
            <CokSatir {...b} rows={8} value={govde} onChange={(e) => setGovde(e.target.value)} />
          )}
        </AlanSarmal>
        <Dugme tur="birincil" disabled={mesgul} onClick={() => void yayinla()}>
          {t("yonKvkkYayinla")}
        </Dugme>
      </Kart>
    </div>
  );
}
