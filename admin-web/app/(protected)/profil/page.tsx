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
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  IskeletMetin,
} from "@/components/ui";
import { GirisYontemlerim } from "@/components/GirisYontemlerim";
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
    // `?? false` SART: onay kutusu DENETIMLIDIR ve `undefined` gormesi
    // React'te denetimliden denetimsize gecis demek (kullanicinin
    // isaretini sessizce kaybettiren sinif). Sozlesme bugun alani her
    // zaman gonderiyor; kutu yine de kendi basina saglam durmali.
    setAranabilir(data.aranabilir ?? false);
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
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("profilBaslik")}
      </h1>

      {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}

      <section className="space-y-4">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("profilKimlik")}</h2>
        {isLoading ? (
          <IskeletMetin satir={3} />
        ) : (
          <dl className="grid gap-3 sm:grid-cols-2">
            <div>
              <dt style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("profilAd")}</dt>
              <dd>{data?.ad ?? "—"}</dd>
            </div>
            <div>
              <dt style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("profilEposta")}</dt>
              <dd>{data?.email ?? "—"}</dd>
            </div>
          </dl>
        )}
      </section>

      <section className="space-y-4">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("profilIletisim")}</h2>
        <div className="grid gap-4 sm:max-w-md">
          <AlanSarmal etiket={t("kullaniciTelefon")} ipucu={t("profilTelefonIpucu")}>
  {(b) => (
    <Alan {...b} // `telefonGiris` CIZIMDE de uygulanir (fikirsizdir/idempotent):
              // garantiyi "her setter dogru cagirmis olmali"ya dayandirmak
              // kirilgandi — ileride durumu bicimlendirmeden yazan bir
              // duzenleme yine maskeli cizer. P123 kapsam kilidi bu yuzden
              // `value={}` icinde ariyor ve HAKLI.
              value={telefonGiris(telefon)}
              // (P123) TEK biçimlendirici — bkz. lib/telefon.ts.
              onChange={(e) => setTelefon(telefonGiris(e.target.value))}
              placeholder={t("kullaniciTelefonOrnek")} />
  )}
</AlanSarmal>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={aranabilir}
              onChange={(e) => setAranabilir(e.target.checked)}
            />
            {t("profilAranabilir")}
          </label>
          <HataDurumu mesaj={iletisimHata} />
          <div>
            <Dugme
              tur="birincil"
              disabled={kaydediyor}
              onClick={() => void iletisimKaydet()}
            >
              {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </div>
        </div>
      </section>

      {/* (P154 / Asama 4) Sosyal giris yontemleri — ekleme/kaldirma. */}
      <GirisYontemlerim />
    </div>
  );
}
