"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import { btnDanger, btnGhost, btnPrimary, inputCls } from "@/components/form";
import { ApiHatasi, apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 6.4) NOT VE EK — panelin TEK ek yuzeyi.
 *
 * Brief: "Not ve ek sistemi ortak olacak, her varliga takilabilsin. Her
 * modul icin ayri dosya yukleme yazma." Bu bilesen `varlikTipi` +
 * `varlikId` alir ve daire, kisi, gorev, icra, dokuman, talep, firma,
 * blok ekranlarinin HEPSINDE ayni sekilde calisir.
 *
 * NOT VE DOSYA TEK LISTEDE: ikisi de "bu kayda iliskin ek bilgi". Ayirmak,
 * kullanicinin tek zaman cizgisinde gormek istedigi seyi ikiye bolerdi.
 *
 * YETKI BURADA DEGIL SUNUCUDA: bilesen kimin ne gorecegine karar vermez.
 * Yazma yetkisi olmayan bir kullanici POST'ta 403 alir; bu durumda yazma
 * alani GIZLENIR (asagida). Gizleme bir GUVENLIK onlemi degil, bos yere
 * doldurulup reddedilen bir forma engel — karar yine sunucunun.
 */

interface Ek {
  id: string;
  tur: "not" | "dosya";
  metin?: string | null;
  dosya_key?: string | null;
  dosya_adi?: string | null;
  olusturan_ad?: string | null;
  created_at: string;
}

interface PresignBileti {
  upload_url: string;
  foto_key: string;
}

const UC = "/api/panel/ekler";

