"use client";

// (P168 §4.4) MESAJ AYARLARI SEKMESI — saglayici, SMTP, kota, test.
//
// =========================================================================
// SIRLAR: ALAN BOS BASLAR, "kayitli" BILGISI AYRI SATIRDA
// =========================================================================
// Sunucu parolayi HIC DONDURMUYOR (bkz. `MesajYapilandirmaOut`), yalnizca
// `*_var` bayragi donuyor. Sebep: `****` gibi maskeli bir deger de bir
// DEGERDIR — forma girer ve "kaydet"te gercek parolanin uzerine yazilirdi.
//
// Bu yuzden alan BOS cizilir ve altinda "kayitli bir parola var" yazar.
// Bos birakilirsa sunucu mevcudu KORUR.

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Kart, Rozet, Secim } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

interface Ayarlar {
  sms_saglayici: string | null;
  sms_kullanici: string | null;
  sms_baslik: string | null;
  sms_parola_var: boolean;
  smtp_host: string | null;
  smtp_port: number;
  smtp_kullanici: string | null;
  smtp_parola_var: boolean;
  smtp_gonderen: string | null;
  gunluk_kota: number | null;
  bugun_gonderilen: number;
  sms_hazir: boolean;
  eposta_hazir: boolean;
  sms_kaynak: "tesis" | "genel" | "yok";
  eposta_kaynak: "tesis" | "genel" | "yok";
}

