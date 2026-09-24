"use client";

import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";

import {
  Dugme,
  HataDurumu,
  SayfaBasligi,
  DugmeBaglantisi,
} from "@/components/ui";
import { ilkGirisTurunuAc } from "@/components/IlkGirisTuru";
import { kurulumHatirlaticiyiAc } from "@/components/KurulumHatirlatici";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { useToast } from "@/components/Toast";
import { KURULUM_HEDEFLERI } from "@/lib/kurulum-adimlari";
import { useRol } from "@/lib/rol-kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const BOY_KUCUK = "kucuk" as const;
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;

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
  /** (P243 §6a) Adim ASGARI calisir kurulumun parcasi mi. */
  asgari?: boolean;
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
  /** (P243 §6a) Asgari kurulumun adim sayisi ve eksikleri. */
  asgari_toplam?: number;
  asgari_eksikler?: string[];
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

  // (P243 §6a/§6f) ASGARI CALISIR KURULUM — ILERLEME BASKI YAPMAZ.
  //
  // OLCULEN KUSUR: 19 adimin 7'si "zorunlu"ydu ve aralarinda kasa,
  // gelir-gider tanimi, aidat vardi. Yeni bir yonetici sihirbazi
  // acinca "%16 tamam" goruyor ve DUYURU YAPMAK icin once muhasebe
  // kurmasi gerektigini saniyordu. Yuzde, yapilmamis her seyi bir
  // borc gibi gosteriyordu.
  //
  // YENI SUNUM: once "baslamak icin su ikisi" (blok + daire), sonra
  // "sunlari da yapabilirsiniz". Ikincisinde sayac YOK ve her satir
  // NE ACTIGINI yazar; yapilmamis olmak bir eksiklik degil, ACILMAMIS
  // BIR YETENEKTIR.
  const asgariToplam = data?.asgari_toplam ?? 0;
  const asgariEksikler = data?.asgari_eksikler ?? [];
  // Eski sunucu bu alanlari GONDERMEZ: o durumda asgari bolumu hic
  // cizilmez (panel ve sunucu ayri dagitiliyor — P193 §2 dersi).
  const asgariVar = asgariToplam > 0;
  const asgariTamam = asgariToplam - asgariEksikler.length;
  // Eski sunucu ozet alanlarini hic gondermez; o durumda OZET KARTI
  // cizilmez (adim listesi calismaya devam eder).
  const ozetVar = (data?.zorunlu_toplam ?? 0) > 0;
  const calisir = data?.calisir ?? true;
  // (P243 §6b) SONRA YAPILABILECEKLER — asgari OLMAYAN, bitmemis ve
  // atlanmamis adimlar. Atlanan ayri bolumde durur (P199): atlamak
  // bilincli bir karardir, tekrar listeye yazmak sitem olurdu.
  const sonraYapilacaklar = (data?.adimlar ?? []).filter(
    (a) => !a.tamam && !a.atlandi && !a.asgari,
  );
  // (P199) SONRAYA BIRAKILANLAR — ozetin ikinci yarisi.
  //
  // Zorunlu eksikler "tesis calismiyor" der. Atlanan ISTEGE BAGLI
  // adimlar bundan farklidir: tesis calisir, ama yonetici NEYI
  // KAYBETTIGINI bilmeden calisir. Bugune kadar atlanan adim listeden
  // sessizce dusuyordu; sihirbazin sonunda hicbir izi kalmiyordu.
  //
  // ZORUNLU olan atlansa bile buraya GIRMEZ: o zaten yukaridaki
  // "eksikler" listesinde ve atlanmis olmasi gercegi degistirmiyor
  // (P193 §2 karari).
  const atlananlar = (data?.adimlar ?? []).filter(
    (a) => a.atlandi && !a.tamam && !a.zorunlu,
  );

  return (
    <div>
      <SayfaBasligi baslik={t("kurulumBaslik")} aciklama={t("kurulumAltAdimlar")} />
      <HataDurumu mesaj={hata ?? (error ? t("kurulumHata") : null)} />

      {/* (P243 §6a) BASLAMAK ICIN GEREKENLER — sihirbazin ILK sozu.
          Yuzde gostergesi buradan KALKTI: "%16 tamam" yapilmamis her
          seyi borc gibi gosteriyor ve yeni yoneticiye muhasebe kurmadan
          duyuru yapamayacagini sandiriyordu. */}
      {data && asgariVar && !calisir && (
        <section className="p-kart" data-test="kurulum-asgari" aria-label={t("kurulumAsgariBaslik")}>
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-medium" style={{ color: "var(--yz-text)" }}>{t("kurulumAsgariBaslik")}</p>
            <span className="text-sm tabular-nums" style={{ color: "var(--yz-text-2)" }}>
              {t("kurulumAsgariSayac", { tamam: asgariTamam, toplam: asgariToplam })}
            </span>
          </div>
          <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("kurulumAsgariAlt")}
          </p>
          <ul className="mt-2 space-y-1">
            {asgariEksikler.map((kod) => {
              const h = KURULUM_HEDEFLERI[kod];
              if (!h) return null;
              return (
                <li key={kod} style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                  <Link href={h.rota} className="odak-ic underline">
                    {t(h.etiket)}
                  </Link>{" "}
                  <span style={{ color: "var(--yz-text-2)" }}>{t(h.aciklama)}</span>
                </li>
              );
            })}
          </ul>
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
            <p className="text-sm font-medium" style={{ color: "var(--yz-text)" }}>
              {calisir ? t("kurulumOzetHazir") : t("kurulumOzetEksik")}
            </p>

          </div>
          <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {calisir ? t("kurulumOzetHazirAlt") : t("kurulumOzetEksikAlt")}
          </p>
          {/* (P243 §6b) SONRA YAPILABILECEKLER — "eksikler" DEGIL.
              Baslik ve metin bilincli olarak sitem etmiyor: her satir
              bir YETENEGI acar ve neyi actigini yazar. Yapmamak bir
              hata degil, bir tercihtir. */}
          {sonraYapilacaklar.length > 0 && (
            <div className="mt-3 border-t pt-3" style={{ borderColor: "var(--yz-border)" }} data-test="kurulum-sonra">
              <p className="text-sm font-medium" style={{ color: "var(--yz-text)" }}>{t("kurulumSonraBaslik")}</p>
              <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("kurulumSonraAlt")}
              </p>
              <ul className="mt-2 space-y-1">
                {sonraYapilacaklar.map((a) => {
                  const h = KURULUM_HEDEFLERI[a.kod];
                  if (!h) return null;
                  return (
                    <li key={a.kod} style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                      <Link href={h.rota} className="odak-ic underline">
                        {t(h.etiket)}
                      </Link>{" "}
                      <span style={{ color: "var(--yz-text-2)" }}>{t(h.engel)}</span>
                    </li>
                  );
                })}
              </ul>
            </div>
          )}
          {atlananlar.length > 0 && (
            <div className="mt-3 border-t pt-3" style={{ borderColor: "var(--yz-border)" }} data-test="kurulum-atlananlar">
              <p className="text-sm font-medium" style={{ color: "var(--yz-text)" }}>
                {t("kurulumAtlanan")}
              </p>
              <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("kurulumAtlananAlt")}
              </p>
              <ul className="mt-2 space-y-1">
                {atlananlar.map((a) => {
                  const h = KURULUM_HEDEFLERI[a.kod];
                  if (!h) return null;
                  return (
                    <li key={a.kod} style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                      <Link href={h.rota} className="odak-ic underline">
                        {t(h.etiket)}
                      </Link>{" "}
                      <span style={{ color: "var(--yz-text-2)" }}>{t(h.engel)}</span>
                    </li>
                  );
                })}
              </ul>
            </div>
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
          <div className="mt-3 flex flex-wrap gap-2">
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
            {/* (P243 §6d) TANITIM TURU BURADAN DA ACILIR: "bir kez
                gosterilir" ile "bir daha asla ulasilamaz" ayni sey
                degil. Yeri hatirlatici dugmesinin yani, cunku ikisi de
                "bana bastan anlat" istegine cevap veriyor. */}
            <Dugme type="button" boy="kucuk" onClick={ilkGirisTurunuAc}>
              {t("turTekrarAc")}
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
                  <p
                    className="flex items-center gap-2 text-sm font-medium"
                    style={{ color: "var(--yz-text)" }}
                  >
                    <span
                      // SAYI DA ROZET DE ANLAM TASIR: yalniz renk kullanmak,
                      // renk ayirt edemeyen kullanici icin bilgiyi silerdi.
                      className="inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs"
                      style={
                        a.tamam
                          ? { background: "var(--yz-surface-sunken)", color: "var(--yz-success-ink)" }
                          : a.atlandi
                            ? { background: "var(--yz-surface-sunken)", color: "var(--yz-text-2)" }
                            : { background: "var(--yz-surface-sunken)", color: "var(--yz-accent-ink)" }
                      }
                    >
                      {i + 1}
                    </span>
                    {t(h.etiket)}
                    <span className="text-xs font-normal" style={{ color: "var(--yz-text-2)" }}>
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
                  <DugmeBaglantisi
                    href={h.rota}
                    // BITMEMIS adim BIRINCIL, biten IKINCIL: sihirbazda
                    // goz siradaki isi arar, yapilani degil.
                    tur={a.tamam ? TUR_IKINCIL : TUR_BIRINCIL}
                    boy={BOY_KUCUK}
                  >
                    {a.tamam || yetkisiz ? t("kurulumGoruntule") : t("kurulumGit")}
                  </DugmeBaglantisi>
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
