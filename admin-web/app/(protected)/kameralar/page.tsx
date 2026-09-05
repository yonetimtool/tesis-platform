"use client";

// (P126.5 · P131) KAMERALAR — canlı kare ızgarası + OYNATICI + yönetim.
//
// IZGARADA OYNATICI YOK, P121'deki gerekçenin aynısı: N video oynatıcıyı
// aynı anda çalıştırmak pil/bant genişliği açısından pahalıdır. Karo
// `snapshot_url`den durağan kare çeker ve yalnız sekme GÖRÜNÜRKEN
// tazelenir (`document.visibilityState`). Oynatma, karoya tıklayınca
// AÇILAN tek bir oynatıcıda olur — aynı anda en fazla bir yayın.
//
// (P131) OYNATMA ARTIK VAR: `hls.js` bağımlılık kararı verildi. Safari
// HLS'i yerelden oynatır ve orada kütüphane HİÇ yüklenmez; diğerlerinde
// oynat'a basınca dinamik import edilir (bkz. KameraOynatici).
//
// OYNATILAMAZ KAYNAK GİZLENMEZ, ROZETLENİR: `rtsp` (restream'siz) bir
// kamera tarayıcıda açılamaz. Karoyu tıklanabilir bırakıp siyah ekran
// vermek "bozuk" izlenimi üretirdi; rozet + bilgi kutusu NEDENİNİ söyler.
// Web sayfası adresi (YouTube vb.) VERİLMEZ — o kayıt zaten reddedilir
// (lib/kamera-url.ts).
//
// (P131) YÖNETİM AÇILDI: kural artık ortak vaka dosyasıyla kilitli
// (`contracts/kamera-url-kurali.json`), yani mobil ile ayrışması ölçülüyor.
import { useEffect, useMemo, useState } from "react";
import useSWR from "swr";


import { KameraOynatici } from "@/components/KameraOynatici";
import { kareKaynagi } from "@/components/KameraSeridi";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Modal,
  Rozet,
  Secim,
  useOnay,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import {
  adrestenTur,
  anlikKareHatasi,
  oynatilabilirMi,
  restreamHatasi,
  yayinUrlHatasi,
  type KameraUrlHatasi,
} from "@/lib/kamera-url";
import type { CameraTur, Kamera, KameraListResponse } from "@/lib/types";

// Kare tazeleme aralığı — mobildeki `kareAraligi` ile aynı (8 sn).
const KARE_ARALIGI_MS = 8000;

