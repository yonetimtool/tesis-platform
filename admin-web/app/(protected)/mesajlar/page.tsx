"use client";

import { useMemo, useRef, useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Alan,
  CokSatir,
  Kart,
  VeriTablosu,
  type Kolon,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  Secim,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { GonderimKarti } from "@/components/mesajlar/gonderim-karti";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { BagimlilikUyarisi } from "@/components/BagimlilikUyarisi";
import { useT } from "@/lib/i18n/kullan";
import { useSorguSecimi } from "@/lib/sorgu-secimi";
import { Sekmeler } from "@/components/ui";
import { EtiketCipleri } from "@/components/mesaj/etiket-cipleri";
import {
  HazirSablonPenceresi,
  MesajDurumKarti,
  duzMetniHtmlYap,
  yerTutuculari,
  type HazirSablon,
} from "@/components/mesaj/hazir-sablonlar";
import { ZenginMetin } from "@/components/ZenginMetin";
import { smsOlc } from "@/lib/sms-olcu";
import { SINIR } from "@/lib/girdi-siniri";

/** Sablon kanallari — veritabanindaki `mesaj_kanal` enum'uyla AYNI.
 *
 * WHATSAPP BURADA YOK ve bu bilincli: enum bugun yalnizca `sms, eposta`
 * tasiyor. Secenegi eklemek, kaydedilemeyen bir sablon formu acmak
 * olurdu. WhatsApp Asama 9'un kalan isidir (enum + sablon onay alanlari,
 * bkz. docs/whatsapp-arastirma.md).
 */
type Kanal = "sms" | "eposta";
const KANALLAR: readonly Kanal[] = ["sms", "eposta"];

/** (P168 §4) Sekmeler. (P250 §8) "Ayarlar" sekmesi PLATFORM paneline
 *  tasindi (`/mesaj-ayarlari`, tesis secilerek); burada yalniz kanal
 *  DURUMU kalir (`MesajDurumKarti`). */
type SekmeId = "gonderim" | "sms" | "eposta";
const SEKMELER: readonly SekmeId[] = ["gonderim", "sms", "eposta"];

/**
 * P40 — MESAJ bolumu (P32 API'si).
 *
 * SMS SAYACI EKRANDA: Turkce harf tuzagi (kucuk i-noktasiz, g-yumusak ve
 * s-cedilla GSM-7'de YOKTUR) mesaji UCS-2'ye dusurur ve 160 karakterlik
 * sinir 70'e iner — "biraz uzun" bir
 * mesaj birden UC SMS olur. Sayaci gizlemek, kullanicinin faturayi
 * gonderdikten SONRA gormesi demekti; bu yuzden onizleme ucu cagrilir ve
 * parca sayisi ile ZORLAYAN karakterler gosterilir.
 *
 * RIZA GONDERIMDE ZORLANIR (P36): pazarlama sablonu yalniz O KANALA izin
 * vermis kisilere gider; atlananlar SESSIZCE DUSURULMEZ, sayilir.
 */

interface Sablon {
  id: string;
  kanal: string;
  ad: string;
  konu: string | null;
  govde: string;
  amac: string;
  aktif: boolean;
}

export default function MesajlarPage() {
  const t = useT();
  const toast = useToast();

  const {
    data: sablonlar,
    error: sErr,
    mutate: sablonTazele,
  } = useSWR<{ items: Sablon[] }>("/api/panel/mesaj-sablonlari?limit=100", jsonFetcher);
  // (P251 §10) GONDERIM GECMISI BURADAN KALKTI: satirlar saglayicinin ham
  // hatasini (535, 5.7.8...) tasiyordu ve yoneticiye ait degildi; teknik
  // gunluk platform panelinde ("Gonderim gunlugu"). Yonetici gonderim
  // sonucunu bu ekranda SAYILARLA (gonderildi / riza yok / adres yok /
  // basarisiz) ve odeme kodu satirlarinda sade durumla gorur.

  // --- yeni sablon ---
  // (P154 / Asama 7.1) Menudeki "SMS gonderimi / WhatsApp / E-posta
  // gonderimi" satirlari uc ayri sayfa DEGIL, bu secimin on ayarlari.
  const [kanal, setKanal] = useSorguSecimi<Kanal>("kanal", KANALLAR, "sms");
  /** SMS govdesinin DOM dugumu — etiket cipleri imlec konumunu buradan alir. */
  const govdeRef = useRef<HTMLTextAreaElement | null>(null);
  /** Zengin metin editorunun "imlece ekle" kancasi. */
  const zenginEkleRef = useRef<((metin: string) => void) | null>(null);
  const [ad, setAd] = useState("");
  const [konu, setKonu] = useState("");
  const [govde, setGovde] = useState("");
  const [amac, setAmac] = useState("operasyonel");
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  /** (P250 §8) Hazir sablon secicisi hangi kanal icin acik. */
  const [hazirKanal, setHazirKanal] = useState<Kanal | null>(null);


  /** (P250 §8) Hazir sablon -> yeni sablon formu (duzenlenip kaydedilir). */
  function hazirSablonuKullan(s: HazirSablon): void {
    setKanal(s.kanal);
    setAd(s.ad);
    setKonu(s.konu ?? "");
    setGovde(s.kanal === "eposta" ? duzMetniHtmlYap(s.govde) : s.govde);
    setAmac("operasyonel");
    setHata(null);
    setHazirKanal(null);
    setModalAcik(true);
  }

  // (P250 §8) Doldurulmamis `[TARİH]` gibi yer tutucular KAYDI ENGELLER:
  // sakine "[SAAT]'te toplanti" giden bir mesaj geri alinamaz.
  const eksikYerler = yerTutuculari(`${kanal === "eposta" ? konu : ""} ${govde}`);

  async function sablonEkle(): Promise<void> {
    setHata(null);
    if (!ad.trim() || !govde.trim()) {
      setHata(t("mesajAdGovdeGerekli"));
      return;
    }
    if (eksikYerler.length > 0) {
      setHata(t("mesajYerTutucuUyari", { liste: eksikYerler.join(" ") }));
      return;
    }
    setMesgul(true);
    try {
      await apiSend("/api/panel/mesaj-sablonlari", "POST", {
        kanal,
        ad,
        konu: kanal === "eposta" ? konu || null : null,
        govde,
        amac,
      });
      setAd("");
      setGovde("");
      setKonu("");
      toast.success(t("mesajSablonEklendi"));
      await sablonTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  async function sablonSil(id: string): Promise<void> {
    try {
      await apiSend(`/api/panel/mesaj-sablonlari/${id}`, "DELETE");
      toast.success(t("mesajSablonSilindi"));
      await sablonTazele();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  const sablonKolonlari: Kolon<Sablon>[] = useMemo(
    () => [
      {
        id: "kanal", kartRolu: "ozet",
        baslik: t("mesajKanal"),
        gizlenebilir: false,
        hucre: (s) => t(`mesajKanal_${s.kanal}` as never),
      },
      { id: "ad", kartRolu: "baslik", baslik: t("mesajAd"), hucre: (s) => s.ad },
      {
        id: "amac", kartRolu: "ozet",
        baslik: t("mesajAmac"),
        // AMAC SABLONDA (P32): ayni sablonun bir gun pazarlama bir gun
        // operasyonel gonderilmesi riza denetimini anlamsiz kilardi — bu
        // yuzden gonderimde secilemez.
        hucre: (s) => t(`mesajAmac_${s.amac}` as never),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (s) => (
          <div className="flex justify-end">
            <Dugme tur="tehlike" boy="kucuk" onClick={() => void sablonSil(s.id)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  // (P168 §4) SEKMELI YAPI. Brief dort sekme istiyor; onceki hâl tek bir
  // uzun sayfaydi ve "SMS sablonlari" ile "e-posta sablonlari" AYNI
  // tabloda karisik duruyordu — iki farkli isin ayni listede olmasi,
  // kullaniciyi her seferinde kanal sutununu okumaya zorluyordu.
  //
  // SEKME ADRESTE TUTULUR: yenilemede ya da paylasilan bir baglantida
  // ayni sekme acilsin; yerel durumda tutmak, "sana gonderdigim linkte
  // baska sey goruyorum" sinifini acardi.
  const [sekme, setSekme] = useSorguSecimi<SekmeId>("sekme", SEKMELER, "gonderim");

  const sablonListesi = (kanal: Kanal) => (
    <section className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {kanal === "sms" ? t("mesajSekmeSms") : t("mesajSekmeEposta")}
        </h2>
        <div className="flex flex-wrap gap-2">
          <Dugme boy="kucuk" data-test={`hazir-ac-${kanal}`} onClick={() => setHazirKanal(kanal)}>
            {t("mesajHazirSablonlar")}
          </Dugme>
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              setHata(null);
              setKanal(kanal);
              setModalAcik(true);
            }}
          >
            {t("mesajYeniSablon")}
          </Dugme>
        </div>
      </div>
      <VeriTablosu<Sablon>
        kolonlar={sablonKolonlari}
        satirlar={(sablonlar?.items ?? []).filter((x) => x.kanal === kanal)}
        satirId={(x) => x.id}
        hata={sErr ? t("mesajSablonHata") : null}
        onTekrar={() => void sablonTazele()}
        yukleniyor={!sablonlar && !sErr}
        bosBaslik={t("mesajSablonYok")}
        bosAciklama={t("mesajSablonYokAlt")}
      />
    </section>
  );

  // (P168 §4.1) Canli SMS olcumu — her tusa basista sunucuya sormak
  // saniyede on istek atmak olurdu.
  const olcum = smsOlc(govde);

  /** (P168 §4.3 · P253 §B) GONDERIM sekmesi — onizle, kime, ONAY, gonder. */
  const gonderimIcerigi = (
    <div className="space-y-4">
      <GonderimKarti sablonlar={(sablonlar?.items ?? []).filter((x) => x.aktif)} />
    </div>
  );

  return (
    <div className="space-y-6">
      <div>
        <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("mesajBaslik")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={() => {
          // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden acildiginda
          // onceki denemenin mesaji ekranda duruyordu ve kullanici hic
          // denemeden hata gormus oluyordu.
          setHata(null);
          setModalAcik(true);
        }}>
          {t("mesajYeniSablon")}
        </Dugme>
      </div>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("mesajAlt")}</p>
      </div>
      {/* (P154 / Asama 7.4) Sablon yoksa gonderim YAPILAMAZ
          (`POST /mesajlar/gonder`, envanter §0.4). */}
      <BagimlilikUyarisi
        kod="mesajSablonu"
        eksik={(sablonlar?.items.length ?? 1) === 0}
      />
      <HataDurumu mesaj={hata ?? (sErr ? t("mesajSablonHata") : null)} />
      <MesajDurumKarti />

      <Sekmeler
        aktifId={sekme}
        onDegis={(id) => setSekme(id as SekmeId)}
        sekmeler={[
          { id: "gonderim", baslik: t("mesajSekmeGonderim"), icerik: gonderimIcerigi },
          { id: "sms", baslik: t("mesajSekmeSms"), icerik: sablonListesi("sms") },
          {
            id: "eposta",
            baslik: t("mesajSekmeEposta"),
            icerik: sablonListesi("eposta"),
          },
        ]}
      />

      {hazirKanal ? (
        <HazirSablonPenceresi
          kanal={hazirKanal}
          onSec={hazirSablonuKullan}
          onKapat={() => setHazirKanal(null)}
        />
      ) : null}

      {/* MODAL SEKMELERIN DISINDA: hangi sekmeden acilirsa acilsin ayni
          modal kullanilir ve sekme degisince kapanmamali. */}
      {/* ---------------------------- yeni sablon -------------------------- */}
      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("mesajYeniSablon")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={mesgul}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={mesgul} onClick={sablonEkle}>
          {t("mesajSablonKaydet")}
        </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <AlanSarmal etiket={t("mesajKanal")}>
  {(b) => (
    <Secim {...b} value={kanal} onChange={(e) => setKanal(e.target.value as Kanal)}>
              <option value="sms">{t("mesajKanal_sms")}</option>
              <option value="eposta">{t("mesajKanal_eposta")}</option></Secim>
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("mesajAd")}>
  {(b) => (
    <Alan maxLength={SINIR.AD} {...b} value={ad} onChange={(e) => setAd(e.target.value)} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("mesajAmac")}>
  {(b) => (
    <Secim {...b} value={amac} onChange={(e) => setAmac(e.target.value)}>
              <option value="operasyonel">{t("mesajAmac_operasyonel")}</option>
              <option value="pazarlama">{t("mesajAmac_pazarlama")}</option></Secim>
  )}
</AlanSarmal>
          {kanal === "eposta" ? (
            <AlanSarmal etiket={t("mesajKonu")}>
  {(b) => (
    <Alan maxLength={SINIR.BASLIK} {...b} value={konu} onChange={(e) => setKonu(e.target.value)} />
  )}
</AlanSarmal>
          ) : null}
        </div>
        {/* (P168 §4.1/§4.2) ETIKET CIPLERI — yazim hatasi ihtimalini
            sifira indirir. Onceki hâl tek satirlik bir IPUCUYDU ve
            kullanicinin etiketi dogru yazmasini bekliyordu; tek harf
            hatasi (`{bakiyee}`) mesajda oldugu gibi gorunuyordu. */}
        <div className="space-y-1">
          <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("mesajEtiketler")}
          </span>
          <EtiketCipleri
            onEkle={(metin) => {
              if (kanal === "eposta") {
                zenginEkleRef.current?.(metin);
                return;
              }
              // SMS: imlecin oldugu yere ekle. Sona eklemek, cumlenin
              // ortasina etiket koymak isteyen kullaniciyi metni elle
              // tasimaya zorlardi.
              const el = govdeRef.current;
              if (!el) {
                setGovde((g) => g + metin);
                return;
              }
              const bas = el.selectionStart ?? govde.length;
              const son = el.selectionEnd ?? bas;
              setGovde(govde.slice(0, bas) + metin + govde.slice(son));
              // Imleci eklenen metnin SONUNA tasi — yoksa bir sonraki
              // cip ayni yere yazar ve etiketler ic ice girerdi.
              queueMicrotask(() => {
                el.focus();
                el.setSelectionRange(bas + metin.length, bas + metin.length);
              });
            }}
          />
        </div>

        {eksikYerler.length > 0 ? (
          <p role="status" data-test="yer-tutucu-uyari" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
            {t("mesajYerTutucuUyari", { liste: eksikYerler.join(" ") })}
          </p>
        ) : null}

        {kanal === "eposta" ? (
          // (P168 §4.2) E-POSTA GOVDESI ZENGIN METIN. SMS'te bicimlendirme
          // ANLAMSIZDIR (duz metin gider) ve editor koymak, kullaniciya
          // hicbir sey yapmayan dugmeler gostermek olurdu.
          <AlanSarmal etiket={t("mesajGovde")}>
            {() => (
              <ZenginMetin
                deger={govde}
                onDegisti={setGovde}
                etiket={t("mesajGovde")}
                ekleRef={zenginEkleRef}
                azami={4000 /* sunucu: MesajSablonuCreate.govde */}
              />
            )}
          </AlanSarmal>
        ) : (
          <>
            <AlanSarmal etiket={t("mesajGovde")}>
              {(b) => (
                <CokSatir maxLength={4000 /* sunucu: MesajSablonuCreate.govde */}
                  {...b}
                  ref={govdeRef}
                  rows={4}
                  value={govde}
                  onChange={(e) => setGovde(e.target.value)}
                />
              )}
            </AlanSarmal>
            {/* (P168 §4.1) CANLI SAYAC — yazarken. Kaydettikten sonra
                gorulen sayi sunucunundur (onizleme ucu); bu, yazarken
                gosterilen tahmindir. */}
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {t("mesajKalanKarakter")}:{" "}
              <b className="tabular-nums">{olcum.kalan}</b> ·{" "}
              <b className="tabular-nums">{t("mesajSmsAdet", { n: olcum.parca })}</b>
              {olcum.unicodeMi ? (
                <>
                  {" · "}
                  <span style={{ color: "var(--yz-danger-ink)" }}>
                    {t("mesajUnicodeUyari")} {olcum.zorlayan.join(" ")}
                  </span>
                </>
              ) : null}
            </p>
          </>
        )}
        </div>
      </Modal>

    </div>
  );
}