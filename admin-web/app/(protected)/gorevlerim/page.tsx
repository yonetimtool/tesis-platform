"use client";

// (P126.6) GÖREVLERİM — saha rolünün kendi görevleri.
//
// Paneldeki `/tasks` YÖNETİM ekranıdır: görev tanımlar, atar. Burası
// görevi YAPAN tarafın ekranı. Sunucu `/tasks`ı saha rolleri için ZATEN
// kendi-kapsamlı döner ("saha rolü YALNIZ kendine atanan görevleri okur —
// katı: havuz/grup görünürlüğü YOK"), bu yüzden istemci süzgeci yok.
//
// İKİ KISIT DÜRÜSTÇE GÖSTERİLİR (gizlenmez):
//  * `foto_zorunlu` görev fotoğraf kanıtı olmadan tamamlanamaz — web'de
//    yükleme akışı yok, o görevler mobilde tamamlanır. Düğmeyi aktif
//    bırakıp 422 aldırmak "bozuk" izlenimi verirdi.
//  * NFC okutma donanıma bağlıdır ve tarayıcıda yoktur. Sunucu NFC'yi
//    yalnız GÖNDERİLDİYSE doğrular, yani web tamamlaması geçerlidir —
//    ama kontrol noktasına bağlı görevde okutma kanıtı OLUŞMAZ ve bu
//    ekranda yazılıdır.
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  PageHeader,
  btnGhost,
  cardCls,
  inputCls,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend, genIdempotencyKey } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { tarihSaatUzun } from "@/lib/tarih";

type Gorev = {
  id: string;
  ad: string;
  aciklama: string | null;
  checkpoint_id: string | null;
  foto_zorunlu: boolean;
  sonraki_planlanan: string | null;
  aktif: boolean;
};

export default function GorevlerimPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Gorev[] }>(
    "/api/tasks?limit=50&offset=0",
    jsonFetcher,
  );

  const [notlar, setNotlar] = useState<Record<string, string>>({});
  const [calisan, setCalisan] = useState<string | null>(null);

  const gorevler = (data?.items ?? []).filter((g) => g.aktif);

  async function tamamla(g: Gorev) {
    setCalisan(g.id);
    try {
      await apiSend(
        `/api/tasks/${g.id}/completions`,
        "POST",
        {
          tamamlanma_zamani: new Date().toISOString(),
          notlar: notlar[g.id]?.trim() || null,
        },
        // Cift tiklama/ag tekrari ayni gorevi iki kez tamamlamamali.
        { "Idempotency-Key": genIdempotencyKey() },
      );
      setNotlar({ ...notlar, [g.id]: "" });
      toast.success(t("gorevimTamamlandi"));
      void mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setCalisan(null);
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader title={t("gorevimBaslik")} />
      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
      ) : null}
      {!isLoading && !error && gorevler.length === 0 ? (
        <EmptyState title={t("gorevimYok")} />
      ) : null}

      {gorevler.map((g) => (
        <article key={g.id} className={`${cardCls} space-y-2 p-4`}>
          <h2 className="font-medium">{g.ad}</h2>
          {g.sonraki_planlanan ? (
            <p className="text-xs text-muted">
              {tarihSaatUzun(g.sonraki_planlanan)}
            </p>
          ) : null}
          {g.aciklama ? <p className="text-sm">{g.aciklama}</p> : null}

          {g.checkpoint_id ? (
            <p className="text-xs text-muted">{t("gorevimNfcNotu")}</p>
          ) : null}

          {g.foto_zorunlu ? (
            // Dugme AKTIF BIRAKILIP 422 aldirilmaz: sebebi yazilir.
            <p className="text-sm text-amber-700">{t("gorevimFotoMobil")}</p>
          ) : (
            <div className="space-y-2">
              <input
                className={inputCls}
                value={notlar[g.id] ?? ""}
                onChange={(e) =>
                  setNotlar({ ...notlar, [g.id]: e.target.value })
                }
                // `placeholder` bir ERISILEBILIR AD DEGILDIR: ekran
                // okuyucu onu ad olarak okumaz ve yazi girilince kaybolur.
                // Her gorev karti icin gorunur bir etiket koymak listeyi
                // gurultulu yapardi; `aria-label` dogru cozum.
                aria-label={t("gorevimNot")}
                placeholder={t("gorevimNot")}
                maxLength={500}
              />
              <button
                className={btnGhost}
                disabled={calisan === g.id}
                onClick={() => void tamamla(g)}
              >
                {calisan === g.id
                  ? t("ortakKaydediliyor")
                  : t("gorevimTamamla")}
              </button>
            </div>
          )}
        </article>
      ))}
    </div>
  );
}
