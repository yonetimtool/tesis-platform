"use client";

/**
 * (P250 §4) EGITIM VIDEOLARI — PLATFORM YONETIMI (panel.*).
 *
 * Videolari platform yoneticisi YouTube'a "liste disi" yukler; burada her
 * kurulum sihirbazi adimi icin baglanti, baslik, kisa aciklama, sira ve
 * aktiflik girilir. Sunucu YALNIZ video kimligini saklar; video sunucumuzda
 * durmaz. Degisiklik ANINDA yayindadir (uygulama surumu gerekmez).
 *
 * KAYDETMEDEN ONCE ONIZLEME: gizli (private) ya da yerlestirmesi kapali
 * video OYNAMAZ. Onizleme oynatici hatasini yakalar ve "video gizli
 * olabilir ya da yerlestirmeye izin verilmemis" uyarisini gosterir —
 * yonetici bunu kullanicilardan once gorur.
 */
import { useEffect, useState } from "react";
import useSWR from "swr";

import { YoutubeOynatici } from "@/components/YoutubeOynatici";
import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Kart, Rozet, type RozetDurumu } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { KURULUM_HEDEFLERI } from "@/lib/kurulum-adimlari";
import { youtubeKimligi } from "@/lib/youtube";

type Video = {
  adim_kodu: string;
  youtube_id: string;
  baslik: string;
  aciklama: string | null;
  sira: number;
  aktif: boolean;
  surum: number;
};
type Liste = { set_kodu: string; adimlar: string[]; videolar: Video[] };

const UC = "/api/egitim-videolari/yonetim";
const TON_OLUMLU: RozetDurumu = "olumlu";
const TON_NOTR: RozetDurumu = "notr";
const VARSAYILAN_ETIKET: SozlukAnahtari = "egitimAdimBilinmeyen";
/** Bicim ornegi (cevrilecek metin degil, adres). */
const BAGLANTI_ORNEGI = "https://youtu.be/…";

