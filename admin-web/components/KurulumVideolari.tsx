"use client";

// (P250 §4) KURULUM VIDEOLARI — ana sayfa karti + acilir pencere.
//
// PENCERE (modal):
//   * buyuk 16:9 video alani (IFrame API, youtube-nocookie, rel=0),
//   * altinda adim numaralari 1, 2, 3...: izlenende onay isareti, aktif
//     adim vurgulu, tiklayinca o adima gecer,
//   * ileri / geri oklari (klavyede sol/sag ok tuslari da),
//   * "Simdi bu adimi yap": pencere kapanir, ilgili sayfaya gidilir; video
//     BITINCE vurgulanir,
//   * Esc ve disari tiklama kapatir (ortak `Modal`).
//   * Videosu olmayan adim "yakinda" — kirik oynatici YOK.
//
// IZLENDI bilgisi HESAPTA (`/egitim-videolari`): web ve mobil ayni.
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import useSWR from "swr";

import { YoutubeOynatici } from "@/components/YoutubeOynatici";
import { Dugme, Kart, Modal } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { KURULUM_HEDEFLERI } from "@/lib/kurulum-adimlari";

export const EGITIM_UC = "/api/egitim-videolari";

export type EgitimAdim = {
  adim_kodu: string;
  video: { youtube_id: string; baslik: string; aciklama: string | null } | null;
  izlendi: boolean;
};
export type EgitimListe = {
  set_kodu: string;
  adimlar: EgitimAdim[];
  toplam: number;
  izlenen: number;
  kurulum_tamam: boolean;
};

const VARSAYILAN_ETIKET: SozlukAnahtari = "egitimAdimBilinmeyen";
// JSX icinde dize yazilmaz (`sabit-metin` kilidi): durum degerleri sabit.
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
const TUR_SESSIZ = "sessiz" as const;
const BOY_KUCUK = "kucuk" as const;
const EVET = "evet";
const HAYIR = "hayir";
const ADIM = "step" as const;
const SAYDAM = "transparent";
const ACIK_RENK = "var(--yz-on-fill)";

function adimEtiketi(kod: string): SozlukAnahtari {
  return (KURULUM_HEDEFLERI[kod]?.etiket as SozlukAnahtari | undefined) ?? VARSAYILAN_ETIKET;
}

export function useEgitimVideolari() {
  return useSWR<EgitimListe>(EGITIM_UC, jsonFetcher);
}

