"use client";

// (P126.5) KAMERALAR — canlı karo ızgarası (P121 deseninin web ikizi).
//
// OYNATICI IZGARADA YOK, P121'deki gerekçenin aynısı: N video oynatıcıyı
// aynı anda çalıştırmak pil/bant genişliği açısından pahalıdır. Karo
// `snapshot_url`den durağan kare çeker ve yalnız sekme GÖRÜNÜRKEN
// tazelenir (`document.visibilityState`) — mobilde bu, ekran görünürlüğü
// ve uygulama ön planı ile yapılıyordu.
//
// TAM EKRAN OYNATMA BU DİLİMDE **YOK**. Neden: `stream_url` HLS'tir;
// Safari `.m3u8`i yerel oynatır ama Chrome/Firefox oynatmaz — orada
// `<video>` sessizce siyah kalırdı. Çalışması için `hls.js` (~150 KB)
// gerekir ve bu bir BAĞIMLILIK KARARIDIR; tek başıma almadım. Tarayıcıların
// yarısında çalışan bir oynat düğmesi, hiç olmayandan kötüdür: kullanıcı
// bozuk olanın kamera mı tarayıcı mı olduğunu bilemez. Karo canlı kareyi
// gösterir; oynatma mobilde çalışıyor (P124'te ölçüldü).
//
// YÖNETİM (ekle/düzenle/sil) BU DİLİMDE YOK: desteklenen-kaynak kuralı
// mobilde `CameraDraft` içinde yaşıyor (P121) ve TS'e ikinci kez yazmak iki
// kopyanın ayrışması demekti.
import { useEffect, useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, PageHeader, cardCls } from "@/components/form";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

type Kamera = {
  id: string;
  ad: string;
  konum: string | null;
  snapshot_url: string | null;
  oynatilabilir: boolean;
  aktif: boolean;
};

/** Kare tazeleme araligi — mobildeki `kareAraligi` ile ayni (8 sn). */
const KARE_ARALIGI_MS = 8000;

export default function KameralarPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<{ items: Kamera[] }>(
    "/api/cameras?limit=50&offset=0",
    jsonFetcher,
  );
  const kameralar = (data?.items ?? []).filter((k) => k.aktif);
  const kareCekilebilir = kameralar.some((k) => !!k.snapshot_url);

  // NESİL SAYACI: adrese eklenerek önbelleği kırar. Zaman damgası yerine
  // sayaç — testte deterministik olsun diye (mobildeki gerekçenin aynısı).
  const [nesil, setNesil] = useState(0);

  useEffect(() => {
    // Kare çekebilen kamera yoksa zamanlayıcı HİÇ kurulmaz.
    if (!kareCekilebilir) return;
    let zamanlayici: ReturnType<typeof setInterval> | null = null;

    function baslat() {
      if (zamanlayici) return;
      zamanlayici = setInterval(() => setNesil((n) => n + 1), KARE_ARALIGI_MS);
    }
    function durdur() {
      if (!zamanlayici) return;
      clearInterval(zamanlayici);
      zamanlayici = null;
    }
    function gorunurlukDegisti() {
      // SEKME ARKA PLANDAYKEN İSTEK ATILMAZ. Bu olmadan açık bırakılmış bir
      // sekme, kimse bakmıyorken dakikada onlarca istek atardı.
      if (document.visibilityState === "visible") {
        setNesil((n) => n + 1);
        baslat();
      } else {
        durdur();
      }
    }

    if (document.visibilityState === "visible") baslat();
    document.addEventListener("visibilitychange", gorunurlukDegisti);
    return () => {
      durdur();
      document.removeEventListener("visibilitychange", gorunurlukDegisti);
    };
  }, [kareCekilebilir]);

  return (
    <div className="space-y-5">
      <PageHeader title={t("kameraBaslikWeb")} />
      <p className="text-sm text-muted">{t("kameraYonetimMobil")}</p>
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
      ) : null}
      {!isLoading && !error && kameralar.length === 0 ? (
        <EmptyState title={t("kameraYokWeb")} />
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {kameralar.map((k) => (
          <article key={k.id} className={`${cardCls} overflow-hidden`}>
            <div className="aspect-video bg-slate-100">
              {k.snapshot_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={`${k.snapshot_url}${k.snapshot_url.includes("?") ? "&" : "?"}_k=${nesil}`}
                  alt={k.ad}
                  className="h-full w-full object-cover"
                />
              ) : (
                <div className="flex h-full items-center justify-center text-xs text-muted">
                  {t("kameraKareYokWeb")}
                </div>
              )}
            </div>
            <div className="space-y-0.5 p-3">
              <h2 className="font-medium">{k.ad}</h2>
              {k.konum ? (
                <p className="text-xs text-muted">{k.konum}</p>
              ) : null}
              <p className="text-xs text-muted">
                {k.snapshot_url ? t("kameraCanliWeb") : t("kameraGoruntuYokWeb")}
              </p>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}
