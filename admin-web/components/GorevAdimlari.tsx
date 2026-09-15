"use client";

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, BosDurum, Dugme, Kart, useOnay } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { PresignTicket, TaskStepList } from "@/lib/types";

/**
 * (P237 §2) GOREV ALT ADIMLARI — web yuzeyi.
 *
 * =========================================================================
 * NEDEN AYRI BILESEN
 * =========================================================================
 * `tasks/page.tsx` 1100 satir ve iki gorunum (tablo + takvim) tasiyor.
 * Adim akisi kendi durumunu (ekleme formu, yukleme bileti, hata) tutuyor;
 * sayfaya gommek o dosyayi okunamaz hale getirirdi.
 *
 * =========================================================================
 * WEB'DE DE TAMAMLAMA VAR — FOTOGRAFLA
 * =========================================================================
 * Ilk tasarimda web yalniz IZLEYICI olacakti ("adimi saha kapatir").
 * Parite kurali bunu curuttu: yonetici ofisten bir adimi kapatmak
 * isteyebilir ve `foto_zorunlu` adimda yuklemesiz bir dugme 422 verirdi.
 * Bu yuzden presign akisi (duyuru gorseliyle ayni desen) buraya da kondu.
 */
export function GorevAdimlari({
  taskId,
  adimSirali,
  onDegisti,
}: {
  taskId: string;
  adimSirali?: boolean;
  onDegisti?: () => void;
}): React.ReactElement {
  const t = useT();
  const toast = useToast();
  // (P161) YIKICI ONAY tarayicinin `confirm()`u ile SORULMAZ: o diyalog
  // temayi ve dili tanimaz. `modal-tasima` kilidi bunu kaynakta zorluyor.
  const { onayla, diyalog } = useOnay();
  const yol = `/api/tasks/${taskId}/adimlar`;
  const { data, mutate } = useSWR<TaskStepList>(yol, jsonFetcher);
  const [yeniAd, setYeniAd] = useState("");
  const [mesgul, setMesgul] = useState(false);
  const [yukleniyor, setYukleniyor] = useState<string | null>(null);

  const adimlar = data?.items ?? [];
  const tamam = adimlar.filter((a) => a.tamamlandi).length;

  async function tazele(): Promise<void> {
    await mutate();
    onDegisti?.();
  }

  async function ekle(): Promise<void> {
    const ad = yeniAd.trim();
    if (!ad) return;
    setMesgul(true);
    try {
      // SIRA GELIS SIRASI: hepsini 0 birakmak, "sirali" gorevlerde akisi
      // rastgele yapardi.
      await apiSend(yol, "POST", { ad, sira: adimlar.length });
      setYeniAd("");
      await tazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  async function sil(stepId: string): Promise<void> {
    const onay = await onayla({
      baslik: t("gorevAdimSil"),
      mesaj: t("gorevAdimSilOnay"),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!onay) return;
    try {
      await apiSend(`${yol}/${stepId}`, "DELETE");
      await tazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function geriAl(stepId: string): Promise<void> {
    try {
      await apiSend(`${yol}/${stepId}/geri-al`, "POST", {});
      await tazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function tamamla(stepId: string, fotoKey?: string): Promise<void> {
    try {
      await apiSend(`${yol}/${stepId}/tamamla`, "POST", {
        foto_key: fotoKey ?? null,
      });
      await tazele();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  /** Duyuru gorseliyle AYNI desen: presign -> PUT -> foto_key. */
  async function fotoylaTamamla(stepId: string, dosya: File): Promise<void> {
    setYukleniyor(stepId);
    try {
      const bilet = await apiSend<PresignTicket>(
        "/api/uploads/presign",
        "POST",
        { content_type: dosya.type || "image/jpeg", dosya_adi: dosya.name },
      );
      const put = await fetch(bilet.upload_url, {
        method: "PUT",
        headers: { "Content-Type": dosya.type || "image/jpeg" },
        body: dosya,
      });
      if (!put.ok) throw new Error(t("yuklemeBasarisiz", { kod: put.status }));
      await tamamla(stepId, bilet.foto_key);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setYukleniyor(null);
    }
  }

  return (
    <Kart className="space-y-3" data-test="gorev-adimlari">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="text-base font-medium">{t("gorevAdimlar")}</h3>
        <span className="text-sm text-metin-muted" data-test="gorev-adim-ilerleme">
          {t("gorevAdimIlerleme", {
            tamam: String(tamam),
            toplam: String(adimlar.length),
          })}
        </span>
      </div>
      {adimSirali ? (
        <p className="text-xs text-metin-muted">{t("gorevAdimSirali")}</p>
      ) : null}

      {adimlar.length === 0 ? (
        <BosDurum baslik={t("gorevAdimYok")} />
      ) : (
        <ul className="space-y-2">
          {adimlar.map((a) => (
            <li
              key={a.id}
              data-test={`gorev-adim-${a.id}`}
              className="flex flex-wrap items-center gap-2 rounded-lg border kart-kenar p-2"
            >
              <span className="min-w-0 flex-1">
                <span className="font-medium">{a.ad}</span>
                {a.foto_zorunlu ? (
                  <span className="ms-2 rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-900">
                    {t("gorevAdimFotoZorunlu")}
                  </span>
                ) : null}
                {a.tamamlandi ? (
                  <span className="block text-xs text-metin-muted">
                    {a.tamamlayan_ad ?? ""}
                    {a.tamamlanma_zamani
                      ? ` · ${formatDateTime(a.tamamlanma_zamani)}`
                      : ""}
                    {a.notlar ? ` · ${a.notlar}` : ""}
                  </span>
                ) : null}
              </span>
              {a.foto_url ? (
                <a href={a.foto_url} target="_blank" rel="noreferrer">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={a.foto_url}
                    alt={a.ad}
                    loading="lazy"
                    decoding="async"
                    className="h-10 w-14 rounded object-cover"
                  />
                </a>
              ) : null}
              {a.tamamlandi ? (
                <Dugme
                  boy="kucuk"
                  tur="ikincil"
                  data-test={`gorev-adim-geri-al-${a.id}`}
                  onClick={() => void geriAl(a.id)}
                >
                  {t("gorevAdimGeriAl")}
                </Dugme>
              ) : a.foto_zorunlu ? (
                <label className="cursor-pointer rounded-md border kart-kenar px-2 py-1 text-sm">
                  {yukleniyor === a.id ? "…" : t("gorevAdimTamamla")}
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    data-test={`gorev-adim-foto-${a.id}`}
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) void fotoylaTamamla(a.id, f);
                    }}
                  />
                </label>
              ) : (
                <Dugme
                  boy="kucuk"
                  data-test={`gorev-adim-tamamla-${a.id}`}
                  onClick={() => void tamamla(a.id)}
                >
                  {t("gorevAdimTamamla")}
                </Dugme>
              )}
              <Dugme
                boy="kucuk"
                tur="sessiz"
                data-test={`gorev-adim-sil-${a.id}`}
                onClick={() => void sil(a.id)}
              >
                {t("gorevAdimSil")}
              </Dugme>
            </li>
          ))}
        </ul>
      )}

      <div className="flex flex-wrap items-end gap-2">
        <div className="min-w-0 flex-1">
          <AlanSarmal etiket={t("gorevAdimAd")}>
            {(b) => (
              <Alan
                {...b}
                value={yeniAd}
                data-test="gorev-adim-yeni"
                onChange={(e) => setYeniAd(e.target.value)}
              />
            )}
          </AlanSarmal>
        </div>
        <Dugme
          disabled={mesgul || !yeniAd.trim()}
          data-test="gorev-adim-ekle"
          onClick={() => void ekle()}
        >
          {t("gorevAdimEkle")}
        </Dugme>
      </div>
      {diyalog}
    </Kart>
  );
}
