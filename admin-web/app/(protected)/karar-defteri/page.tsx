"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  CokSatir,
  Dugme,
  HataDurumu,
  Modal,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P167 §6.2) KARAR DEFTERI — kendi sayfasi.
 *
 * =========================================================================
 * NEREDEN GELDI
 * =========================================================================
 * Brief §6.1 "Yonetisim alt basligi tamamen kaldirilsin" diyor. Karar
 * defteri o sayfanin icindeki dort bolumden biriydi ve artik kendi
 * basligi var (§6.2).
 *
 * =========================================================================
 * FORM SAYFADAN MODALA TASINDI
 * =========================================================================
 * Eski sayfada form LISTENIN ALTINDA duruyordu. Bu, uzun bir karar metni
 * yazarken listenin ekrandan kaymasi ve "hangi numaradan devam ediyorum"
 * sorusunun goz denetimine kalmasi demekti. Brief de modal istiyor.
 *
 * =========================================================================
 * NUMARA ARTIK ZORUNLU DEGIL
 * =========================================================================
 * Brief'in alan listesinde yildiz yalniz "Konu"da. Numara bos
 * birakilirsa sunucu MERKEZI seriden uretiyor (`KRR-2026-000001`) —
 * Asama 4'un "her modul kendi numarasini uretmesin" ilkesiyle ayni
 * sayactan. Eskiden numara zorunluydu ve kullanici her karar icin bir
 * numara UYDURMAK zorundaydi; seri tutarliligi insan hafizasina
 * birakilmisti.
 */

interface Uye {
  ad: string;
  gorev?: string | null;
}

interface Karar {
  id: string;
  karar_no: string;
  tarih: string;
  konu: string;
  metin: string;
  baskan_ad: string | null;
  uyeler: Uye[];
}

const BOS = "";
const UYE_AYIRACI = ", ";
/** Sunucu sinirlari (`KararDefteriCreate`) — istemci de aynisini uygular. */
const MAKS_UYE = 50;

/** Bos bir uye satiri. Yeni satir eklemek `[...]` ile yapilir. */
function bosUye(): Uye {
  return { ad: BOS, gorev: BOS };
}