export function KurulumVideolariPenceresi({
  acik,
  onKapat,
  baslangic,
}: {
  acik: boolean;
  onKapat: () => void;
  /** Pencere bu adimda acilir (sihirbazdaki "Videoyu izle"). */
  baslangic?: string | null;
}) {
  const t = useT();
  const router = useRouter();
  const { data, mutate } = useEgitimVideolari();
  const adimlar = useMemo(() => data?.adimlar ?? [], [data]);
  const [sira, setSira] = useState(0);
  const [bitti, setBitti] = useState(false);
  // Konum her ACILISTA BIR KEZ secilir — ama veri geldikten sonra. Pencere
  // liste yuklenmeden acilirsa (ilk ziyaret) secim bos listeye bakip hep
  // 0'da kaliyordu (olculdu). Izlendi isareti gelince yer DEGISMEMELI.
  const [konumlandi, setKonumlandi] = useState(false);

  useEffect(() => {
    if (!acik) {
      setKonumlandi(false);
      return;
    }
    if (konumlandi || adimlar.length === 0) return;
    const i = baslangic ? adimlar.findIndex((a) => a.adim_kodu === baslangic) : -1;
    setSira(i >= 0 ? i : Math.max(0, adimlar.findIndex((a) => a.video && !a.izlendi)));
    setBitti(false);
    setKonumlandi(true);
  }, [acik, baslangic, adimlar, konumlandi]);

  const adim = adimlar[sira];

  function git(i: number) {
    if (i < 0 || i >= adimlar.length) return;
    setSira(i);
    setBitti(false);
  }

  async function videoBitti() {
    if (!adim?.video) return;
    setBitti(true);
    try {
      await apiSend(`${EGITIM_UC}/${adim.adim_kodu}/izlendi`, "POST", {});
      await mutate();
    } catch {
      // Isaret yazilamazsa video yine izlendi; sonraki izlemede yeniden denenir.
    }
  }

  function simdiYap() {
    const rota = adim ? KURULUM_HEDEFLERI[adim.adim_kodu]?.rota : undefined;
    onKapat();
    if (rota) router.push(rota);
  }

  return (
    <Modal
      acik={acik}
      onKapat={onKapat}
      baslik={t("egitimVideolariBaslik")}
      genislikSinifi="max-w-4xl"
      eylemler={
        <>
          <Dugme
            tur={bitti ? TUR_BIRINCIL : TUR_IKINCIL}
            data-test="egitim-simdi-yap"
            data-vurgulu={bitti ? EVET : HAYIR}
            onClick={simdiYap}
            disabled={!adim || !KURULUM_HEDEFLERI[adim.adim_kodu]?.rota}
          >
            {t("egitimSimdiYap")}
          </Dugme>
          <Dugme tur="sessiz" onClick={onKapat}>
            {t("ortakKapat")}
          </Dugme>
        </>
      }
    >
      <div
        className="space-y-4"
        onKeyDown={(e) => {
          if (e.key === "ArrowRight") git(sira + 1);
          if (e.key === "ArrowLeft") git(sira - 1);
        }}
      >
        {adim?.video ? (
          <YoutubeOynatici
            key={adim.adim_kodu}
            videoId={adim.video.youtube_id}
            baslik={adim.video.baslik}
            onBitti={() => void videoBitti()}
          />
        ) : adim ? (
          <div
            data-test="egitim-yakinda"
            className="flex aspect-video w-full items-center justify-center rounded-lg p-6 text-center"
            style={{ background: "var(--yz-surface-sunken)", color: "var(--yz-text-2)" }}
          >
            {t("egitimYakinda")}
          </div>
        ) : null}

        {adim && (
          <div>
            <p className="font-semibold" style={{ color: "var(--yz-text)" }}>
              {sira + 1}. {adim.video?.baslik ?? t(adimEtiketi(adim.adim_kodu))}
            </p>
            {adim.video?.aciklama && (
              <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
                {adim.video.aciklama}
              </p>
            )}
          </div>
        )}

        <div className="flex items-center gap-2">
          <Dugme
            tur="sessiz"
            boy="kucuk"
            aria-label={t("egitimOnceki")}
            data-test="egitim-geri"
            disabled={sira <= 0}
            onClick={() => git(sira - 1)}
          >
            ‹
          </Dugme>
          <ol className="flex flex-1 flex-wrap gap-1" aria-label={t("egitimAdimlar")}>
            {adimlar.map((a, i) => (
              <li key={a.adim_kodu}>
                <button
                  type="button"
                  data-test="egitim-adim"
                  aria-current={i === sira ? ADIM : undefined}
                  aria-label={t("egitimAdimEtiketi", {
                    n: i + 1,
                    ad: a.video?.baslik ?? t(adimEtiketi(a.adim_kodu)),
                  })}
                  onClick={() => git(i)}
                  className="inline-flex h-9 min-w-9 items-center justify-center rounded-full border px-2 text-sm font-semibold"
                  style={{
                    borderColor: i === sira ? "var(--yz-accent)" : "var(--yz-border)",
                    background: i === sira ? "var(--yz-accent)" : SAYDAM,
                    color: i === sira ? ACIK_RENK : a.video ? "var(--yz-text)" : "var(--yz-text-2)",
                  }}
                >
                  {a.izlendi ? "✓" : i + 1}
                </button>
              </li>
            ))}
          </ol>
          <Dugme
            tur="sessiz"
            boy="kucuk"
            aria-label={t("egitimSonraki")}
            data-test="egitim-ileri"
            disabled={sira >= adimlar.length - 1}
            onClick={() => git(sira + 1)}
          >
            ›
          </Dugme>
        </div>
      </div>
    </Modal>
  );
}

/** Ana sayfa karti. Kurulum tamamlaninca KUCULUR ama kaybolmaz (devir). */
export function KurulumVideolariKarti() {
  const t = useT();
  const { data } = useEgitimVideolari();
  const [acik, setAcik] = useState(false);
  // Hic video girilmemisse kart cizilmez: "0/0" bir vaat degil gurultudur.
  if (!data || data.toplam === 0) return null;
  const kucuk = data.kurulum_tamam;
  return (
    <>
      <Kart>
        <div
          data-test="kurulum-videolari-karti"
          data-kucuk={kucuk ? EVET : HAYIR}
          className={`flex flex-wrap items-center justify-between gap-3 ${kucuk ? "" : "py-1"}`}
        >
          <div className="min-w-0">
            <p className="font-semibold" style={{ color: "var(--yz-text)" }}>
              {t("egitimVideolariBaslik")}
            </p>
            <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
              {t("egitimIlerleme", { izlenen: data.izlenen, toplam: data.toplam })}
            </p>
            {!kucuk && (
              <div
                className="mt-2 h-2 w-full max-w-xs overflow-hidden rounded-full"
                style={{ background: "var(--yz-border)" }}
                role="progressbar"
                aria-valuemin={0}
                aria-valuemax={data.toplam}
                aria-valuenow={data.izlenen}
                aria-label={t("egitimVideolariBaslik")}
              >
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${Math.round((data.izlenen / data.toplam) * 100)}%`,
                    background: "var(--yz-accent)",
                  }}
                />
              </div>
            )}
          </div>
          <Dugme
            tur={kucuk ? TUR_SESSIZ : TUR_BIRINCIL}
            boy={kucuk ? BOY_KUCUK : undefined}
            data-test="kurulum-videolari-ac"
            onClick={() => setAcik(true)}
          >
            {t("egitimVideolariIzle")}
          </Dugme>
        </div>
      </Kart>
      {acik && <KurulumVideolariPenceresi acik onKapat={() => setAcik(false)} />}
    </>
  );
}
