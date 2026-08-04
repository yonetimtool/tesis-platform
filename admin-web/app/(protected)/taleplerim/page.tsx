"use client";

// (P126.3) TALEPLERİM — sakinin KENDİ talepleri + yeni talep.
//
// Paneldeki `/complaints` YÖNETİM ekranıdır: bütün talepleri listeler,
// atama/durum değiştirir. Bu, talebi YAŞAYAN tarafın ekranı.
//
// AYNI UÇ, FARKLI GÖVDE (P42 sınıfı): `/complaints` sunucuda zaten
// kendi-kapsamlıdır — açan roller (`security`, `tesis_gorevlisi`,
// `resident`) YALNIZ kendi açtıklarını görür. Bu yüzden yeni bir uç
// açılmadı; istemci süzgeci de KOYULMADI (istemci süzgeci bir gün
// unutulur, sunucu kuralı unutulmaz).
//
// Yönetici bu sayfayı GÖRMEZ: onun ekranı `/complaints`tir ve talebi
// yönetir; kanal tek yönlüdür (sakin/saha → yönetim).
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import {
  ErrorBox,
  Field,
  PageHeader,
  btnPrimary,
  cardCls,
  inputCls,
} from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihSaatUzun } from "@/lib/tarih";

// METIN DEGIL KIMLIK (modul duzeyi — tur 18 dersi). Esleme paneldeki
// `complaints` sayfasiyla AYNI; ham `durum` degerini ("acik") ekrana
// yazmak, kullaniciya veritabani sabiti gostermek olurdu.
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  acik: "ortakAcik",
  is_emri: "talepIsEmri",
  cozuldu: "destekCozuldu",
  reddedildi: "talepReddedildi",
};

/**
 * Bilinmeyen durum icin geri dusus — CIZIM ICINDE degil, MODUL duzeyinde.
 *
 * `t(HARITA[x] ?? "anahtar")` yazmak, sabit-metin taramasini hakli olarak
 * tetikliyor: bir uclunun icindeki satir-ici dizge, gorunen metinle ayni
 * sozdiziminde durur ve tarayici ikisini ayirt edemez. Paneldeki
 * `isEmriAnahtari` ile ayni desen.
 */
function durumAnahtari(durum: string): SozlukAnahtari {
  const anahtar = DURUM_ANAHTARI[durum];
  if (anahtar) return anahtar;
  // `??` ile tek satirda yazmak sabit-metin taramasini tetikliyor: tarayici
  // bunu bir uclu sayiyor ve uclu icindeki dizge gorunen metinle ayni
  // sozdiziminde durur. Paneldeki `isEmriAnahtari` de bu yuzden `switch`.
  return "talepDurumBilinmiyor";
}

type Talep = {
  id: string;
  baslik: string;
  mesaj: string;
  durum: string;
  kategori_ad: string | null;
  created_at: string;
};

const LIMIT = 20;

export default function TaleplerimPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Talep[] }>(
    `/api/complaints?limit=${LIMIT}&offset=0`,
    jsonFetcher,
  );

  const [baslik, setBaslik] = useState("");
  const [mesaj, setMesaj] = useState("");
  const [formHata, setFormHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);

  const talepler = data?.items ?? [];

  async function gonder() {
    if (!baslik.trim() || !mesaj.trim()) {
      setFormHata(t("talebimAlanZorunlu"));
      return;
    }
    setFormHata(null);
    setGonderiyor(true);
    try {
      await apiSend("/api/complaints", "POST", {
        baslik: baslik.trim(),
        mesaj: mesaj.trim(),
      });
      setBaslik("");
      setMesaj("");
      toast.success(t("talebimGonderildi"));
      void mutate();
    } catch (e) {
      // SUNUCU metni aynen gosterilir (tur 14: istegin dilinde gelir).
      setFormHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("talebimBaslik")} />

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("talebimYeni")}</h2>
        <div className="grid gap-4">
          <Field label={t("talebimKonu")}>
            <input
              className={inputCls}
              value={baslik}
              onChange={(e) => setBaslik(e.target.value)}
              maxLength={200}
            />
          </Field>
          <Field label={t("talebimAciklama")}>
            <textarea
              className={`${inputCls} min-h-24`}
              value={mesaj}
              onChange={(e) => setMesaj(e.target.value)}
              maxLength={5000}
            />
          </Field>
          <ErrorBox message={formHata} />
          <div>
            <button
              className={btnPrimary}
              disabled={gonderiyor}
              onClick={() => void gonder()}
            >
              {gonderiyor ? t("ortakKaydediliyor") : t("talebimGonder")}
            </button>
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="font-medium">{t("talebimGecmis")}</h2>
        {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
        ) : null}
        {!isLoading && !error && talepler.length === 0 ? (
          <EmptyState title={t("talebimYok")} />
        ) : null}
        {talepler.map((c) => (
          <article key={c.id} className={`${cardCls} space-y-1 p-4`}>
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="font-medium">{c.baslik}</h3>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs">
                {t(durumAnahtari(c.durum))}
              </span>
            </div>
            <p className="text-xs text-metin-muted">{tarihSaatUzun(c.created_at)}</p>
            <p className="text-sm">{c.mesaj}</p>
          </article>
        ))}
      </section>
    </div>
  );
}
