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

import {
  Alan,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
} from "@/components/ui";
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
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("gorevimBaslik")}
      </h1>
      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
      {isLoading ? (
        <IskeletMetin satir={3} />
      ) : null}
      {!isLoading && !error && gorevler.length === 0 ? (
        <BosDurum baslik={t("gorevimYok")} />
      ) : null}

      {gorevler.map((g) => (
        <article key={g.id} className="space-y-2">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{g.ad}</h2>
          {g.sonraki_planlanan ? (
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {tarihSaatUzun(g.sonraki_planlanan)}
            </p>
          ) : null}
          {g.aciklama ? <p className="text-sm">{g.aciklama}</p> : null}

          {g.checkpoint_id ? (
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("gorevimNfcNotu")}</p>
          ) : null}

          {g.foto_zorunlu ? (
            // Dugme AKTIF BIRAKILIP 422 aldirilmaz: sebebi yazilir.
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-warning-ink)" }}>
              {t("gorevimFotoMobil")}
            </p>
          ) : (
            <div className="space-y-2">
              {/* `placeholder` bir ERISILEBILIR AD DEGILDIR: ekran
                  okuyucu onu ad olarak okumaz ve yazi girilince kaybolur.
                  Her gorev karti icin gorunur bir etiket koymak listeyi
                  gurultulu yapardi; `aria-label` dogru cozum. */}
              <Alan
                aria-label={t("gorevimNot")}
                value={notlar[g.id] ?? ""}
                onChange={(e) =>
                  setNotlar({ ...notlar, [g.id]: e.target.value })
                }
                placeholder={t("gorevimNot")}
                maxLength={500}
              />
              <Dugme
                boy="kucuk"
                disabled={calisan === g.id}
                onClick={() => void tamamla(g)}
              >
                {calisan === g.id
                  ? t("ortakKaydediliyor")
                  : t("gorevimTamamla")}
              </Dugme>
            </div>
          )}
        </article>
      ))}
    </div>
  );
}
