"use client";

import { useMemo, useRef, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Modal,
  VeriTablosu,
  useOnay,
  type Kolon,
} from "@/components/ui";
import { apiSend, agIstegi } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P167 §6.3) DOKUMAN YONETIMI — kendi sayfasi.
 *
 * =========================================================================
 * UC GERCEK EKSIK KAPANDI (ucu de sessizdi)
 * =========================================================================
 *  1. INDIRME YOKTU. Dosya yuklenebiliyor ve listelenebiliyordu ama
 *     INDIRILEMIYORDU — arsivin tek amaci olan sey yapilamiyordu. Yeni uc
 *     `GET /dokumanlar/{id}/indir` kisa omurlu bir baglanti doner.
 *  2. SILME DEPODA COP BIRAKIYORDU. Kayit siliniyor, MinIO objesi
 *     sonsuza kadar kaliyordu. Artik yumusak silme + gecelik supurme.
 *  3. YUKLEME AKISI YOKTU. Sayfa yalnizca listeliyordu; dosya baska bir
 *     ekrandan gelmis olmaliydi.
 *
 * =========================================================================
 * YUKLEME: PRESIGN -> DOGRUDAN DEPOYA PUT -> KAYIT
 * =========================================================================
 * Dosya KENDI SUNUCUMUZDAN GECMEZ (duyuru gorseli ve ek dosyalariyla ayni
 * akis). Proxylemek, 25 MB'lik bir yuklemeyi uygulama surecinin bellegine
 * sokmak ve boyut sinirini iki yerde tutmak olurdu.
 *
 * SIRA ONEMLI: once obje, sonra kayit. Tersi olsaydi, PUT basarisiz
 * oldugunda listede DOSYASI OLMAYAN bir satir kalirdi — tiklaninca
 * hicbir sey indirmeyen bir kayit.
 */

interface Dokuman {
  id: string;
  ad: string;
  obje_anahtari: string;
  boyut_bayt: number | null;
  yukleyen_ad: string | null;
  created_at: string;
}

interface PresignBileti {
  upload_url: string;
  foto_key: string;
}

const BOS = "";
const SAYFA_BOYU = 25;
/** Sunucu siniri (`DokumanCreate.boyut_bayt le=26_214_400`) — istemci de
 *  ayni sayiyi uygular ki kullanici 25 MB'lik yuklemeyi TAMAMLAYIP
 *  sonunda reddedilmesin. */
const MAKS_BAYT = 26_214_400;
const KB = 1024;
/** Kabul edilen turler. Sunucu icerik tipini SERBEST birakiyor; sinirlama
 *  burada bir KOLAYLIK (dosya secicide filtre), guvenlik siniri degil —
 *  guvenligi depo ve `Content-Type` basligi tasir. */
const KABUL = ".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.png,.jpg,.jpeg,.zip";
const VARSAYILAN_TUR = "application/octet-stream";
const YENI_SEKME = "_blank";
const SEKME_GUVENLIGI = "noopener";
const YUZDE_TAM = 100;

