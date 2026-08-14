"use client";

import { useState } from "react";
import useSWR from "swr";

import {
  CokSatir,
  Kart,
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 7.2) ANKETLER — kendi sayfasi.
 *
 * NEDEN TASINDI: anket yonetimi `/portal` ("Site sayfasi") icinde
 * yasiyordu ve brief o sayfanin KALDIRILMASINI istiyor. Ama anket
 * calisan bir ozellik ve mobil karsiligi BILEREK salt-okuma
 * ("olusturma/kapatma YONETIM isidir ve panele"). Portali oldugu gibi
 * silmek, anketi ACILAMAZ hâle getirirdi.
 *
 * UC DEGISMEDI (`/anketler`): bu bir yuzey tasima, sozlesme degisikligi
 * degil. Mobil istemci etkilenmez.
 *
 * SONUC KAPANANA KADAR GIZLI (P38) ve bu sayfa onu DEGISTIRMEZ: sayilar
 * sunucudan geldigi gibi cizilir. Gelmiyorsa hic cizilmez — SIFIR
 * UYDURULMAZ, cunku "0 oy" ile "sonuc gizli" ayni sey degildir.
 */

interface Secenek {
  id: string;
  metin: string;
  oy: number | null;
}
interface Anket {
  id: string;
  baslik: string;
  aciklama: string | null;
  acik: boolean;
  aktif: boolean;
  toplam_oy: number | null;
  secenekler: Secenek[];
}

export default function AnketlerPage() {
  const t = useT();
  const toast = useToast();
  const [hata, setHata] = useState<string | null>(null);
  const [baslik, setBaslik] = useState("");
  const [secenekMetni, setSecenekMetni] = useState("");

  const {
    data: anketler,
    error: aErr,
    mutate: tazele,
  } = useSWR<{ items: Anket[] }>("/api/panel/anketler?limit=50", jsonFetcher);

  async function ekle(): Promise<void> {
    setHata(null);
    const secenekler = secenekMetni
      .split("\n")
      .map((x) => x.trim())
      .filter(Boolean)
      .map((metin, i) => ({ metin, sira: i }));
    if (!baslik.trim() || secenekler.length < 2) {
      // EN AZ IKI secenek (P38): tek secenekli anket oy toplamaz, ONAY
      // toplar — bunu sunucuya sorup 422 almak yerine burada soyluyoruz.
      setHata(t("anketEnAzIki"));
      return;
    }
    try {
      await apiSend("/api/panel/anketler", "POST", { baslik, secenekler });
      setBaslik("");
      setSecenekMetni("");
      toast.success(t("anketEklendi"));
      await tazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function kapat(id: string): Promise<void> {
    try {
      await apiSend(`/api/panel/anketler/${id}`, "PATCH", { aktif: false });
      toast.success(t("anketKapatildi"));
      await tazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukAnketler")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("anketAlt")}
        </p>
      </div>
      <HataDurumu mesaj={hata ?? (aErr ? t("anketHata") : null)} />

      <Kart>
        {anketler && anketler.items.length === 0 ? (
          <BosDurum baslik={t("anketYok")} aciklama={t("anketYokAlt")} />
        ) : null}

        <div className="space-y-3">
          {(anketler?.items ?? []).map((a) => (
            <div
              key={a.id}
              className="p-3"
              style={{
                borderRadius: "var(--yz-radius-btn)",
                border: "1px solid var(--yz-border)",
                fontSize: "var(--yz-fs-sm)",
                color: "var(--yz-text)",
              }}
            >
              <div className="flex items-center justify-between gap-3">
                <span style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{a.baslik}</span>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {a.acik ? t("anketAcik") : t("anketKapali")}
                  {a.toplam_oy != null ? ` · ${a.toplam_oy}` : ""}
                </span>
              </div>
              <ul className="mt-2 space-y-1 text-xs">
                {a.secenekler.map((s) => (
                  <li key={s.id} className="flex justify-between">
                    <span>{s.metin}</span>
                    {/* Yonetim sonucu HER ZAMAN gorur (P38) — sayi sunucudan
                        gelmiyorsa hic cizilmez, sifir UYDURULMAZ. */}
                    {s.oy != null ? (
                      <span className="tabular-nums">{s.oy}</span>
                    ) : null}
                  </li>
                ))}
              </ul>
              {a.aktif ? (
                <Dugme
                  className="mt-2"
                  tur="tehlike"
                  boy="kucuk"
                  onClick={() => void kapat(a.id)}
                >
                  {t("anketKapat")}
                </Dugme>
              ) : null}
            </div>
          ))}
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("anketBaslik")}>
  {(b) => (
    <Alan {...b} value={baslik}
              onChange={(e) => setBaslik(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("anketSecenekler")} ipucu={t("anketSecenekIpucu")}>
            {(b) => (
              <CokSatir
                {...b}
                rows={3}
                value={secenekMetni}
                onChange={(e) => setSecenekMetni(e.target.value)}
              />
            )}
          </AlanSarmal>
        </div>
        <Dugme
          type="button"
          tur="birincil"
          onClick={() => void ekle()}
        >
          {t("anketEkle")}
        </Dugme>
      </Kart>
    </div>
  );
}
