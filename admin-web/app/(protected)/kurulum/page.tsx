"use client";

import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";

import {
  Dugme,
  HataDurumu,
} from "@/components/ui";
import { kurulumHatirlaticiyiAc } from "@/components/KurulumHatirlatici";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { useToast } from "@/components/Toast";
import { KURULUM_HEDEFLERI } from "@/lib/kurulum-adimlari";
import { useRol } from "@/lib/rol-kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/**
 * (P154 / Asama 7.3) KURULUM SIHIRBAZI.
 *
 * Brief: "Adim adim kurulum sihirbazi: Blok → Kat/daire → Daire tipleri →
 * Sakinler → Personel → Gorev alanlari → NFC noktalari → Aidat tanimi.
 * Ilerleme gostergesi, atlanabilir adimlar, yarim birakip devam edebilme,
 * tamamlananlarin kalici isaretlenmesi, bitince ayarlardan tekrar
 * acilabilme."
 *
 * SIHIRBAZ KENDI FORMLARINI CIZMEZ — VAR OLAN EKRANLARA YOLLAR. Sekiz
 * adimin sekizinin de calisan bir ekrani zaten var. Sihirbaz icinde
 * ikinci bir "blok ekle" formu yazmak, ayni dogrulamayi iki yerde tutmak
 * ve biri degistiginde otekini unutmak olurdu.
 *
 * ADIMLAR KILITLI DEGIL: sirali cizilir (blok olmadan daire, daire
 * olmadan sakin anlamsizdir) ama hicbiri otekini engellemez. Kilitlemek,
 * brief'in "yarim birakip devam edebilme" sartiyla celisirdi — yarim
 * birakan kullanici geri donunce kaldigi yerden DEGIL, istedigi yerden
 * devam eder.
 *
 * TAMAMLANMA SUNUCUDAN GELIR, BURADA HESAPLANMAZ: "bu adim bitti mi"
 * karari `routers/kurulum.py`de tek yerde durur. Istemcide tekrar etmek,
 * iki farkli yanit uretebilecek ikinci bir kaynak olurdu.
 */

interface Adim {
  kod: string;
  sayi: number;
  tamam: boolean;
  atlandi: boolean;
  /** Ayni dagitim gerekcesiyle OPSIYONEL (bkz. `Durum`). */
  zorunlu?: boolean;
}
interface Durum {
  adimlar: Adim[];
  toplam: number;
  gecilen: number;
  /**
   * (P193 §2) Ozet alanlari OPSIYONEL YAZILDI.
   *
   * Panel ve sunucu AYRI dagitiliyor: yeni panel bir an eski sunucudan
   * yanit alabilir. Alanlari zorunlu saymak, o anda sayfayi tamamen
   * bos birakirdi (olculdu: `undefined.length` ile cizim coktu).
   * Ozet yoksa yalnizca OZET cizilmez; adim listesi calismaya devam eder.
   */
  zorunlu_toplam?: number;
  /** Tamamlanmamis ZORUNLU adim kodlari — ATLAMA burada sayilmaz. */
  eksik_zorunlular?: string[];
  calisir?: boolean;
}

const UC = "/api/panel/kurulum";

