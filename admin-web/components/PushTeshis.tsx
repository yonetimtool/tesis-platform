"use client";

/**
 * (P191 §2) PUSH TESHISI — "bildirim gelmedi" sorusunun panel yuzeyi.
 *
 * OLCULEN KUSUR: altyapi P181/P183'te yazildi ama UCTAN UCA calistigi HIC
 * GORULMEDI. Bildirim gelmediginde bakilacak bir yer yoktu; zincirin alti
 * halkasindan (jeton, cihaz kaydi, tetikleme, saglayici yaniti, tercih,
 * servis hesabi) hicbiri disaridan gorunmuyordu.
 *
 * BURASI CEVAP VERIR ve cevabi EYLEME baglar:
 *   * saglayici `noop` -> hicbir sey gonderilmiyor (sunucu ayari),
 *   * kimlik eksik     -> FCM servis hesabi yok (dosya yolu yaziyor),
 *   * cihaz 0          -> kimse uygulamaya girmemis/izin vermemis,
 *   * tercih kapali    -> kullanici mobil bildirimi kapatmis,
 *   * son denemeler    -> kime, ne zaman, sonuc ne.
 *
 * "Kendime test gonder" dugmesi zinciri DENEYEREK olcer: yonetici
 * "calisiyor mu?" sorusunu tahminle degil kaniti gorerek cevaplar.
 */
import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Rozet,
  VeriTablosu,
  type Kolon,
  type RozetDurumu,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

const UC = "/api/push/teshis?limit=50";
const UC_TEST = "/api/push/test";
const UC_TEMIZLE = "/api/push/cihaz-temizle";
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SAGLAYICI_NOOP = "noop";
const ROZET_OLUMLU = "olumlu" as const;
const ROZET_UYARI = "uyari" as const;
const ROZET_KRITIK = "kritik" as const;
const ROZET_NOTR = "notr" as const;
const TUR_IKINCIL = "ikincil" as const;

type Deneme = {
  id: string;
  kimlik: string;
  user_id: string | null;
  ad: string | null;
  rol: string | null;
  token_son6: string | null;
  platform: string | null;
  saglayici: string;
  durum: string;
  hata_kodu: string | null;
  created_at: string;
};

type Teshis = {
  saglayici: string;
  yapilandirildi: boolean;
  cihaz_aktif: number;
  cihaz_kullanici: number;
  bildirim_kapali: number;
  ozet_24s: Record<string, number>;
  denemeler: Deneme[];
};

/** Sunucu durum kodu -> (metin anahtari, rozet tonu). */
const DURUM_HARITA: Record<string, [SozlukAnahtari, RozetDurumu]> = {
  gonderildi: ["pushDurumGonderildi", ROZET_OLUMLU],
  gecersiz_token: ["pushDurumGecersizToken", ROZET_UYARI],
  basarisiz: ["pushDurumBasarisiz", ROZET_KRITIK],
  noop: ["pushDurumNoop", ROZET_UYARI],
  yapilandirilmadi: ["pushDurumYapilandirilmadi", ROZET_KRITIK],
  hedef_yok: ["pushDurumHedefYok", ROZET_UYARI],
};