export function Ekler({
  varlikTipi,
  varlikId,
}: {
  varlikTipi: string;
  varlikId: string;
}) {
  const t = useT();
  const [ekler, setEkler] = useState<Ek[]>([]);
  const [not, setNot] = useState("");
  const [mesgul, setMesgul] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  // Yazma yetkisi SUNUCUDAN ogrenilir: ilk 403'ten sonra form gizlenir.
  // Rol listesini istemcide tutmak, ikinci bir dogruluk kaynagi olurdu.
  const [yazabilir, setYazabilir] = useState(true);
  const dosyaRef = useRef<HTMLInputElement>(null);

  const sorgu = `${UC}?varlik_tipi=${encodeURIComponent(varlikTipi)}&varlik_id=${varlikId}`;

  const yukle = useCallback(async () => {
    try {
      const d = await jsonFetcher<{ items: Ek[] }>(sorgu);
      setEkler(d.items);
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }, [sorgu, t]);

  useEffect(() => {
    void yukle();
  }, [yukle]);

  async function gonder(govde: Record<string, unknown>) {
    setMesgul(true);
    setHata(null);
    try {
      await apiSend(UC, "POST", {
        varlik_tipi: varlikTipi,
        varlik_id: varlikId,
        ...govde,
      });
      await yukle();
    } catch (e) {
      if (e instanceof ApiHatasi && e.status === 403) setYazabilir(false);
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
    }
  }

  async function notEkle() {
    if (!not.trim()) return;
    await gonder({ tur: "not", metin: not.trim() });
    setNot("");
  }

  // DOSYA: once presign, sonra DOGRUDAN depoya PUT, en son anahtar
  // kaydedilir (duyuru/gorev ekranlariyla ayni akis). Dosyayi kendi
  // sunucumuzdan gecirmek, boyut sinirini iki yerde tutmak olurdu.
  async function dosyaSec(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    setMesgul(true);
    setHata(null);
    try {
      const bilet = await apiSend<PresignBileti>("/api/uploads/presign", "POST", {
        content_type: f.type || "application/octet-stream",
        dosya_adi: f.name,
      });
      const put = await fetch(bilet.upload_url, {
        method: "PUT",
        headers: { "Content-Type": f.type || "application/octet-stream" },
        body: f,
      });
      if (!put.ok) throw new Error(t("yuklemeBasarisiz", { kod: put.status }));
      await gonder({ tur: "dosya", dosya_key: bilet.foto_key, dosya_adi: f.name });
    } catch (err) {
      setHata(err instanceof Error ? err.message : t("ortakHataOlustu"));
    } finally {
      setMesgul(false);
      // Ayni dosya tekrar secilebilsin: `input` degeri temizlenmezse
      // `change` olayi ikinci kez tetiklenmez.
      if (dosyaRef.current) dosyaRef.current.value = "";
    }
  }

  async function sil(id: string) {
    if (!window.confirm(t("ekSilOnay"))) return;
    setHata(null);
    try {
      await apiSend(`${UC}/${id}`, "DELETE");
      await yukle();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  return (
    <section aria-label={t("ekBaslik")} className="flex flex-col gap-3">
      <h3 className="text-sm font-semibold text-metin-body">{t("ekBaslik")}</h3>

      {hata && (
        <p role="alert" className="text-sm text-vurguInk-red">
          {hata}
        </p>
      )}

      <ul className="flex flex-col gap-2">
        {ekler.length === 0 && (
          <li className="text-sm text-metin-muted">{t("ekYok")}</li>
        )}
        {ekler.map((e) => (
          <li
            key={e.id}
            className="kart-kenar flex items-start justify-between gap-3 rounded-kart border p-2"
          >
            <div className="min-w-0">
              {e.tur === "not" ? (
                <p className="whitespace-pre-wrap break-words text-sm text-metin-body">
                  {e.metin}
                </p>
              ) : (
                <p className="break-words text-sm font-medium text-metin-body">
                  {e.dosya_adi ?? e.dosya_key}
                </p>
              )}
              <p className="mt-0.5 text-xs text-metin-muted">
                {e.olusturan_ad ?? "—"} · {formatDateTime(e.created_at)}
              </p>
            </div>
            <button
              type="button"
              onClick={() => void sil(e.id)}
              // Ad SATIRA OZEL: ekranda alt alta on "Sil" dugmesi varsa,
              // ekran okuyucu kullanicisi hangisinde oldugunu bilemez.
              aria-label={`${t("ekSil")} — ${
                e.tur === "not" ? (e.metin ?? "").slice(0, 40) : (e.dosya_adi ?? "")
              }`}
              className={`${btnDanger} min-h-11 min-w-11 shrink-0`}
            >
              {t("ekSil")}
            </button>
          </li>
        ))}
      </ul>

      {yazabilir && (
        <div className="flex flex-col gap-2">
          <label htmlFor="ek-not" className="sr-only">
            {t("ekNotEkle")}
          </label>
          <textarea
            id="ek-not"
            value={not}
            onChange={(ev) => setNot(ev.target.value)}
            rows={2}
            maxLength={4000}
            placeholder={t("ekNotYer")}
            className={inputCls}
          />
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => void notEkle()}
              disabled={mesgul || !not.trim()}
              className={`${btnPrimary} min-h-11`}
            >
              {t("ekNotEkle")}
            </button>
            <button
              type="button"
              onClick={() => dosyaRef.current?.click()}
              disabled={mesgul}
              className={`${btnGhost} min-h-11`}
            >
              {t("ekDosyaEkle")}
            </button>
            {/* Gorunmez ama ADSIZ DEGIL: tarayicinin kendi dosya
                dugmesi cevrilemez ve tasarima uymaz, o yuzden gorunen
                dugme bunu tetikler. `tabIndex={-1}` sekmeden cikarir;
                yine de bir okuyucu buraya duserse ne oldugunu duymali. */}
            <input
              ref={dosyaRef}
              type="file"
              onChange={(ev) => void dosyaSec(ev)}
              className="hidden"
              aria-label={t("ekDosyaEkle")}
              tabIndex={-1}
            />
          </div>
        </div>
      )}
    </section>
  );
}
