"use client";

import { useEffect, useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Secim,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { GIRDI_TIPI, OPERASYON } from "@/lib/tesis-ayar-alanlari";
import type { TenantSettings } from "@/lib/types";

/**
 * (P193 §5) TESIS AYARLARI — YONETICININ EKRANI.
 *
 * =========================================================================
 * NEDEN VAR
 * =========================================================================
 * Yonetici kurulum rehberi yazilirken bulundu (eksik 2 ve 3): saat dilimi,
 * hava durumu konumu, otopark kapasitesi, gurultu esigi, tur alarmi —
 * bunlarin bir KISMINI sunucu yoneticiye ACIYOR (`_YONETICI_YAZABILIR`)
 * ama panelde EKRAN YOKTU. Tek ayarlar ekrani `/settings`ti ve o
 * PLATFORM yuzeyinde (`panel.*`), yani yalniz Yonetiyor ekibi goruyordu.
 * Tesis adi bile web'den degistirilemiyordu — yalniz mobilden.
 *
 * =========================================================================
 * ALAN TABLOSU KOPYALANMADI
 * =========================================================================
 * Alanlar `lib/tesis-ayar-alanlari.ts`te, `/settings` ile ORTAK. Ikinci
 * bir liste tutmak, yeni bir ayar eklendiginde ekranlardan birinin
 * sessizce eksik kalmasi demekti.
 *
 * =========================================================================
 * NE GOSTERILMEZ ve NEDEN
 * =========================================================================
 * `adminOnly` alanlar (bugun: guvenlik modu) ve saat dilimi/tesis kodu
 * burada YOK:
 *   * GUVENLIK MODU sahipligi devreder (P35). Yoneticinin kendi yetkisini
 *     kendine geri verebilmesi, dis sirkete devri anlamsizlastirirdi.
 *   * SAAT DILIMI ve TESIS KODU (slug) kimlik/altyapi degerleridir;
 *     degismeleri oturumu ve gecmis kayitlarin yorumunu etkiler.
 * Ikisi de sunucuda da kapali; buradaki gizleme yalnizca kullaniciya 403
 * aldirmamak icin.
 */

/** Tesis kimlik/adres alanlari — yoneticinin yazabildikleri. */
const ADRES_ALANLARI = [
  { anahtar: "adres", etiket: "tesisAyarAdres" },
  { anahtar: "ilce", etiket: "tesisAyarIlce" },
  { anahtar: "il", etiket: "tesisAyarIl" },
  { anahtar: "posta_kodu", etiket: "tesisAyarPostaKodu" },
] as const;

const UC = "/api/tenant/settings";

export default function TesisAyarlariPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<TenantSettings>(UC, jsonFetcher);

  const [form, setForm] = useState<Record<string, unknown>>({});
  const [yuklendi, setYuklendi] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [bilgi, setBilgi] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  // YONETICININ YAZABILDIKLERI: sunucudaki kume ile ayni olcut.
  const ayarlar = OPERASYON.filter((a) => !a.adminOnly);

  useEffect(() => {
    if (!data || yuklendi) return;
    const kaynak = data as unknown as Record<string, unknown>;
    const baslangic: Record<string, unknown> = { ad: data.ad };
    for (const a of ADRES_ALANLARI) baslangic[a.anahtar] = kaynak[a.anahtar] ?? "";
    for (const a of ayarlar) baslangic[a.anahtar] = kaynak[a.anahtar];
    setForm(baslangic);
    setYuklendi(true);
  }, [data, yuklendi, ayarlar]);

  async function kaydet() {
    setHata(null);
    setBilgi(null);
    setKaydediyor(true);
    try {
      // YALNIZ DEGISENLER GIDER: degismeyen bir alani gondermek, sunucuda
      // gereksiz bir yazma ve (bir gun kisitlanirsa) beklenmedik bir 403
      // uretirdi.
      const govde: Record<string, unknown> = {};
      const kaynak = (data ?? {}) as unknown as Record<string, unknown>;
      // BOS = BOS: sunucu bos bir metni `null` doner, form onu `""`
      // tutar. Ikisini farkli saymak, kullanici HICBIR SEYE dokunmadan
      // "Kaydet"e bastiginda bos alanlari yeniden yazan bir istek
      // uretirdi (olculdu: `gurultu_uyari_metni: null` sizdi).
      const bos = (v: unknown) => v === null || v === undefined || v === "";
      for (const anahtar of Object.keys(form)) {
        const yeni = form[anahtar];
        const eski = kaynak[anahtar];
        if (yeni === eski) continue;
        if (bos(yeni) && bos(eski)) continue;
        // BOS DIZGE `null` OLUR: "temizledim" ile "dokunmadim" ayri
        // seylerdir ve sunucu ikincisini `exclude_unset` ile anlar.
        govde[anahtar] = yeni === "" ? null : yeni;
      }
      if (Object.keys(govde).length === 0) {
        setBilgi(t("ayarDegisiklikYok"));
        return;
      }
      await apiSend(UC, "PATCH", govde);
      setBilgi(t("ayarKaydedildi"));
      toast.success(t("ayarKaydedildi"));
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ayarKaydedilemedi"));
    } finally {
      setKaydediyor(false);
    }
  }

  function yaz(anahtar: string, deger: unknown) {
    setForm((o) => ({ ...o, [anahtar]: deger }));
  }

  return (
    <div className="max-w-2xl space-y-5">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("tesisAyarBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("tesisAyarAlt")}
        </p>
      </div>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={4} />}

      {data && (
        <>
          <Kart className="space-y-4">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("tesisAyarKimlik")}
            </h2>
            <AlanSarmal etiket={t("ayarTesisAdi")}>
              {(b) => (
                <Alan
                  {...b}
                  value={String(form.ad ?? "")}
                  onChange={(e) => yaz("ad", e.target.value)}
                />
              )}
            </AlanSarmal>
            {/* (P193 §4) ADRES — makbuzda ve rapor basliginda yazilir.
                Ipucu bunu SOYLER: nereye cikacagini bilmeden doldurulan
                bir alan, bos birakilan bir alandir. */}
            {ADRES_ALANLARI.map((a) => (
              <AlanSarmal
                key={a.anahtar}
                etiket={t(a.etiket)}
                ipucu={a.anahtar === "adres" ? t("tesisAyarAdresIpucu") : undefined}
              >
                {(b) => (
                  <Alan
                    {...b}
                    value={String(form[a.anahtar] ?? "")}
                    onChange={(e) => yaz(a.anahtar, e.target.value)}
                  />
                )}
              </AlanSarmal>
            ))}
          </Kart>

          <Kart className="space-y-4">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("ayarOperasyon")}
            </h2>
            {ayarlar.map((a) => (
              <AlanSarmal
                key={a.anahtar}
                etiket={t(a.etiket)}
                ipucu={
                  // (P213 §1) ESIK 1 UYARISI — REDDETMEK DEGIL, SOYLEMEK.
                  //
                  // Esik 1'de HER sikayette daireye anons gider ve uyari
                  // hizla anlamsizlasir. Ama bu KULLANILAMAZ degil,
                  // TERCIH edilebilir bir uc deger (kucuk bir sitede
                  // bilincli olarak secilebilir). Uc 422 dondurseydi,
                  // mesru bir kullanimi imkansiz kilardik; bu yuzden
                  // sunucu KABUL EDER, arayuz UYARIR.
                  a.anahtar === "gurultu_esigi" && Number(form[a.anahtar]) === 1
                    ? t("ayarGurultuEsikBirUyari")
                    : a.ipucu
                      ? t(a.ipucu)
                      : undefined
                }
              >
                {() => {
                  if (a.tip === "bool") {
                    return (
                      <input
                        type="checkbox"
                        className="h-4 w-4"
                        aria-label={t(a.etiket)}
                        checked={Boolean(form[a.anahtar])}
                        onChange={(e) => yaz(a.anahtar, e.target.checked)}
                      />
                    );
                  }
                  if (a.tip === "secim") {
                    return (
                      <Secim
                        aria-label={t(a.etiket)}
                        value={String(form[a.anahtar] ?? "")}
                        onChange={(e) => yaz(a.anahtar, e.target.value)}
                      >
                        {(a.secenekler ?? []).map((s) => (
                          <option key={s.deger} value={s.deger}>
                            {t(s.etiket)}
                          </option>
                        ))}
                      </Secim>
                    );
                  }
                  return (
                    <Alan
                      aria-label={t(a.etiket)}
                      type={GIRDI_TIPI[a.tip]}
                      min={a.min}
                      max={a.max}
                      value={String(form[a.anahtar] ?? "")}
                      onChange={(e) => {
                        if (a.tip !== "sayi") {
                          yaz(a.anahtar, e.target.value);
                          return;
                        }
                        yaz(
                          a.anahtar,
                          e.target.value === "" ? "" : Number(e.target.value),
                        );
                      }}
                    />
                  );
                }}
              </AlanSarmal>
            ))}
          </Kart>

          <HataDurumu mesaj={hata} />
          {bilgi && (
            <p role="status" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-success-ink)" }}>
              {bilgi}
            </p>
          )}
          {/* PLATFORMA AIT OLAN NE, ACIKCA YAZILI: kullanici aradigi bir
              ayari bulamayinca "ekran bozuk" degil "burada degil" bilgisi
              almali. */}
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("tesisAyarPlatformNotu")}
          </p>
          <Dugme tur="birincil" disabled={kaydediyor} onClick={() => void kaydet()}>
            {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </>
      )}
    </div>
  );
}