export function PushTeshis() {
  const t = useT();
  const toast = useToast();
  const [bekliyor, setBekliyor] = useState(false);
  const { data, error, isLoading, mutate } = useSWR<Teshis>(UC, jsonFetcher);

  function durumEtiketi(durum: string): [string, RozetDurumu] {
    const kayit = DURUM_HARITA[durum];
    // BILINMEYEN DURUM HAM GOSTERILIR: sessizce "bilinmiyor" yazmak, yeni
    // bir sonuc kodunu gorunmez kilardi.
    return kayit ? [t(kayit[0]), kayit[1]] : [durum, ROZET_NOTR];
  }

  /**
   * (P191-ek §1) GECERSIZ JETONLARI TEMIZLE.
   *
   * Sunucu FCM `validate_only` ile dogrular: hicbir telefon CALMAZ. Bu bir
   * bakim aracidir; her tiklamada tesisteki herkese bildirim gitmesi kabul
   * edilemezdi.
   */
  async function temizle() {
    setBekliyor(true);
    try {
      const d = (await apiSend(UC_TEMIZLE, "POST", {})) as {
        denenen?: number;
        budanan?: number;
        desteklenmiyor?: boolean;
      };
      if (d.desteklenmiyor) {
        // "Bakamadim" ile "hepsi saglam" AYNI SEY DEGIL — basari toast'u
        // gostermek, olu jetonlari saglam ilan etmekti.
        toast.error(t("pushTemizlikDesteklenmiyor"));
      } else {
        toast.success(
          t("pushTemizlikSonuc", {
            denenen: String(d.denenen ?? 0),
            budanan: String(d.budanan ?? 0),
          }),
        );
      }
      await mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setBekliyor(false);
    }
  }

  async function testGonder() {
    setBekliyor(true);
    try {
      const d = (await apiSend(UC_TEST, "POST", {})) as {
        durum?: string;
        cihaz?: number;
        gonderildi?: number;
      };
      toast.success(
        t("pushTeshisTestSonuc", {
          durum: durumEtiketi(d.durum ?? "")[0],
          cihaz: String(d.cihaz ?? 0),
          gonderildi: String(d.gonderildi ?? 0),
        }),
      );
      await mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setBekliyor(false);
    }
  }

  const kolonlar = useMemo<Kolon<Deneme>[]>(
    () => [
      {
        id: "kimlik",
        baslik: t("pushTeshisOlay"),
        kartRolu: "baslik",
        hucre: (d) => <span className="font-mono">{d.kimlik}</span>,
      },
      {
        id: "kime",
        baslik: t("pushTeshisKime"),
        kartRolu: "ozet",
        hucre: (d) => d.ad ?? "—",
      },
      {
        id: "cihaz",
        baslik: t("pushTeshisCihazKisa"),
        darEkrandaGizle: true,
        hucre: (d) => (
          <span className="font-mono">{d.token_son6 ? `…${d.token_son6}` : "—"}</span>
        ),
      },
      {
        id: "sonuc",
        baslik: t("pushTeshisSonuc"),
        kartRolu: "rozet",
        hucre: (d) => {
          const [etiket, ton] = durumEtiketi(d.durum);
          return (
            <span className="inline-flex items-center gap-2">
              <Rozet durum={ton}>{etiket}</Rozet>
              {d.hata_kodu ? (
                <span
                  className="font-mono"
                  style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                >
                  {d.hata_kodu}
                </span>
              ) : null}
            </span>
          );
        },
      },
      {
        id: "zaman",
        baslik: t("ortakTarih"),
        kartRolu: "ozet",
        hucre: (d) => formatDateTime(d.created_at),
      },
    ],
    // `durumEtiketi` yalniz `t`ye bagli; bagimlilik listesi onu izler.
    [t], // eslint-disable-line react-hooks/exhaustive-deps
  );

  if (error) {
    return (
      <Kart>
        <HataDurumu mesaj={t("pushTeshisYuklenemedi")} onTekrar={() => void mutate()} />
      </Kart>
    );
  }
  if (isLoading && !data) {
    return (
      <Kart>
        <IskeletMetin />
      </Kart>
    );
  }
  if (!data) return null;

  const noop = data.saglayici === SAGLAYICI_NOOP;
  return (
    <Kart>
      <div className="space-y-4">
        <div>
          <h2 style={{ fontSize: "var(--yz-fs-h2)", color: "var(--yz-text)" }}>
            {t("pushTeshisBaslik")}
          </h2>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("pushTeshisAciklama")}
          </p>
        </div>

        {/* EN ONEMLI IKI ARIZA EN USTTE ve EYLEMIYLE birlikte: bunlar
            varken asagidaki sayilara bakmanin anlami yok. */}
        {noop || !data.yapilandirildi ? (
          <p
            role="alert"
            className="border px-3 py-2"
            style={{
              borderColor: "var(--yz-danger-edge)",
              borderWidth: "var(--yz-border-w)",
              borderRadius: "var(--yz-radius-chip)",
              color: "var(--yz-danger-ink)",
              fontSize: "var(--yz-fs-sm)",
            }}
          >
            {noop ? t("pushTeshisNoopUyari") : t("pushTeshisKimlikUyari")}
          </p>
        ) : null}

        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {(
            [
              [t("pushTeshisSaglayici"), data.saglayici],
              [
                t("pushTeshisYapilandirma"),
                data.yapilandirildi
                  ? t("pushTeshisYapilandirmaTamam")
                  : t("pushTeshisYapilandirmaEksik"),
              ],
              [t("pushTeshisCihaz"), String(data.cihaz_aktif)],
              [t("pushTeshisKapali"), String(data.bildirim_kapali)],
            ] as [string, string][]
          ).map(([etiket, deger]) => (
            <div key={etiket}>
              <dt style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {etiket}
              </dt>
              <dd style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                {deger}
              </dd>
            </div>
          ))}
        </dl>

        <div className="flex flex-wrap gap-2">
          <Dugme
            boy="kucuk"
            tur={TUR_IKINCIL}
            disabled={bekliyor}
            onClick={() => void testGonder()}
            data-test="push-test-gonder"
          >
            {t("pushTeshisTestGonder")}
          </Dugme>
          <Dugme
            boy="kucuk"
            tur={TUR_IKINCIL}
            disabled={bekliyor || data.cihaz_aktif === 0}
            onClick={() => void temizle()}
            data-test="push-temizle"
          >
            {t("pushTemizle")}
          </Dugme>
        </div>

        {/* ORTAK TABLO ILKELI (P138): ham `<table>` yazmak, dar ekran
            davranisini ve bos/hata durumlarini yeniden icat etmek olurdu —
            depo bunu `tasarim-token` kilidiyle engelliyor. */}
        <VeriTablosu<Deneme>
          kolonlar={kolonlar}
          // SAVUNMA: uc alani hic dondurmediyse (eski surum / kismi yanit)
          // tablo bos cizilir; `undefined` gecirmek bileseni dusururdu.
          satirlar={data.denemeler ?? []}
          satirId={(d) => d.id}
          bosBaslik={t("pushTeshisBosBaslik")}
          bosAciklama={t("pushTeshisBosAciklama")}
        />
      </div>
    </Kart>
  );
}
