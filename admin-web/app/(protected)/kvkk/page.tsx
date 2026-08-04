"use client";

// (P126.3) KVKK TERCİHLERİM — pazarlama izinleri.
//
// ÜÇ BAĞIMSIZ KANAL (e-posta / SMS / arama). Tek bir "pazarlama" bayrağı,
// kişiyi istemediği kanaldan mesaj almak ile hiç almamak arasında seçmeye
// zorlardı — sunucu şemasının gerekçesi burada da geçerli.
//
// HESAP SİLME BU SAYFADA YOK: mobilde var (P112, App Store 5.1.1(v) şartı)
// ve geri alınamaz bir işlemdir; web'e taşımak kendi onay akışını ister.
// Yarım bir silme düğmesi koymaktansa hiç koymamak doğru.
import { useEffect, useState } from "react";
import useSWR from "swr";

import { ErrorBox, PageHeader, btnPrimary, cardCls } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

type Tercihler = { eposta: boolean; sms: boolean; arama: boolean };

export default function KvkkPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<Tercihler>(
    "/api/me/pazarlama",
    jsonFetcher,
  );

  const [tercih, setTercih] = useState<Tercihler>({
    eposta: false,
    sms: false,
    arama: false,
  });
  const [kaydediyor, setKaydediyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  // Sunucudan gelen değer forma BİR KEZ yüklenir; kullanıcı seçim yaparken
  // SWR yeniden doğrulaması seçimini EZMESİN.
  useEffect(() => {
    if (!data) return;
    setTercih({ eposta: data.eposta, sms: data.sms, arama: data.arama });
  }, [data?.eposta, data?.sms, data?.arama]); // eslint-disable-line react-hooks/exhaustive-deps

  async function kaydet() {
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/me/pazarlama", "PATCH", tercih);
      toast.success(t("kvkkKaydedildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  const KANALLAR = [
    { alan: "eposta" as const, etiket: t("kvkkEposta") },
    { alan: "sms" as const, etiket: t("kvkkSms") },
    { alan: "arama" as const, etiket: t("kvkkArama") },
  ];

  return (
    <div className="space-y-6">
      <PageHeader title={t("kvkkBaslik")} />
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("kvkkPazarlama")}</h2>
        <p className="text-sm text-muted">{t("kvkkPazarlamaAciklama")}</p>
        {isLoading ? (
          <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
        ) : (
          <div className="space-y-2">
            {KANALLAR.map((k) => (
              <label key={k.alan} className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={tercih[k.alan]}
                  onChange={(e) =>
                    setTercih({ ...tercih, [k.alan]: e.target.checked })
                  }
                />
                {k.etiket}
              </label>
            ))}
          </div>
        )}
        <ErrorBox message={hata} />
        <div>
          <button
            className={btnPrimary}
            disabled={kaydediyor}
            onClick={() => void kaydet()}
          >
            {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </button>
        </div>
      </section>

      <section className={`${cardCls} space-y-2 p-5`}>
        <h2 className="font-medium">{t("kvkkBelgeler")}</h2>
        <ul className="space-y-1 text-sm">
          <li>
            <a className="underline" href="/gizlilik" target="_blank" rel="noreferrer">
              {t("kvkkGizlilik")}
            </a>
          </li>
          <li>
            <a className="underline" href="/kosullar" target="_blank" rel="noreferrer">
              {t("kvkkKosullar")}
            </a>
          </li>
        </ul>
      </section>
    </div>
  );
}
