"use client";

// (P126.5) DIŞ HİZMETLER — güvenilir esnaf rehberi.
//
// OKUMA tüm rollere açıktır (sunucu: "güvenilir esnafı herkes görür/
// arayabilir"), YAZMA admin+yönetici. Ekran ikisini de tek sayfada tutar;
// yazma formunu role göre gizlemiyoruz çünkü `app.*`ta bu sayfa yönetici
// menüsündedir — sunucu zaten reddeder ve gizlemek yetkilendirme değildir.
//
// TELEFON P123 MASKESİNDEN GEÇER: rehberdeki numara aranmak içindir;
// gruplanmamış 11 hane okunmaz ve yanlış tuşlanır.
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
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";

type Hizmet = {
  id: string;
  tur: string;
  ad: string;
  soyad: string;
  telefon: string;
  aciklama: string | null;
};
/** Liste yaniti bir de BOLUM NOTU tasir (yoneticinin serbest metni). */
type Liste = { note: string | null; items: Hizmet[] };

export default function DisHizmetlerPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<Liste>(
    "/api/external-services",
    jsonFetcher,
  );

  const [tur, setTur] = useState("");
  const [ad, setAd] = useState("");
  const [soyad, setSoyad] = useState("");
  const [telefon, setTelefon] = useState("");
  const [aciklama, setAciklama] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);

  const kayitlar = data?.items ?? [];

  async function ekle() {
    // SOYAD DA ZORUNLU: sunucu `DisHizmetCreate.soyad` icin min_length=1
    // istiyor. Bos gondermek 422 uretirdi — kural sunucudan OKUNDU.
    if (!tur.trim() || !ad.trim() || !soyad.trim()) {
      setHata(t("disHizmetAlanZorunlu"));
      return;
    }
    const telHata = telefonHatasi(telefon);
    if (telHata) {
      setHata(
        telHata === "gecersizOnEk" ? t("telefonHataOnEk") : t("telefonHataEksik"),
      );
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      await apiSend("/api/external-services", "POST", {
        tur: tur.trim(),
        ad: ad.trim(),
        soyad: soyad.trim(),
        // Sunucuya NORMALLESTIRILMIS gider (P123).
        telefon: telefonNormalle(telefon),
        aciklama: aciklama.trim() || null,
      });
      setTur("");
      setAd("");
      setSoyad("");
      setTelefon("");
      setAciklama("");
      toast.success(t("disHizmetEklendi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("disHizmetBaslik")} />

      {data?.note ? (
        <p className={`${cardCls} p-4 text-sm`}>{data.note}</p>
      ) : null}

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("disHizmetYeni")}</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("disHizmetTur")}>
            <input
              className={inputCls}
              value={tur}
              onChange={(e) => setTur(e.target.value)}
              maxLength={60}
            />
          </Field>
          <Field label={t("disHizmetAd")}>
            <input
              className={inputCls}
              value={ad}
              onChange={(e) => setAd(e.target.value)}
              maxLength={80}
            />
          </Field>
          <Field label={t("disHizmetSoyad")}>
            <input
              className={inputCls}
              value={soyad}
              onChange={(e) => setSoyad(e.target.value)}
              maxLength={80}
            />
          </Field>
          <Field label={t("kullaniciTelefon")}>
            <input
              className={inputCls}
              // (P123) TEK bicimlendirici — bkz. lib/telefon.ts.
              value={telefonGiris(telefon)}
              onChange={(e) => setTelefon(telefonGiris(e.target.value))}
              placeholder={t("kullaniciTelefonOrnek")}
            />
          </Field>
          <Field label={t("disHizmetAciklama")}>
            <input
              className={inputCls}
              value={aciklama}
              onChange={(e) => setAciklama(e.target.value)}
              maxLength={500}
            />
          </Field>
        </div>
        <ErrorBox message={hata} />
        <div>
          <button
            className={btnPrimary}
            disabled={gonderiyor}
            onClick={() => void ekle()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : t("ortakEkle")}
          </button>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="font-medium">{t("disHizmetListe")}</h2>
        {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <EmptyState title={t("disHizmetYok")} />
        ) : null}
        {kayitlar.map((h) => (
          <article key={h.id} className={`${cardCls} space-y-1 p-4`}>
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="font-medium">
                {h.ad} {h.soyad}
              </h3>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs">
                {h.tur}
              </span>
            </div>
            {/* `tel:` baglantisi: rehberdeki numara ARANMAK icindir. */}
            <a className="text-sm underline" href={`tel:${h.telefon}`}>
              {telefonGiris(h.telefon)}
            </a>
            {h.aciklama ? <p className="text-sm">{h.aciklama}</p> : null}
          </article>
        ))}
      </section>
    </div>
  );
}