const BOS = "";
const UC = "/api/panel/mesaj-ayarlari";
const KANAL_SMS = "sms";
const KANAL_EPOSTA = "eposta";
const SAGLAYICI_NETGSM = "netgsm";
// SAGLAYICI ADI CEVRILMEZ ve sozluge girmez: "Netgsm" bir SIRKET
// ADIDIR. Sozluge koymak, yedi dilde ayni markayi tekrar etmek ve bir
// gun birini yanlislikla cevirmek riskini almaktir.
const SAGLAYICI_NETGSM_ADI = "Netgsm";
const DURUM_GONDERILDI = "gonderildi";
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`): bunlar rozet
// kimlikleri, kullanici metni DEGIL.
const ROZET_OLUMLU = "olumlu" as const;
const ROZET_UYARI = "uyari" as const;

/** Rozet metni: hazir mi + HANGI ayardan. */
function durumMetni(
  t: (a: SozlukAnahtari) => string,
  hazir: boolean | undefined,
  kaynak: "tesis" | "genel" | "yok" | undefined,
): string {
  if (!hazir) return t("mesajYapilandirilmadi");
  // "genel" DENDIGINDE alanlarin bos olmasi ARTIK TUTARLI gorunur.
  return kaynak === "genel"
    ? `${t("mesajHazir")} (${t("mesajKaynakGenel")})`
    : t("mesajHazir");
}

export function MesajAyarlariSekmesi() {
  const t = useT();
  const toast = useToast();
  const { data, error, mutate } = useSWR<Ayarlar>(UC, jsonFetcher);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);
  const [testHedef, setTestHedef] = useState(BOS);
  const [testKanal, setTestKanal] = useState(KANAL_SMS);
  const [testSonuc, setTestSonuc] = useState<string | null>(null);

  // Form durumu SUNUCUDAN gelen degerlerle baslar ama PAROLALAR BOS:
  // sunucu onlari zaten gondermiyor.
  const [form, setForm] = useState<Record<string, string>>({});
  function deger(ad: keyof Ayarlar): string {
    if (ad in form) return form[ad as string];
    const v = data?.[ad];
    return v === null || v === undefined ? BOS : String(v);
  }
  function yaz(ad: string, v: string) {
    setForm((o) => ({ ...o, [ad]: v }));
  }

  async function kaydet() {
    setHata(null);
    setMesgul(true);
    try {
      // YALNIZ DOKUNULAN ALANLAR GONDERILIR: tumunu gondermek, bos
      // birakilan parola alanini "temizle" komutuna cevirirdi.
      const govde: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(form)) {
        govde[k] = k === "smtp_port" || k === "gunluk_kota" ? (v ? Number(v) : null) : v;
      }
      if (Object.keys(govde).length === 0) return;
      await apiSend(UC, "PUT", govde);
      setForm({});
      toast.success(t("ortakKaydedildi"));
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  async function test() {
    setHata(null);
    setTestSonuc(null);
    try {
      const r = await apiSend<{ durum: string; hata: string | null }>(
        `${UC}/test`,
        "POST",
        { kanal: testKanal, hedef: testHedef },
      );
      // SONUC OLDUGU GIBI GOSTERILIR: "gonderildi" olmayan bir sonucu
      // basari gibi gostermek, bu turun duzelttigi kusurun ta kendisi.
      setTestSonuc(r.durum);
      if (r.durum !== DURUM_GONDERILDI) setHata(r.hata ?? r.durum);
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  return (
    <div className="space-y-4">
      {/* (P173 §5) SUNUCUNUN METNI ONCE. `mesajAyarHata` genel bir
          cumledir ("ayarlar okunamadi") ve 404/405 gibi govdesiz
          yanitlarda kullaniciya HICBIR ipucu birakmiyordu. `jsonFetcher`
          artik bu durumlar icin ne yapilacagini soyleyen bir metin
          uretiyor; genel cumle yalnizca YEDEK. */}
      <HataDurumu
        mesaj={hata ?? (error ? (error as Error).message || t("mesajAyarHata") : null)}
      />

      {/* HAZIRLIK DURUMU EN USTTE: kullanici "neden gitmiyor" sorusunu
          gonderdikten SONRA degil, buraya girdigi anda gormeli. */}
      <Kart className="flex flex-wrap items-center gap-3">
        {/* (P173 §4) ROZET KAYNAGI DA SOYLER.
            "Hazir" tek basina yaniltiyordu: alanlar BOS gorunurken rozet
            hazir diyor, kullanici "ben bir sey girmedim, nasil hazir?"
            diye sorup ayarlari yeniden girmeye kalkiyordu. Sebep dogru
            ama gorunmuyordu — kanal genel (ENV) ayardan calisiyor. */}
        <Rozet durum={data?.sms_hazir ? ROZET_OLUMLU : ROZET_UYARI}>
          {t("mesajSmsDurum")}: {durumMetni(t, data?.sms_hazir, data?.sms_kaynak)}
        </Rozet>
        <Rozet durum={data?.eposta_hazir ? ROZET_OLUMLU : ROZET_UYARI}>
          {t("mesajEpostaDurum")}:{" "}
          {durumMetni(t, data?.eposta_hazir, data?.eposta_kaynak)}
        </Rozet>
        <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("mesajBugunGonderilen")}: {data?.bugun_gonderilen ?? 0}
          {data?.gunluk_kota ? ` / ${data.gunluk_kota}` : BOS}
        </span>
      </Kart>

      <Kart className="space-y-3">
        <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("mesajSmsAyarlari")}
        </h3>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("mesajSaglayici")}>
            {(b) => (
              <Secim
                {...b}
                value={deger("sms_saglayici")}
                onChange={(e) => yaz("sms_saglayici", e.target.value)}
              >
                <option value={BOS}>{t("mesajSaglayiciYok")}</option>
                <option value={SAGLAYICI_NETGSM}>{SAGLAYICI_NETGSM_ADI}</option>
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesajKullanici")}>
            {(b) => (
              <Alan
                {...b}
                value={deger("sms_kullanici")}
                onChange={(e) => yaz("sms_kullanici", e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal
            etiket={t("mesajParola")}
            ipucu={data?.sms_parola_var ? t("mesajParolaKayitli") : undefined}
          >
            {(b) => (
              <Alan
                {...b}
                type="password"
                autoComplete="new-password"
                value={form.sms_parola ?? BOS}
                onChange={(e) => yaz("sms_parola", e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesajBaslikAlan")}>
            {(b) => (
              <Alan
                {...b}
                value={deger("sms_baslik")}
                onChange={(e) => yaz("sms_baslik", e.target.value)}
              />
            )}
          </AlanSarmal>
        </div>
      </Kart>

      <Kart className="space-y-3">
        <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("mesajSmtpAyarlari")}
        </h3>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("mesajSmtpHost")}>
            {(b) => (
              <Alan {...b} value={deger("smtp_host")} onChange={(e) => yaz("smtp_host", e.target.value)} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesajSmtpPort")}>
            {(b) => (
              <Alan
                {...b}
                type="number"
                value={deger("smtp_port")}
                onChange={(e) => yaz("smtp_port", e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesajKullanici")}>
            {(b) => (
              <Alan
                {...b}
                value={deger("smtp_kullanici")}
                onChange={(e) => yaz("smtp_kullanici", e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal
            etiket={t("mesajParola")}
            ipucu={data?.smtp_parola_var ? t("mesajParolaKayitli") : undefined}
          >
            {(b) => (
              <Alan
                {...b}
                type="password"
                autoComplete="new-password"
                value={form.smtp_parola ?? BOS}
                onChange={(e) => yaz("smtp_parola", e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesajGonderen")}>
            {(b) => (
              <Alan
                {...b}
                value={deger("smtp_gonderen")}
                onChange={(e) => yaz("smtp_gonderen", e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesajGunlukKota")} ipucu={t("mesajKotaIpucu")}>
            {(b) => (
              <Alan
                {...b}
                type="number"
                value={deger("gunluk_kota")}
                onChange={(e) => yaz("gunluk_kota", e.target.value)}
              />
            )}
          </AlanSarmal>
        </div>
        <Dugme tur="birincil" disabled={mesgul} onClick={() => void kaydet()}>
          {t("ortakKaydet")}
        </Dugme>
      </Kart>

      <Kart className="space-y-3">
        <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("mesajTestGonderimi")}
        </h3>
        <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
          {t("mesajTestAciklama")}
        </p>
        <div className="grid gap-3 sm:grid-cols-3">
          <AlanSarmal etiket={t("mesajKanal")}>
            {(b) => (
              <Secim {...b} value={testKanal} onChange={(e) => setTestKanal(e.target.value)}>
                <option value={KANAL_SMS}>{t("mesajKanal_sms")}</option>
                <option value={KANAL_EPOSTA}>{t("mesajKanal_eposta")}</option>
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("mesajTestHedef")}>
            {(b) => (
              <Alan {...b} value={testHedef} onChange={(e) => setTestHedef(e.target.value)} />
            )}
          </AlanSarmal>
          <div className="flex items-end">
            <Dugme disabled={!testHedef} onClick={() => void test()}>
              {t("mesajTestGonder")}
            </Dugme>
          </div>
        </div>
        {testSonuc ? (
          <Rozet durum={testSonuc === DURUM_GONDERILDI ? ROZET_OLUMLU : ROZET_UYARI}>
            {testSonuc}
          </Rozet>
        ) : null}
      </Kart>
    </div>
  );
}
