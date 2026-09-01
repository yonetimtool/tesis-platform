"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Kart, Rozet } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { DILLER, DIL_ADLARI } from "@/lib/i18n/diller";

/**
 * (P202) ZORUNLU / ONERILEN GUNCELLEME — PLATFORM YONETIMI.
 *
 * =========================================================================
 * NEDEN BU EKRAN VAR
 * =========================================================================
 * Politika YENI SURUM YAYINLAMADAN degistirilebilmeli. Esikler koda ya da
 * ortam degiskenine gomulu olsaydi her degisiklik bir dagitim isterdi —
 * ve zorunlu guncelleme tam da acil bir guvenlik duzeltmesinde, en hizli
 * olmasi gereken anda en yavas arac olurdu.
 *
 * =========================================================================
 * IKI ESIK, IKI AYRI ANLAM
 * =========================================================================
 * ASGARI  — bunun ALTI uygulamayi KULLANAMAZ (kapatilamayan ekran).
 * ONERILEN— bunun ALTI UYARILIR ama kullanmaya devam eder.
 *
 * Ikisi de BOSALTILABILIR ve bos = O SEVIYE KAPALI. Bosaltma bir "geri
 * alma" dugmesidir: yanlis bir esik girildiginde politikayi kaldirmanin
 * yolu, sunucuya gitmeden burada olmali.
 *
 * =========================================================================
 * MESAJ ZORUNLU DEGIL
 * =========================================================================
 * Yedi dilin doldurulmasini SART kosmak, ozelligi kullanilmaz yapardi:
 * acil bir guvenlik duzeltmesinde operator ceviri beklemez. Bos
 * birakilirsa uygulama KENDI yerellestirilmis metnini gosterir.
 */

type Politika = {
  platform: string;
  asgari_surum: string | null;
  onerilen_surum: string | null;
  mesaj: Record<string, string>;
};

const UC = "/api/panel/surum-politikasi";

/** Sunucudaki bicim denetiminin ISTEMCI ESI — ayni kural, erken geri
 *  bildirim. Sunucu yine de dogrular (istemci kilidine guvenilmez). */
const SURUM_BICIMI = /^\d+(\.\d+){0,2}$/;

export default function SurumPolitikasiSayfasi() {
  const t = useT();
  const toast = useToast();
  const { data, error, mutate } = useSWR<{ ogeler: Politika[] }>(UC, jsonFetcher);

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("surumPolitikasiBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("surumPolitikasiAlt")}
        </p>
      </div>
      <HataDurumu mesaj={error ? t("ortakHataOlustu") : null} />
      {(data?.ogeler ?? []).map((p) => (
        <PlatformKarti key={p.platform} politika={p} tazele={mutate} toast={toast} />
      ))}
    </div>
  );
}

function PlatformKarti({
  politika,
  tazele,
  toast,
}: {
  politika: Politika;
  tazele: () => void;
  toast: ReturnType<typeof useToast>;
}) {
  const t = useT();
  const [asgari, setAsgari] = useState(politika.asgari_surum ?? "");
  const [onerilen, setOnerilen] = useState(politika.onerilen_surum ?? "");
  const [mesaj, setMesaj] = useState<Record<string, string>>(politika.mesaj ?? {});
  const [bekliyor, setBekliyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  // Sunucudan yeni veri gelince alanlar TAZELENIR: kaydettikten sonra
  // ekranin eski degeri gostermeye devam etmesi, operatore "kaydedilmedi"
  // dedirtirdi.
  useEffect(() => {
    setAsgari(politika.asgari_surum ?? "");
    setOnerilen(politika.onerilen_surum ?? "");
    setMesaj(politika.mesaj ?? {});
  }, [politika]);

  const asgariGecersiz = asgari.trim() !== "" && !SURUM_BICIMI.test(asgari.trim());
  const onerilenGecersiz =
    onerilen.trim() !== "" && !SURUM_BICIMI.test(onerilen.trim());

  async function kaydet() {
    if (asgariGecersiz || onerilenGecersiz) return;
    setBekliyor(true);
    setHata(null);
    try {
      await apiSend(`${UC}-${politika.platform}`, "PUT", {
        asgari_surum: asgari.trim() || null,
        onerilen_surum: onerilen.trim() || null,
        mesaj,
      });
      toast.success(t("ortakKaydedildi"));
      tazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  const etiket =
    politika.platform === "ios" ? t("surumPlatformIos") : t("surumPlatformAndroid");
  const acikSeviye = !!(politika.asgari_surum || politika.onerilen_surum);

  return (
    <Kart>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-base font-medium text-metin-body">{etiket}</h2>
        <Rozet durum={acikSeviye ? "uyari" : "notr"}>
          {acikSeviye ? t("surumPolitikaAcik") : t("surumPolitikaKapali")}
        </Rozet>
      </div>

      <div className="mt-3 grid gap-3 sm:grid-cols-2">
        <AlanSarmal
          etiket={t("surumAsgari")}
          ipucu={t("surumAsgariIpucu")}
          hata={asgariGecersiz ? t("surumBicimGecersiz") : undefined}
        >
          {(baglar) => (
            <Alan
              {...baglar}
              value={asgari}
              onChange={(e) => setAsgari(e.target.value)}
              placeholder="1.2.0"
              data-test={`surum-asgari-${politika.platform}`}
            />
          )}
        </AlanSarmal>
        <AlanSarmal
          etiket={t("surumOnerilen")}
          ipucu={t("surumOnerilenIpucu")}
          hata={onerilenGecersiz ? t("surumBicimGecersiz") : undefined}
        >
          {(baglar) => (
            <Alan
              {...baglar}
              value={onerilen}
              onChange={(e) => setOnerilen(e.target.value)}
              placeholder="1.3.0"
              data-test={`surum-onerilen-${politika.platform}`}
            />
          )}
        </AlanSarmal>
      </div>

      <p className="mt-3" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {t("surumMesajAciklama")}
      </p>
      <div className="mt-2 grid gap-2 sm:grid-cols-2">
        {DILLER.map((dil) => (
          <AlanSarmal key={dil} etiket={DIL_ADLARI[dil]}>
            {(baglar) => (
              <Alan
                {...baglar}
                value={mesaj[dil] ?? ""}
                onChange={(e) => setMesaj((o) => ({ ...o, [dil]: e.target.value }))}
                data-test={`surum-mesaj-${politika.platform}-${dil}`}
              />
            )}
          </AlanSarmal>
        ))}
      </div>

      <HataDurumu mesaj={hata} />
      <div className="mt-3">
        <Dugme
          type="button"
          onClick={() => void kaydet()}
          disabled={bekliyor || asgariGecersiz || onerilenGecersiz}
          data-test={`surum-kaydet-${politika.platform}`}
        >
          {bekliyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
        </Dugme>
      </div>
    </Kart>
  );
}
