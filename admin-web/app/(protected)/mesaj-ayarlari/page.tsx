"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";

import { MesajAyarlariFormu } from "@/components/mesaj/ayarlar-formu";
import { Alan, AlanSarmal, Dugme, HataDurumu, Kart } from "@/components/ui";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { SINIR } from "@/lib/girdi-siniri";

/**
 * (P250 §8) SMS / E-POSTA TEKNIK AYARLARI — PLATFORM PANELI.
 *
 * Saglayici, kullanici adi, parola, gonderen adi, kota: bunlar platformun
 * isidir. Yonetici yanlis bir SMTP parolasi girip tesisin butun davet ve
 * hatirlatma e-postalarini SESSIZCE durdurabiliyordu; artik yalniz
 * "hazir mi" durumunu gorur ve mesaj gonderir / sablon yazar.
 *
 * TESIS SECIMI ARAMAYLA: prod'da binlerce tesis var (tek liste yaniti
 * yuzlerce KB idi, bkz. `/api/tenants` notu); ilk 20 eslesme gosterilir.
 */
interface TesisSatiri {
  id: string;
  ad: string;
}

const SAYFA = 20 as const;
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`): dugme turu kimlikleri.
const TUR_SECILI = "birincil" as const;
const TUR_DIGER = "sessiz" as const;

export default function MesajAyarlariPlatformPage() {
  const t = useT();
  const [arama, setArama] = useState("");
  const [gecikmeli, setGecikmeli] = useState("");
  const [secili, setSecili] = useState<TesisSatiri | null>(null);
  useEffect(() => {
    const z = setTimeout(() => setGecikmeli(arama.trim()), 250);
    return () => clearTimeout(z);
  }, [arama]);

  const sorgu = new URLSearchParams({ limit: String(SAYFA), offset: "0" });
  if (gecikmeli) sorgu.set("q", gecikmeli);
  const { data, error } = useSWR<{ items: TesisSatiri[] }>(`/api/tenants?${sorgu}`, jsonFetcher);
  const liste = data?.items ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("mesajAyarPanelBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("mesajAyarPanelAlt")}
        </p>
      </div>

      <Kart className="space-y-3">
        <AlanSarmal etiket={t("mesajAyarTesisAra")}>
          {(b) => (
            <Alan
              {...b}
              maxLength={SINIR.AD}
              value={arama}
              data-test="mesaj-ayar-tesis-ara"
              onChange={(e) => setArama(e.target.value)}
            />
          )}
        </AlanSarmal>
        <HataDurumu mesaj={error ? (error as Error).message : null} />
        {data && liste.length === 0 ? (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("mesajAyarTesisYok")}
          </p>
        ) : (
          <ul className="flex flex-wrap gap-2" data-test="mesaj-ayar-tesisler">
            {liste.map((x) => (
              <li key={x.id}>
                <Dugme
                  boy="kucuk"
                  tur={secili?.id === x.id ? TUR_SECILI : TUR_DIGER}
                  aria-pressed={secili?.id === x.id}
                  onClick={() => setSecili(x)}
                >
                  {x.ad}
                </Dugme>
              </li>
            ))}
          </ul>
        )}
      </Kart>

      {secili ? (
        <section className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("mesajAyarSecili", { ad: secili.ad })}
          </h2>
          {/* `key`: tesis degisince form durumu (yazilmis ama kaydedilmemis
              alanlar) SIFIRLANIR — A tesisine yazilan parola B'ye gitmesin. */}
          <MesajAyarlariFormu
            key={secili.id}
            uc={`/api/tenants/${encodeURIComponent(secili.id)}/mesaj-ayarlari`}
          />
        </section>
      ) : (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("mesajAyarTesisSec")}
        </p>
      )}
    </div>
  );
}