export default function DokumanlarPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const [sayfa, setSayfa] = useState(0);

  const { data, error, isLoading, mutate } = useSWR<{
    meta: { total: number };
    items: Dokuman[];
  }>(
    `/api/panel/dokumanlar?limit=${SAYFA_BOYU}&offset=${sayfa * SAYFA_BOYU}`,
    jsonFetcher,
  );

  const [secili, setSecili] = useState<string[]>([]);
  const [acik, setAcik] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [dosya, setDosya] = useState<File | null>(null);
  const [ad, setAd] = useState(BOS);
  const [aciklama, setAciklama] = useState(BOS);
  const [ilerleme, setIlerleme] = useState<number | null>(null);
  const [suruklu, setSuruklu] = useState(false);
  const girdiRef = useRef<HTMLInputElement | null>(null);

  function kapat(): void {
    setAcik(false);
    setDosya(null);
    setAd(BOS);
    setAciklama(BOS);
    setHata(null);
    setIlerleme(null);
  }

  function dosyaAl(f: File | null): void {
    setHata(null);
    if (!f) return;
    if (f.size > MAKS_BAYT) {
      // SINIR YUKLEMEDEN ONCE KONTROL EDILIR: 30 MB'lik bir dosyayi
      // yukleyip sonunda reddetmek, kullanicinin bant genisligini ve
      // dakikalarini harcamak olurdu.
      setHata(t("dokumanCokBuyuk", { mb: Math.floor(MAKS_BAYT / KB / KB) }));
      return;
    }
    setDosya(f);
    // AD DOSYA ADINDAN ON-DOLDURULUR ama KILITLI DEGIL: cogu zaman dogru,
    // bazen "tarama0001.pdf" gibi anlamsizdir.
    if (ad === BOS) setAd(f.name);
  }

  /**
   * Depoya PUT — ILERLEME ICIN `XMLHttpRequest`.
   *
   * `fetch` govde yukleme ilerlemesi VERMEZ. Brief ilerleme gostergesi
   * istiyor ve 25 MB'lik bir dosyada "bir sey oluyor mu" sorusu gercek:
   * gostergesiz bir bekleme, kullaniciyi ikinci kez yuklemeye iter.
   */
  function depoyaYukle(url: string, f: File): Promise<void> {
    return new Promise((coz, red) => {
      const istek = new XMLHttpRequest();
      istek.open("PUT", url);
      istek.setRequestHeader("Content-Type", f.type || VARSAYILAN_TUR);
      istek.upload.onprogress = (o) => {
        if (o.lengthComputable) {
          setIlerleme(Math.round((o.loaded / o.total) * YUZDE_TAM));
        }
      };
      istek.onload = () =>
        istek.status >= 200 && istek.status < 300
          ? coz()
          : red(new Error(t("yuklemeBasarisiz", { kod: istek.status })));
      istek.onerror = () => red(new Error(t("yuklemeBasarisiz", { kod: 0 })));
      istek.send(f);
    });
  }

  async function yukle(): Promise<void> {
    if (!dosya) {
      setHata(t("dokumanDosyaSec"));
      return;
    }
    setHata(null);
    setIlerleme(0);
    try {
      const bilet = await apiSend<PresignBileti>("/api/uploads/presign", "POST", {
        content_type: dosya.type || VARSAYILAN_TUR,
        dosya_adi: dosya.name,
      });
      await depoyaYukle(bilet.upload_url, dosya);
      await apiSend("/api/panel/dokumanlar", "POST", {
        ad: ad.trim() || dosya.name,
        obje_anahtari: bilet.foto_key,
        icerik_tipi: dosya.type || null,
        boyut_bayt: dosya.size,
        aciklama: aciklama.trim() || null,
      });
      toast.success(t("dokumanYuklendi"));
      kapat();
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
      setIlerleme(null);
    }
  }

  async function indir(d: Dokuman): Promise<void> {
    setHata(null);
    try {
      const res = await agIstegi(`/api/panel/dokumanlar/${d.id}/indir`);
      if (res === null) return; // oturum bitti -> yonlendirildi
      const veri = await res.json().catch(() => null);
      if (!res.ok) throw new Error(veri?.error?.message ?? String(res.status));
      window.open(veri.url as string, YENI_SEKME, SEKME_GUVENLIGI);
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  async function sil(idler: string[]): Promise<void> {
    if (
      !(await onayla({
        baslik: t("ortakSilBaslik"),
        mesaj: t("dokumanSilOnay", { adet: idler.length }),
        onayMetni: t("ortakSil"),
        tehlikeli: true,
      }))
    )
      return;
    setHata(null);
    try {
      // SIRAYLA: toplu silme ucu YOK ve uydurulmadi. Paralel gondermek,
      // birinin dusmesi halinde "kaci silindi" sorusunu cevapsiz
      // birakirdi.
      for (const id of idler) {
        await apiSend(`/api/panel/dokumanlar/${id}`, "DELETE");
      }
      toast.success(t("dokumanSilindi"));
      setSecili([]);
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    }
  }

  const kolonlar: Kolon<Dokuman>[] = useMemo(
    () => [
      {
        id: "created_at",
        baslik: t("dokumanTarih"),
        hucre: (d) => formatDateTime(d.created_at),
        deger: (d) => d.created_at,
      },
      { id: "ad", baslik: t("dokumanAd"), hucre: (d) => d.ad, deger: (d) => d.ad },
      {
        id: "yukleyen",
        baslik: t("dokumanYukleyen"),
        hucre: (d) => d.yukleyen_ad ?? t("ortakYok"),
      },
      {
        id: "boyut",
        baslik: t("dokumanBoyut"),
        sayisal: true,
        hucre: (d) =>
          d.boyut_bayt === null ? t("ortakYok") : String(Math.round(d.boyut_bayt / KB)),
        deger: (d) => d.boyut_bayt,
      },
      {
        id: "eylem",
        baslik: t("listeIslemler"),
        hucre: (d) => (
          <span className="flex gap-2">
            <Dugme boy="kucuk" onClick={() => void indir(d)}>
              {t("dokumanIndir")}
            </Dugme>
            <Dugme tur="tehlike" boy="kucuk" onClick={() => void sil([d.id])}>
              {t("ortakSil")}
            </Dugme>
          </span>
        ),
      },
    ],
    [t],
  );

  const toplam = data?.meta.total ?? 0;
  const sonSayfa = Math.max(0, Math.ceil(toplam / SAYFA_BOYU) - 1);

  return (
    <div className="space-y-6">
      {diyalog}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("dokumanBaslik")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("dokumanAlt")}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {/* EXCEL: rapor motorundan. Ikinci bir Excel yazicisi yazmak,
              sutun bicimlerinin iki yerde yasamasi olurdu. */}
          <a
            className="odak-ic yz-lift inline-flex items-center gap-2 px-3 py-2"
            style={{
              borderRadius: "var(--yz-radius-btn)",
              border: "var(--yz-border-w) solid var(--yz-border)",
              fontSize: "var(--yz-fs-sm)",
              color: "var(--yz-success-ink)",
            }}
            href="/raporlar"
            aria-label={t("dokumanExcel")}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <rect
                x="3" y="4" width="18" height="16" rx="2"
                stroke="currentColor" strokeWidth="1.6"
              />
              <path d="M3 9h18M9 9v11M15 9v11" stroke="currentColor" strokeWidth="1.6" />
            </svg>
            {t("dokumanExcel")}
          </a>
          <Dugme tur="birincil" onClick={() => setAcik(true)}>
            {t("dokumanYukle")}
          </Dugme>
        </div>
      </div>

      {hata ? <HataDurumu mesaj={hata} /> : null}

      <VeriTablosu<Dokuman>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(d) => d.id}
        yukleniyor={isLoading}
        hata={error ? t("dokumanHata") : null}
        onTekrar={() => void mutate()}
        bosBaslik={t("dokumanYok")}
        bosAciklama={t("dokumanYokAlt")}
        secilebilir
        secili={secili}
        onSeciliDegisti={setSecili}
        topluEylemler={(idler) => (
          <Dugme tur="tehlike" boy="kucuk" onClick={() => void sil(idler)}>
            {t("dokumanTopluSil", { adet: idler.length })}
          </Dugme>
        )}
      />

      {/* SAYFALAMA SUNUCU TARAFLI: uc `limit`/`offset` aliyor ve
          `meta.total` donuyor. Istemcide sayfalamak, 25 kaydi alip
          "25 kayit var" demek olurdu — sessiz ve yanlis. */}
      {toplam > SAYFA_BOYU ? (
        <div className="flex items-center justify-end gap-3">
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("dokumanSayfa", { sayfa: sayfa + 1, toplam: sonSayfa + 1 })}
          </span>
          <Dugme boy="kucuk" disabled={sayfa === 0} onClick={() => setSayfa((s) => s - 1)}>
            {t("ortakOnceki")}
          </Dugme>
          <Dugme
            boy="kucuk"
            disabled={sayfa >= sonSayfa}
            onClick={() => setSayfa((s) => s + 1)}
          >
            {t("ortakSonraki")}
          </Dugme>
        </div>
      ) : null}

      <Modal
        acik={acik}
        onKapat={kapat}
        baslik={t("dokumanYukle")}
        kirliMi={dosya !== null}
        eylemler={
          <div className="flex justify-end gap-2">
            <Dugme tur="sessiz" onClick={kapat}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
              tur="birincil"
              disabled={ilerleme !== null}
              onClick={() => void yukle()}
            >
              {t("dokumanYukle")}
            </Dugme>
          </div>
        }
      >
        <div className="space-y-3">
          {hata ? <HataDurumu mesaj={hata} /> : null}

          {/* SURUKLE-BIRAK ALANI. `<button>` bilincli: klavyeyle de
              acilabilmeli — surukleme bir FARE hareketidir ve tek yol
              olsaydi ekran okuyucu kullanicisi dosya yukleyemezdi. */}
          <button
            type="button"
            onClick={() => girdiRef.current?.click()}
            onDragOver={(e) => {
              e.preventDefault();
              setSuruklu(true);
            }}
            onDragLeave={() => setSuruklu(false)}
            onDrop={(e) => {
              e.preventDefault();
              setSuruklu(false);
              dosyaAl(e.dataTransfer.files?.[0] ?? null);
            }}
            className="odak-ic flex w-full flex-col items-center gap-1 px-4 py-8"
            style={{
              borderRadius: "var(--yz-radius-btn)",
              border: `var(--yz-border-w) dashed ${
                suruklu ? "var(--yz-accent)" : "var(--yz-border)"
              }`,
              background: "var(--yz-metal-1)",
            }}
          >
            <span style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
              {dosya ? dosya.name : t("dokumanBirak")}
            </span>
            <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {t("dokumanSinir", { mb: Math.floor(MAKS_BAYT / KB / KB) })}
            </span>
          </button>
          {/* GIZLI ama ADSIZ DEGIL: `hidden` gorunmezligi saglar, ama
              girdi hâlâ erisilebilirlik agacinda. Adsiz birakmak, ekran
              okuyucuya adsiz bir dosya denetimi okutmak olurdu. */}
          <input
            ref={girdiRef}
            type="file"
            accept={KABUL}
            aria-label={t("dokumanYukle")}
            className="hidden"
            onChange={(e) => dosyaAl(e.target.files?.[0] ?? null)}
          />

          {ilerleme !== null ? (
            <div>
              <div
                role="progressbar"
                aria-valuenow={ilerleme}
                aria-valuemin={0}
                aria-valuemax={YUZDE_TAM}
                aria-label={t("dokumanIlerleme")}
                className="h-2 w-full overflow-hidden"
                style={{ borderRadius: "var(--yz-radius-btn)", background: "var(--yz-metal-2)" }}
              >
                <div
                  className="h-full"
                  style={{ width: `${ilerleme}%`, background: "var(--yz-accent)" }}
                />
              </div>
              <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("dokumanIlerlemeYuzde", { yuzde: ilerleme })}
              </p>
            </div>
          ) : null}

          <AlanSarmal etiket={t("dokumanAd")}>
            {(b) => <Alan {...b} value={ad} onChange={(e) => setAd(e.target.value)} />}
          </AlanSarmal>
          <AlanSarmal etiket={t("dokumanAciklama")}>
            {(b) => (
              <Alan {...b} value={aciklama} onChange={(e) => setAciklama(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
      </Modal>
    </div>
  );
}