export default function EgitimVideolariSayfasi() {
  const t = useT();
  const { data, error, mutate } = useSWR<Liste>(UC, jsonFetcher);

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold" style={{ color: "var(--yz-text)" }}>
          {t("egitimPanelBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("egitimPanelAciklama")}
        </p>
        <p className="mt-1" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
          {t("egitimPanelSurumNotu")}
        </p>
      </div>
      <HataDurumu mesaj={error ? t("ortakHataOlustu") : null} onTekrar={() => void mutate()} />
      {data?.adimlar.map((adim, i) => (
        <AdimKarti
          key={adim}
          adim={adim}
          sira={i}
          video={data.videolar.find((v) => v.adim_kodu === adim) ?? null}
          onDegisti={() => void mutate()}
        />
      ))}
    </div>
  );
}

function AdimKarti({
  adim,
  sira,
  video,
  onDegisti,
}: {
  adim: string;
  sira: number;
  video: Video | null;
  onDegisti: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const [baglanti, setBaglanti] = useState("");
  const [baslik, setBaslik] = useState("");
  const [aciklama, setAciklama] = useState("");
  const [siraDeger, setSiraDeger] = useState("");
  const [aktif, setAktif] = useState(true);
  const [onizleme, setOnizleme] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);
  const [hata, setHata] = useState<string | null>(null);

  useEffect(() => {
    setBaglanti(video ? `https://youtu.be/${video.youtube_id}` : "");
    setBaslik(video?.baslik ?? "");
    setAciklama(video?.aciklama ?? "");
    // Varsayilan sira sihirbazdaki yerin 10 kati (sunucuyla ayni kural):
    // hic dokunulmazsa sihirbaz sirasi korunur.
    setSiraDeger(String(video?.sira ?? (sira + 1) * 10));
    setAktif(video?.aktif ?? true);
    setOnizleme(null);
    setHata(null);
  }, [video, sira]);

  const etiket = t((KURULUM_HEDEFLERI[adim]?.etiket as SozlukAnahtari | undefined) ?? VARSAYILAN_ETIKET);

  function onizle() {
    const kimlik = youtubeKimligi(baglanti);
    if (!kimlik) {
      setHata(t("egitimPanelGecersiz"));
      setOnizleme(null);
      return;
    }
    setHata(null);
    setOnizleme(kimlik);
  }

  async function kaydet() {
    if (!youtubeKimligi(baglanti)) {
      setHata(t("egitimPanelGecersiz"));
      return;
    }
    setKaydediyor(true);
    try {
      await apiSend(`${UC}/${adim}`, "PUT", {
        baglanti,
        baslik,
        aciklama: aciklama || null,
        sira: Number(siraDeger) || 0,
        aktif,
      });
      toast.success(t("egitimPanelKaydedildi"));
      onDegisti();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  async function sil() {
    setKaydediyor(true);
    try {
      await apiSend(`${UC}/${adim}`, "DELETE");
      toast.success(t("egitimPanelKaldirildi"));
      onDegisti();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <Kart>
      <div className="space-y-3" data-test={`egitim-panel-${adim}`}>
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="font-semibold" style={{ color: "var(--yz-text)" }}>
            {sira + 1}. {etiket}
          </h2>
          {video ? (
            <Rozet durum={video.aktif ? TON_OLUMLU : TON_NOTR}>
              {video.aktif ? t("egitimPanelAktif") : t("egitimYakinda")}
            </Rozet>
          ) : (
            <Rozet durum={TON_NOTR}>{t("egitimPanelYok")}</Rozet>
          )}
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("egitimPanelBaglanti")} hata={hata}>
            {(b) => (
              <Alan
                {...b}
                data-test="egitim-panel-baglanti"
                value={baglanti}
                maxLength={2048 /* sunucu: EgitimVideosuYaz.baglanti */}
                placeholder={BAGLANTI_ORNEGI}
                onChange={(e) => {
                  setBaglanti(e.target.value);
                  setHata(null);
                }}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("egitimPanelBaslikAlan")}>
            {(b) => (
              <Alan
                {...b}
                data-test="egitim-panel-baslik"
                value={baslik}
                maxLength={200 /* sunucu: EgitimVideosuYaz.baslik */}
                onChange={(e) => setBaslik(e.target.value)}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("egitimPanelAciklamaAlan")}>
            {(b) => (
              <Alan
                {...b}
                value={aciklama}
                maxLength={500 /* sunucu: EgitimVideosuYaz.aciklama */}
                onChange={(e) => setAciklama(e.target.value)}
              />
            )}
          </AlanSarmal>
          <div className="flex items-end gap-4">
            <AlanSarmal etiket={t("egitimPanelSira")}>
              {(b) => (
                <Alan
                  {...b}
                  inputMode="numeric"
                  value={siraDeger}
                  maxLength={4 /* sunucu: 0-9999 */}
                  onChange={(e) => setSiraDeger(e.target.value.replace(/\D/g, ""))}
                />
              )}
            </AlanSarmal>
            <label className="inline-flex items-center gap-2 pb-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
              <input type="checkbox" checked={aktif} onChange={(e) => setAktif(e.target.checked)} />
              {t("egitimPanelAktif")}
            </label>
          </div>
        </div>
        {onizleme && (
          <div className="max-w-xl">
            <YoutubeOynatici videoId={onizleme} baslik={baslik || etiket} />
          </div>
        )}
        <div className="flex flex-wrap gap-2">
          <Dugme tur="ikincil" data-test="egitim-panel-onizle" onClick={onizle} disabled={!baglanti}>
            {t("egitimPanelOnizle")}
          </Dugme>
          <Dugme
            tur="birincil"
            data-test="egitim-panel-kaydet"
            onClick={() => void kaydet()}
            disabled={kaydediyor || !baglanti || !baslik.trim()}
          >
            {t("ortakKaydet")}
          </Dugme>
          {video && (
            <Dugme tur="sessiz" onClick={() => void sil()} disabled={kaydediyor}>
              {t("egitimPanelSil")}
            </Dugme>
          )}
        </div>
      </div>
    </Kart>
  );
}