export default function KararDefteriPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Karar[] }>(
    "/api/panel/karar-defteri?limit=200",
    jsonFetcher,
  );

  const [acik, setAcik] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  const [konu, setKonu] = useState(BOS);
  const [no, setNo] = useState(BOS);
  const [tarih, setTarih] = useState(BOS);
  const [metin, setMetin] = useState(BOS);
  const [baskan, setBaskan] = useState(BOS);
  // BRIEF: "birden fazla Uye satiri". Tek bir cok-satirli kutuya
  // satir satir ad yazdirmak (eski hali) uyenin GOREVINI tasiyamazdi ve
  // sunucu modeli `{ad, gorev}` bekliyor.
  const [uyeler, setUyeler] = useState<Uye[]>([bosUye()]);

  const kirli =
    konu !== BOS || no !== BOS || metin !== BOS || baskan !== BOS ||
    uyeler.some((u) => u.ad !== BOS || (u.gorev ?? BOS) !== BOS);

  function sifirla(): void {
    setKonu(BOS);
    setNo(BOS);
    setTarih(BOS);
    setMetin(BOS);
    setBaskan(BOS);
    setUyeler([bosUye()]);
    setHata(null);
  }

  function kapat(): void {
    setAcik(false);
    sifirla();
  }

  function uyeYaz(i: number, alan: keyof Uye, deger: string): void {
    setUyeler((o) => o.map((u, j) => (j === i ? { ...u, [alan]: deger } : u)));
  }

  async function kaydet(): Promise<void> {
    setHata(null);
    if (!konu.trim() || !metin.trim()) {
      setHata(t("kararZorunlu"));
      return;
    }
    setMesgul(true);
    try {
      await apiSend("/api/panel/karar-defteri", "POST", {
        konu: konu.trim(),
        // BOS ALAN GONDERILMEZ: bos dizgeyi numara diye gondermek
        // sunucuda dogrulama hatasi uretirdi (`min_length=1`). Alan hic
        // gonderilmezse sunucu seriden uretir.
        ...(no.trim() ? { karar_no: no.trim() } : {}),
        ...(tarih ? { tarih } : {}),
        metin: metin.trim(),
        baskan_ad: baskan.trim() || null,
        // BOS UYE SATIRLARI ATILIR: bos ad sunucuda 422 verir ve
        // KAYDIN TAMAMINI dusururdu — kullanici bir satiri bos
        // biraktigi icin butun karari kaybederdi.
        uyeler: uyeler
          .map((u) => ({ ad: u.ad.trim(), gorev: (u.gorev ?? BOS).trim() || null }))
          .filter((u) => u.ad !== BOS),
      });
      toast.success(t("kararEklendi"));
      kapat();
      await mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
    } finally {
      setMesgul(false);
    }
  }

  const kolonlar: Kolon<Karar>[] = useMemo(
    () => [
      {
        id: "karar_no",
        baslik: t("kararNo"),
        hucre: (k) => k.karar_no,
        deger: (k) => k.karar_no,
      },
      {
        id: "tarih",
        baslik: t("kararTarih"),
        hucre: (k) => formatDateTime(k.tarih),
        deger: (k) => k.tarih,
      },
      { id: "konu", baslik: t("kararKonu"), hucre: (k) => k.konu, deger: (k) => k.konu },
      {
        id: "baskan",
        baslik: t("kararBaskan"),
        hucre: (k) => k.baskan_ad ?? t("ortakYok"),
      },
      {
        id: "uyeler",
        baslik: t("kararUyeler"),
        hucre: (k) => k.uyeler.map((u) => u.ad).join(UYE_AYIRACI) || t("ortakYok"),
      },
      {
        id: "pdf",
        baslik: t("listeIslemler"),
        hucre: (k) => (
          // PDF METIN SABLONUYLA uretilir (P33): karar bir YAZIDIR,
          // tabloya sikistirmak metni hucrelere bolerdi.
          <a
            className="odak-ic underline"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }}
            href={`/api/panel/karar-pdf/${k.id}`}
            target="_blank"
            rel="noreferrer"
          >
            {t("kararPdf")}
          </a>
        ),
      },
    ],
    [t],
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("kararBaslik")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("kararAlt")}
          </p>
        </div>
        <Dugme tur="birincil" onClick={() => setAcik(true)}>
          {t("kararEkle")}
        </Dugme>
      </div>

      <VeriTablosu<Karar>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(k) => k.id}
        yukleniyor={isLoading}
        hata={error ? t("kararHata") : null}
        onTekrar={() => void mutate()}
        bosBaslik={t("kararYok")}
        bosAciklama={t("kararYokAlt")}
      />

      <Modal
        acik={acik}
        onKapat={kapat}
        baslik={t("kararEkle")}
        kirliMi={kirli}
        genislikSinifi="max-w-2xl"
        eylemler={
          <div className="flex justify-end gap-2">
            <Dugme tur="sessiz" onClick={kapat}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={mesgul} onClick={() => void kaydet()}>
              {t("ortakKaydet")}
            </Dugme>
          </div>
        }
      >
        <div className="space-y-3">
          {hata ? <HataDurumu mesaj={hata} /> : null}

          <div className="grid gap-3 sm:grid-cols-2">
            <AlanSarmal etiket={t("kararKonu")} zorunlu>
              {(b) => <Alan {...b} value={konu} onChange={(e) => setKonu(e.target.value)} />}
            </AlanSarmal>
            <AlanSarmal etiket={t("kararNo")} ipucu={t("kararNoIpucu")}>
              {(b) => <Alan {...b} value={no} onChange={(e) => setNo(e.target.value)} />}
            </AlanSarmal>
            <AlanSarmal etiket={t("kararTarih")}>
              {(b) => (
                <Alan {...b} type="date" value={tarih} onChange={(e) => setTarih(e.target.value)} />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("kararBaskan")}>
              {(b) => <Alan {...b} value={baskan} onChange={(e) => setBaskan(e.target.value)} />}
            </AlanSarmal>
          </div>

          <AlanSarmal etiket={t("kararMetin")} zorunlu>
            {(b) => (
              <CokSatir {...b} rows={6} value={metin} onChange={(e) => setMetin(e.target.value)} />
            )}
          </AlanSarmal>

          <fieldset className="space-y-2">
            <legend style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
              {t("kararUyeler")}
            </legend>
            {uyeler.map((u, i) => (
              <div key={i} className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]">
                <AlanSarmal etiket={t("kararUyeAd")}>
                  {(b) => (
                    <Alan {...b} value={u.ad} onChange={(e) => uyeYaz(i, "ad", e.target.value)} />
                  )}
                </AlanSarmal>
                <AlanSarmal etiket={t("kararUyeGorev")}>
                  {(b) => (
                    <Alan
                      {...b}
                      value={u.gorev ?? BOS}
                      onChange={(e) => uyeYaz(i, "gorev", e.target.value)}
                    />
                  )}
                </AlanSarmal>
                <div className="flex items-end pb-1">
                  {/* SON SATIR SILINEMEZ: sifir satirli bir liste,
                      kullaniciyi once "ekle"ye basmak zorunda birakirdi. */}
                  <Dugme
                    tur="sessiz"
                    boy="kucuk"
                    disabled={uyeler.length === 1}
                    onClick={() => setUyeler((o) => o.filter((_, j) => j !== i))}
                  >
                    {t("ortakSil")}
                  </Dugme>
                </div>
              </div>
            ))}
            <Dugme
              boy="kucuk"
              disabled={uyeler.length >= MAKS_UYE}
              onClick={() => setUyeler((o) => [...o, bosUye()])}
            >
              {t("kararUyeEkle")}
            </Dugme>
          </fieldset>
        </div>
      </Modal>
    </div>
  );
}