const TURLER: CameraTur[] = ["hls", "mp4", "rtsp"];
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`): tur kimligi cumle degil.
const TUR_RTSP = "rtsp" as const;
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const ROZET_UYARI = "uyari" as const;
// Tur adlari TEKNIK KIMLIKTIR (HLS/MP4/RTSP) — cevrilmez, sozluge girmez.
const TUR_SECENEKLERI = TURLER.map((tr) => (
  <option key={tr} value={tr}>
    {tr.toUpperCase()}
  </option>
));

type Form = {
  ad: string;
  konum: string;
  stream_url: string;
  tur: CameraTur;
  restream_url: string;
  snapshot_url: string;
  sakin_gorebilir: boolean;
  /** (P213 §4) Ana ekranda (Ozet) karesi gosterilsin mi. */
  ana_ekranda: boolean;
  aktif: boolean;
};

const BOS_FORM: Form = {
  ad: "",
  konum: "",
  stream_url: "",
  tur: "hls",
  restream_url: "",
  snapshot_url: "",
  sakin_gorebilir: false,
  ana_ekranda: false,
  aktif: true,
};

export default function KameralarPage() {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<KameraListResponse>(
    "/api/cameras?limit=50&offset=0",
    jsonFetcher,
  );
  const kameralar = data?.items ?? [];
  const gorunen = kameralar.filter((k) => k.aktif);
  // (P190 §6) Karo kaynagi: yoneticinin girdigi snapshot_url varsa o; yoksa
  // RTSP kameralarda SUNUCUNUN cektigi kare (`/api/cameras/{id}/kare`) —
  // kimlik bilgili RTSP adresi istemciye inmeden izgara dolar.
  // (P213 §3) TUR AYRIMI KALKTI: sunucu artik HLS kameradan da kare
  // cekiyor. Ortak yardimci `KameraSeridi`den geliyor — iki ekranin
  // ayni kurali iki kez yazmasi, birini degistirince otekini unutmakti.
  // NOT: `ana_ekranda` bayragi BURAYI ETKILEMEZ; bu sayfa YONETIM
  // ekranidir ve TUM kameralari gosterir.
  const kareCekilebilir = gorunen.some((k) => !!kareKaynagi(k));
  // Kare cekilemeyen (baglanti yok) kameralar — karo acik durum cizer,
  // bos kutu birakmaz. Her tazeleme turunda yeniden denenir.
  const [kareHatalari, setKareHatalari] = useState<Set<string>>(new Set());

  // NESİL SAYACI: adrese eklenerek önbelleği kırar. Zaman damgası yerine
  // sayaç — testte deterministik olsun diye (mobildeki gerekçenin aynısı).
  const [nesil, setNesil] = useState(0);
  const [oynatilan, setOynatilan] = useState<Kamera | null>(null);
  const [bilgi, setBilgi] = useState<Kamera | null>(null);

  useEffect(() => {
    if (!kareCekilebilir) return;
    let zamanlayici: ReturnType<typeof setInterval> | null = null;

    function baslat() {
      if (zamanlayici) return;
      zamanlayici = setInterval(() => {
        setKareHatalari(new Set());
        setNesil((n) => n + 1);
      }, KARE_ARALIGI_MS);
    }
    function durdur() {
      if (!zamanlayici) return;
      clearInterval(zamanlayici);
      zamanlayici = null;
    }
    function gorunurlukDegisti() {
      // SEKME ARKA PLANDAYKEN İSTEK ATILMAZ. Bu olmadan açık bırakılmış bir
      // sekme, kimse bakmıyorken dakikada onlarca istek atardı.
      if (document.visibilityState === "visible") {
        setNesil((n) => n + 1);
        baslat();
      } else {
        durdur();
      }
    }

    if (document.visibilityState === "visible") baslat();
    document.addEventListener("visibilitychange", gorunurlukDegisti);
    return () => {
      durdur();
      document.removeEventListener("visibilitychange", gorunurlukDegisti);
    };
  }, [kareCekilebilir]);

  // ------------------------------ yönetim ---------------------------------- #
  const [acik, setAcik] = useState(false);
  const [duzenlenen, setDuzenlenen] = useState<string | null>(null);
  const [form, setForm] = useState<Form>(BOS_FORM);
  const [formHata, setFormHata] = useState<string | null>(null);
  const [kaydediliyor, setKaydediliyor] = useState(false);
  // (P191 §3) BAGLANTI TESTI — kaydetmeden once adresin CALISTIGINI gormek.
  // Olculen kusur: yonetici kaydediyor, izgarada "Goruntu yok" goruyor ve
  // adresin mi agin mi parolanin mi yanlis oldugunu bilmiyordu.
  const [testEdiliyor, setTestEdiliyor] = useState(false);
  // (P191-ek §3) Gelismis ayarlar VARSAYILAN KAPALI; duzenlemede dolu bir
  // alan varsa acilir (asagida `duzenle`).
  const [gelismis, setGelismis] = useState(false);

  // Hata KİMLİĞİ -> aktif dildeki cümle (metin değil kimlik taşınır).
  const hataMetni = useMemo(
    () => (h: KameraUrlHatasi | null): string | null => {
      if (!h) return null;
      switch (h) {
        case "bos":
          return t("kameraUrlBos");
        case "cokUzun":
          return t("kameraUrlCokUzun");
        case "webSayfasi":
          return t("kameraUrlWebSayfasi");
        case "rtspSemasiGerekli":
          return t("kameraUrlRtspSemasi");
        default:
          return t("kameraUrlHttpSemasi");
      }
    },
    [t],
  );

  /**
   * (P191-ek §3) ADRES YAZILDIKCA TUR TURETILIR.
   *
   * Yonetici "yayin turu"nu artik secmiyor: bilgi zaten adresin icinde.
   * Turetilemeyen (yarim yazilmis) adreste MEVCUT tur korunur — her tus
   * vurusunda turu sifirlamak, kullanicinin yazdigi seyi altindan cekmek
   * olurdu. Gelismis ayarlardan elle degistirilebilir.
   */
  function adresYaz(deger: string) {
    const tur = adrestenTur(deger);
    setForm((onceki) => ({
      ...onceki,
      stream_url: deger,
      tur: tur ?? onceki.tur,
    }));
  }

  function yeni() {
    setDuzenlenen(null);
    setForm(BOS_FORM);
    setFormHata(null);
    setGelismis(false);
    setAcik(true);
  }

  function duzenle(k: Kamera) {
    setDuzenlenen(k.id);
    setForm({
      ad: k.ad,
      konum: k.konum ?? "",
      stream_url: k.stream_url,
      tur: k.tur,
      restream_url: k.restream_url ?? "",
      snapshot_url: k.snapshot_url ?? "",
      sakin_gorebilir: k.sakin_gorebilir,
      ana_ekranda: k.ana_ekranda ?? false,
      aktif: k.aktif,
    });
    setFormHata(null);
    setAcik(true);
  }

  /** RTSP adresini SUNUCUYA denettir; sonucu (tanili) formda goster. */
  async function baglantiyiTestEt() {
    if (form.tur !== TUR_RTSP) {
      setFormHata(t("kameraTestRtspGerekli"));
      return;
    }
    const hata = yayinUrlHatasi(form.stream_url, form.tur);
    if (hata) {
      setFormHata(hataMetni(hata));
      return;
    }
    setFormHata(null);
    setTestEdiliyor(true);
    try {
      const d = (await apiSend("/api/cameras/test-baglanti", "POST", {
        stream_url: form.stream_url.trim(),
        tur: form.tur,
      })) as { kare_bayt?: number };
      toast.success(t("kameraTestBasarili", { bayt: String(d.kare_bayt ?? 0) }));
    } catch (err) {
      // Sunucu TANILI mesaj doner ("parola kabul edilmedi", "ffmpeg yok",
      // "yol bulunamadi"...). Genel bir cumleye indirgemek, teshisin butun
      // degerini yok ederdi.
      setFormHata(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setTestEdiliyor(false);
    }
  }

  async function kaydet(e: React.FormEvent) {
    e.preventDefault();
    // DOĞRULAMA İSTEK ÖNCESİ: sunucu da reddeder (422) ama web sayfası
    // adresini SUNUCU GEÇİRİR — onu yalnız istemci yakalayabilir.
    const hatalar = [
      yayinUrlHatasi(form.stream_url, form.tur),
      restreamHatasi(form.restream_url),
      anlikKareHatasi(form.snapshot_url),
    ].filter(Boolean) as KameraUrlHatasi[];
    if (hatalar.length > 0) {
      setFormHata(hataMetni(hatalar[0]));
      return;
    }
    setFormHata(null);
    setKaydediliyor(true);
    try {
      const govde: Record<string, unknown> = {
        ad: form.ad,
        konum: form.konum || null,
        stream_url: form.stream_url.trim(),
        tur: form.tur,
        restream_url: form.restream_url.trim() || null,
        snapshot_url: form.snapshot_url.trim() || null,
        sakin_gorebilir: form.sakin_gorebilir,
        ana_ekranda: form.ana_ekranda,
        aktif: form.aktif,
      };
      if (duzenlenen) await apiSend(`/api/cameras/${duzenlenen}`, "PATCH", govde);
      else await apiSend("/api/cameras", "POST", govde);
      setAcik(false);
      mutate();
      toast.success(duzenlenen ? t("kameraGuncellendi") : t("kameraOlusturuldu"));
    } catch (err) {
      setFormHata(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setKaydediliyor(false);
    }
  }

  async function sil(k: Kamera) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("kameraSilOnay", { ad: k.ad }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/cameras/${k.id}`, "DELETE");
      mutate();
      toast.success(t("kameraSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kameraBaslikWeb")}
        </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={yeni}>
          {t("kameraYeni")}
        </Dugme>
      </div>

      {/* HATA VARSA IZGARA DALI CALISMAZ: `gorunen` bos gelir ve "kamera
          yok" yazmak, kamera OLMADIGINI soylemek olurdu — oysa bilinen
          tek sey listenin okunamadigi. */}
      {error ? (
        <HataDurumu mesaj={t("ortakHataOlustu")} onTekrar={() => void mutate()} />
      ) : isLoading ? (
        <Kart>
          <IskeletMetin satir={3} />
        </Kart>
      ) : gorunen.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("kameraYokWeb")} />
        </Kart>
      ) : null}

      {oynatilan && (
        <Kart>
          <div className="mb-2 flex items-center justify-between gap-3">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {oynatilan.ad}
            </h2>
            <Dugme boy="kucuk" onClick={() => setOynatilan(null)}>
              {t("ortakKapat")}
            </Dugme>
          </div>
          <KameraOynatici
            // RESTREAM VARSA O OYNATILIR (P17): `stream_url` kameranin KENDI
            // adresidir ve rtsp olabilir; gecit HLS yayinlar.
            // (P190 §6) YONETILEN canli yol oncelikli: BFF vekili (kimlik
            // cerezle) -> backend -> MediaMTX; RTSP adresi istemciye inmez.
            url={
              oynatilan.canli_yol
                ? `/api${oynatilan.canli_yol}`
                : oynatilan.restream_url || oynatilan.stream_url
            }
            mp4={
              oynatilan.tur === "mp4" &&
              !oynatilan.restream_url &&
              !oynatilan.canli_yol
            }
            poster={oynatilan.snapshot_url}
          />
        </Kart>
      )}

      {bilgi && (
        <Kart>
          <div className="mb-2 flex items-center justify-between gap-3">
            <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{bilgi.ad}</h2>
            <Dugme boy="kucuk" onClick={() => setBilgi(null)}>
              {t("ortakKapat")}
            </Dugme>
          </div>
          {/* NEDEN ACILMIYOR — teshisi kullaniciya birakmiyoruz. */}
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("kameraRtspAciklama")}
          </p>
        </Kart>
      )}

      {!error && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {gorunen.map((k) => {
            const oynar = k.oynatilabilir ?? oynatilabilirMi(k.tur, k.restream_url);
            return (
              <Kart key={k.id} className="!p-0 overflow-hidden">
                <button
                  type="button"
                  className="odak-ic block w-full text-start"
                  aria-label={
                    oynar
                      ? t("kameraOynat", { ad: k.ad })
                      : t("kameraNedenOynamiyor", { ad: k.ad })
                  }
                  onClick={() => (oynar ? setOynatilan(k) : setBilgi(k))}
                >
                  <div
                    className="relative aspect-video"
                    style={{ background: "var(--yz-metal-2)" }}
                  >
                    {kareHatalari.has(k.id) ? (
                      // (P190 §6) BAGLANTI YOK — bos/kirik kutu degil ACIK durum.
                      <div
                        className="flex h-full items-center justify-center"
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                      >
                        {t("kameraBaglantiYokWeb")}
                      </div>
                    ) : kareKaynagi(k) ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={`${kareKaynagi(k)}${kareKaynagi(k)!.includes("?") ? "&" : "?"}_k=${nesil}`}
                        alt={k.ad}
                        // (P169 §6) `KameraSeridi`de zaten vardi, izgarada
                        // YOKTU: 20 kameralik bir sitede telefon acilista
                        // 20 anlik goruntuyu birden cekiyordu.
                        loading="lazy"
                        decoding="async"
                        className="h-full w-full object-cover"
                        onError={() =>
                          setKareHatalari((o) => new Set(o).add(k.id))
                        }
                      />
                    ) : (
                      <div
                        className="flex h-full items-center justify-center"
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                      >
                        {t("kameraKareYokWeb")}
                      </div>
                    )}
                    {!oynar && (
                      <span className="absolute end-2 top-2">
                        <Rozet durum={ROZET_UYARI}>{t("kameraOynatilamazRozet")}</Rozet>
                      </span>
                    )}
                  </div>
                </button>
                <div className="space-y-0.5 p-3">
                  <h2 style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
                    {k.ad}
                  </h2>
                  {k.konum ? (
                    <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                      {k.konum}
                    </p>
                  ) : null}
                  <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                    {kareKaynagi(k) ? t("kameraCanliWeb") : t("kameraGoruntuYokWeb")}
                  </p>
                  <div className="flex gap-2 pt-2">
                    <Dugme boy="kucuk" onClick={() => duzenle(k)}>
                      {t("ortakDuzenle")}
                    </Dugme>
                    <Dugme boy="kucuk" tur="tehlike" onClick={() => void sil(k)}>
                      {t("ortakSil")}
                    </Dugme>
                  </div>
                </div>
              </Kart>
            );
          })}
        </div>
      )}

      <Modal
        acik={acik}
        onKapat={() => setAcik(false)}
        baslik={duzenlenen ? t("kameraDuzenle") : t("kameraYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setAcik(false)} disabled={kaydediliyor}>
              {t("ortakVazgec")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="kamera-form" yukleniyor={kaydediliyor}>
              {t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="kamera-form" onSubmit={kaydet} className="space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <AlanSarmal etiket={t("kameraAd")} zorunlu>
              {(b) => (
                <Alan
                  {...b}
                  value={form.ad}
                  onChange={(e) => setForm({ ...form, ad: e.target.value })}
                  required
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("kameraKonum")}>
              {(b) => (
                <Alan
                  {...b}
                  value={form.konum}
                  onChange={(e) => setForm({ ...form, konum: e.target.value })}
                />
              )}
            </AlanSarmal>
            {/* (P191-ek §3) TEK ADRES — GRID ICINDE TAM GENISLIK.
                OLCULEN KUSUR: ornek metni ve test dugmesi dogrudan
                `grid`in cocuguydu; her biri BIR HUCRE kapladi ve sonraki
                alanlar yanlis sutuna kayip ipuclariyla ust uste bindi.
                Adres blogu artik TEK bir `sm:col-span-2` kutusudur. */}
            <div className="sm:col-span-2 space-y-2">
              <AlanSarmal
                etiket={t("kameraAdresi")}
                ipucu={t("kameraAdresIpucu")}
                zorunlu
              >
                {(b) => (
                  <Alan
                    {...b}
                    value={form.stream_url}
                    onChange={(e) => adresYaz(e.target.value)}
                    required
                    data-test="kamera-adres"
                  />
                )}
              </AlanSarmal>
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("kameraAdresOrnek")}
              </p>
              <div className="flex flex-wrap items-center gap-3">
                {/* (P191-ek §3) TEST DUGMESI ARTIK HEP GORUNUR.
                    Onceki surumde `form.tur === "rtsp"` kosuluna baglanmisti
                    ve YENI KAMERA formunda tur varsayilani "hls" oldugu icin
                    dugme HIC cikmiyordu — "ekledim" dedigim sey kullaniciya
                    gorunmuyordu. Artik cizilir; rtsp disi adreste PASIF ve
                    yanindaki not nedenini soyler (gizlemek, kullaniciyi
                    "hani nerede?" diye aratmakti). */}
                <Dugme
                  tur="ikincil"
                  boy="kucuk"
                  disabled={
                    testEdiliyor || !form.stream_url.trim() || form.tur !== TUR_RTSP
                  }
                  onClick={() => void baglantiyiTestEt()}
                  data-test="kamera-test-baglanti"
                >
                  {t("kameraTestEt")}
                </Dugme>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {form.stream_url.trim() && form.tur !== TUR_RTSP
                    ? t("kameraTestRtspNotu")
                    : t("kameraTurAlgilandi", { tur: form.tur.toUpperCase() })}
                </span>
              </div>
            </div>

            {/* GELISMIS AYARLAR — VARSAYILAN KAPALI.
                P190'in mimarisi: izgarada ffmpeg karesi, tiklayinca MediaMTX
                HLS. Yani sistem TEK RTSP adresinden ikisini de KENDI uretir
                ve yoneticinin restream/anlik-kare adresi girmesine gerek
                YOKTUR. Alanlar SILINMEDI: kendi gecidini (Frigate/go2rtc)
                calistiran kurulumlar onlari kullaniyor ve silmek calisan bir
                kurulumu kirardi. */}
            <div className="sm:col-span-2 space-y-3">
              <Dugme
                tur="sessiz"
                boy="kucuk"
                aria-expanded={gelismis}
                onClick={() => setGelismis(!gelismis)}
                data-test="kamera-gelismis"
              >
                {t("kameraGelismis")}
              </Dugme>
              {gelismis ? (
                <div className="space-y-3">
                  <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                    {t("kameraGelismisAciklama")}
                  </p>
                  <AlanSarmal etiket={t("kameraTur")}>
                    {(b) => (
                      <Secim
                        {...b}
                        value={form.tur}
                        onChange={(e) =>
                          setForm({ ...form, tur: e.target.value as CameraTur })
                        }
                      >
                        {TUR_SECENEKLERI}
                      </Secim>
                    )}
                  </AlanSarmal>
                  <AlanSarmal etiket={t("kameraRestream")} ipucu={t("kameraRestreamIpucu")}>
                    {(b) => (
                      <Alan
                        {...b}
                        value={form.restream_url}
                        onChange={(e) =>
                          setForm({ ...form, restream_url: e.target.value })
                        }
                      />
                    )}
                  </AlanSarmal>
                  <AlanSarmal etiket={t("kameraSnapshot")} ipucu={t("kameraSnapshotIpucu")}>
                    {(b) => (
                      <Alan
                        {...b}
                        value={form.snapshot_url}
                        onChange={(e) =>
                          setForm({ ...form, snapshot_url: e.target.value })
                        }
                      />
                    )}
                  </AlanSarmal>
                </div>
              ) : null}
            </div>

            <label
              className="flex items-center gap-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
            >
              <input
                type="checkbox"
                checked={form.sakin_gorebilir}
                onChange={(e) => setForm({ ...form, sakin_gorebilir: e.target.checked })}
              />
              {t("kameraSakinGorebilirOnay")}
            </label>
            {/* (P213 §4) ANA EKRAN — GORUNURLUKTEN AYRI BIR SORU.
                `sakin_gorebilir` YETKI ("sakin gorebilir mi"),
                bu ise YERLESIM ("ozetin bandinda dursun mu"). Ayni
                kutuya baglamak, otopark kamerasini sakinlere acan
                yoneticinin ozetini de kendiliginden doldururdu. */}
            <label
              className="flex items-center gap-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
            >
              <input
                type="checkbox"
                data-test="kamera-ana-ekranda"
                checked={form.ana_ekranda}
                onChange={(e) => setForm({ ...form, ana_ekranda: e.target.checked })}
              />
              {t("kameraAnaEkrandaOnay")}
            </label>
            <label
              className="flex items-center gap-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
            >
              <input
                type="checkbox"
                checked={form.aktif}
                onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
              />
              {t("ortakAktif")}
            </label>
          </div>
          {formHata && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {formHata}
            </p>
          )}
        </form>
      </Modal>
      {diyalog}
    </div>
  );
}