export default function KurulumPage() {
  const t = useT();
  const toast = useToast();
  const [hata, setHata] = useState<string | null>(null);
  const { data, error, mutate } = useSWR<Durum>(UC, jsonFetcher);
  // (P166 §8.3) ROL — hangi adimlarin bu kullaniciyla tamamlanabilecegini
  // soyler. `useRol(null)` `/api/me`ye gider ve SWR anahtari kabukla AYNI
  // oldugu icin ek istek uretmez.
  const rol = useRol(null);

  async function atla(kod: string, deger: boolean) {
    setHata(null);
    try {
      await apiSend(UC, "PATCH", { kod, atla: deger });
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  const yuzde = data ? Math.round((data.gecilen / data.toplam) * 100) : 0;
  const bitti = data ? data.gecilen === data.toplam : false;
  // (P193 §2) ZORUNLU SAYACI ilerleme cubugundan AYRI: "10/12" bir tesisin
  // calisip calismadigini soylemez. Eksik olan tek adim kasaysa tesis
  // %83 degil, KULLANILAMAZ durumdadir.
  const eksikZorunlular = data?.eksik_zorunlular ?? [];
  const zorunluToplam = data?.zorunlu_toplam ?? 0;
  const zorunluTamam = zorunluToplam - eksikZorunlular.length;
  const ozetVar = zorunluToplam > 0;
  const calisir = data?.calisir ?? true;

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kurulumBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("kurulumAlt")}
        </p>
      </div>
      <HataDurumu mesaj={hata ?? (error ? t("kurulumHata") : null)} />

      {data && (
        <section className="p-kart" aria-label={t("kurulumIlerleme")}>
          <div className="flex items-center justify-between gap-3">
            <span className="text-sm font-medium text-metin-body">
              {bitti ? t("kurulumTamamlandi") : t("kurulumIlerleme")}
            </span>
            <span className="text-sm tabular-nums text-metin-muted">
              {t("kurulumSayac", { gecilen: data.gecilen, toplam: data.toplam })}
            </span>
          </div>
          {/* ILERLEME CUBUGU ekran okuyucuya da anlatilir: gorsel bir
              dolgunun tek basina hicbir sey soylemedigi tek kullanici
              grubu tam da bu. */}
          <div
            role="progressbar"
            aria-valuenow={yuzde}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={t("kurulumIlerleme")}
            className="mt-2 h-2 w-full overflow-hidden rounded-full bg-yuzey-divider"
          >
            <div
              className="h-full rounded-full bg-primary transition-all"
              style={{ width: `${yuzde}%` }}
            />
          </div>
        </section>
      )}

      {/* (P193 §2) SIHIRBAZ OZETI — "ne eksik ve NEYI ENGELLIYOR".
          Adim listesi "sunu yap" der; ozet "yapmazsan su calismaz" der.
          Rehberi yazarken gorulen kusur buydu: yonetici kasa adimini
          atliyor, sonucunu ilk tahsilatta ogreniyordu. */}
      {ozetVar && (
        <section
          className="p-kart"
          aria-label={calisir ? t("kurulumOzetHazir") : t("kurulumOzetEksik")}
        >
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-medium text-metin-body">
              {calisir ? t("kurulumOzetHazir") : t("kurulumOzetEksik")}
            </p>
            <span className="text-sm tabular-nums text-metin-muted">
              {t("kurulumZorunluSayac", {
                tamam: zorunluTamam,
                toplam: zorunluToplam,
              })}
            </span>
          </div>
          <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {calisir ? t("kurulumOzetHazirAlt") : t("kurulumOzetEksikAlt")}
          </p>
          {eksikZorunlular.length > 0 && (
            <ul className="mt-2 space-y-1">
              {eksikZorunlular.map((kod) => {
                const h = KURULUM_HEDEFLERI[kod];
                if (!h) return null;
                return (
                  <li key={kod} style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                    <Link href={h.rota} className="odak-ic underline">
                      {t(h.etiket)}
                    </Link>{" "}
                    <span style={{ color: "var(--yz-text-2)" }}>{t(h.engel)}</span>
                  </li>
                );
              })}
            </ul>
          )}
          <p className="mt-2" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("kurulumDevamBilgi")}
          </p>
          {/* (P193 §2 / eksik 14) HATIRLATICIYI GERI GETIR — BURADA.
              Dugme bugune kadar YALNIZ `/settings`teydi, yani yalniz
              admin goruyordu: "Daha sonra" diyen bir YONETICI icin
              hatirlatma bir daha CIKMIYORDU. Yeri de burasi: kullanici
              hatirlatmayi ariyorsa sihirbaza bakar, platform ayarlarina
              degil. */}
          <div className="mt-3">
            <Dugme
              type="button"
              boy="kucuk"
              onClick={() => {
                kurulumHatirlaticiyiAc();
                toast.success(t("kurulumTekrarGoster"));
              }}
            >
              {t("kurulumTekrarGoster")}
            </Dugme>
          </div>
        </section>
      )}

      <ol className="space-y-2">
        {(data?.adimlar ?? []).map((a, i) => {
          const h = KURULUM_HEDEFLERI[a.kod];
          if (!h) return null;
          // Rol bilinmiyorken (ilk kare) UYARI CIZILMEZ: bilmedigimiz bir
          // seyi "yapamazsin" diye gostermek, dogru rolde olan kullaniciya
          // bir an yanlis bilgi vermekti.
          const yetkisiz =
            h.rolGerekli !== undefined && rol !== null && !h.rolGerekli.includes(rol);
          return (
            <li key={a.kod} className="p-kart">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="flex items-center gap-2 text-sm font-medium text-metin-body">
                    <span
                      // SAYI DA ROZET DE ANLAM TASIR: yalniz renk kullanmak,
                      // renk ayirt edemeyen kullanici icin bilgiyi silerdi.
                      className={`inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs ${
                        a.tamam
                          ? "bg-accent-green/15 text-vurguInk-green"
                          : a.atlandi
                            ? "bg-yuzey-divider text-metin-muted"
                            : "bg-accent-blue/12 text-accent-blue"
                      }`}
                    >
                      {i + 1}
                    </span>
                    {t(h.etiket)}
                    <span className="text-xs font-normal text-metin-muted">
                      {a.tamam
                        ? t("kurulumAdimTamam", { sayi: a.sayi })
                        : a.atlandi
                          ? t("kurulumAdimAtlandi")
                          : t("kurulumAdimBekliyor")}
                    </span>
                  </p>
                  <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t(h.aciklama)}</p>
                  {/* (P193 §2) ZORUNLU/ISTEGE BAGLI ROZETI ve — bitmemis
                      adimda — NEYI ENGELLEDIGI. Biten adimda engel metni
                      cizilmez: olmayan bir sorunu anlatmak gurultudur. */}
                  {/* Sunucu zorunluluk bilgisi vermiyorsa (eski surum)
                      ROZET DE CIZILMEZ: "istege bagli" demek, zorunlu bir
                      adimi yanlis etiketlemek olurdu. */}
                  <p className="mt-1" hidden={!ozetVar} style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                    <span
                      className="me-2 inline-flex items-center rounded-full px-2 py-0.5"
                      style={{
                        background: "var(--yz-metal-1)",
                        border: "var(--yz-border-w) solid var(--yz-border)",
                      }}
                    >
                      {a.zorunlu ? t("kurulumZorunlu") : t("kurulumIstegeBagli")}
                    </span>
                    {a.tamam ? null : t(h.engel)}
                  </p>
                </div>
                <div className="flex shrink-0 flex-wrap gap-2">
                  {/* (P166 §8.3) YETKISIZ ADIMDA ONCE ACIKLAMA: kullanici
                      "Git"e basip 403 gormeden ONCE nedenini okur. */}
                  {yetkisiz && (
                    <p
                      role="note"
                      className="max-w-xs"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                    >
                      {t("kurulumAdimYetkiGerekli")}
                    </p>
                  )}
                  {/* BAGLANTI, DUGME DEGIL: adim bir SAYFAYA gider ve orta
                      tikla yeni sekmede acilabilmeli. */}
                  <Link
                    href={h.rota}
                    className="odak-ic yz-lift inline-flex items-center px-3 py-2"
                    style={{
                      borderRadius: "var(--yz-radius-btn)",
                      border: "var(--yz-border-w) solid var(--yz-border)",
                      fontSize: "var(--yz-fs-sm)",
                      color: a.tamam ? "var(--yz-text)" : "var(--yz-on-fill)",
                      background: a.tamam ? "var(--yz-metal-1)" : "var(--yz-metal-accent)",
                    }}
                  >
                    {a.tamam || yetkisiz ? t("kurulumGoruntule") : t("kurulumGit")}
                  </Link>
                  {/* ATLAMA yalniz BITMEMIS adimda anlamli; biten bir adimi
                      atlamak kullaniciya hicbir sey kazandirmaz. */}
                  {!a.tamam && (
                    <Dugme
                      type="button"
                      boy="kucuk"
                      onClick={() => void atla(a.kod, !a.atlandi)}
                    >
                      {a.atlandi ? t("kurulumAtlamayiGeriAl") : t("kurulumAtla")}
                    </Dugme>
                  )}
                </div>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
