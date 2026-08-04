"use client";

// (P126.3) PROFİL — her tesis rolünün kendi kaydı.
//
// `app.*`ın ilk KENDİNE AİT sayfası: bugüne kadar paneldeki 25 sayfa
// yönetimin BAŞKALARINI yönettiği ekranlardı; bu, kullanıcının kendi
// kaydına dokunduğu ilk yer. Sakin/güvenlik/görevli çalışma alanının
// (P126.3–.6) temel taşı — hepsi bu sayfaya ihtiyaç duyar.
//
// SUNUCU UÇLARI: `GET /me/profile`, `PATCH /me/contact`, `PATCH /me/password`.
// Yönetim uçları (`PATCH /users/{id}/contact`) AYRI kalır — bu onların
// kendi-kaydı karşılığıdır.
import { useEffect, useState } from "react";
import useSWR from "swr";

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

type Profil = {
  id: string;
  ad: string;
  email: string | null;
  telefon: string | null;
  aranabilir: boolean;
  role: string;
};

export default function ProfilPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<Profil>(
    "/api/me",
    jsonFetcher,
  );

  const [telefon, setTelefon] = useState("");
  const [aranabilir, setAranabilir] = useState(false);
  const [iletisimHata, setIletisimHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  // Sunucudan gelen değer forma BİR KEZ yüklenir; kullanıcı yazarken
  // SWR yeniden doğrulaması yazdığını EZMESİN.
  useEffect(() => {
    if (!data) return;
    setTelefon(telefonGiris(data.telefon ?? ""));
    setAranabilir(data.aranabilir);
  }, [data?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  async function iletisimKaydet() {
    // Telefon İSTEĞE BAĞLI: boş bırakmak numarayı kaldırır.
    const hata = telefonHatasi(telefon, false);
    if (hata) {
      setIletisimHata(
        hata === "gecersizOnEk" ? t("telefonHataOnEk") : t("telefonHataEksik"),
      );
      return;
    }
    setIletisimHata(null);
    setKaydediyor(true);
    try {
      // `apiSend` HATA FIRLATIR (sonuc nesnesi dondurmez) — depo konvansiyonu.
      await apiSend("/api/me/contact", "PATCH", {
        // Sunucuya NORMALLEŞTİRİLMİŞ gider (P123); boşsa açık null → kaldır.
        telefon: telefonNormalle(telefon) || null,
        aranabilir,
      });
      toast.success(t("profilKaydedildi"));
      void mutate();
    } catch (e) {
      // SUNUCU metni aynen gosterilir (tur 14: istegin dilinde gelir).
      setIletisimHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("profilBaslik")} />

      {error ? <ErrorBox message={t("ortakHataOlustu")} /> : null}

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("profilKimlik")}</h2>
        {isLoading ? (
          <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
        ) : (
          <dl className="grid gap-3 sm:grid-cols-2">
            <div>
              <dt className="text-xs text-metin-muted">{t("profilAd")}</dt>
              <dd>{data?.ad ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-xs text-metin-muted">{t("profilEposta")}</dt>
              <dd>{data?.email ?? "—"}</dd>
            </div>
          </dl>
        )}
      </section>

      <section className={`${cardCls} space-y-4 p-5`}>
        <h2 className="font-medium">{t("profilIletisim")}</h2>
        <div className="grid gap-4 sm:max-w-md">
          <Field label={t("kullaniciTelefon")} hint={t("profilTelefonIpucu")}>
            <input
              className={inputCls}
              // `telefonGiris` CIZIMDE de uygulanir (fikirsizdir/idempotent):
              // garantiyi "her setter dogru cagirmis olmali"ya dayandirmak
              // kirilgandi — ileride durumu bicimlendirmeden yazan bir
              // duzenleme yine maskeli cizer. P123 kapsam kilidi bu yuzden
              // `value={}` icinde ariyor ve HAKLI.
              value={telefonGiris(telefon)}
              // (P123) TEK biçimlendirici — bkz. lib/telefon.ts.
              onChange={(e) => setTelefon(telefonGiris(e.target.value))}
              placeholder={t("kullaniciTelefonOrnek")}
            />
          </Field>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={aranabilir}
              onChange={(e) => setAranabilir(e.target.checked)}
            />
            {t("profilAranabilir")}
          </label>
          <ErrorBox message={iletisimHata} />
          <div>
            <button
              className={btnPrimary}
              disabled={kaydediyor}
              onClick={() => void iletisimKaydet()}
            >
              {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}
