"use client";

/**
 * (P155 §7) DAVETLER — yonetici "gitmeyen daveti" gorur ve yeniden gonderir.
 *
 * NEDEN AYRI SAYFA: web'de sakin yonetimi Excel toplu yukleme (`/ice-aktarim`)
 * ve mobil tekli ekleme ile yapiliyor; davet gonderim DURUMU ise ayri bir
 * sorudur ("kime gitti, kime gitmedi") ve tek bir yerde toplanmali. Sakin
 * eklendiginde davet OTOMATIK gider (backend); bu sayfa sonucu izler.
 *
 * SAGLAYICI YOKKEN: davet "gonderilemedi" gorunur ve yonetici TESIS KODUNU
 * kopyalayip elle iletebilir (kisi §4 yedek yoluyla kaydolur). Saglayici
 * baglaninca "yeniden gonder" ayni jetonu tazeler ve bu sefer gider.
 */
import { useMemo } from "react";
import useSWR from "swr";

import { KopyaKod } from "@/components/KopyaKod";
import {
  Dugme,
  Kart,
  Rozet,
  VeriTablosu,
  type Kolon,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend, ApiHatasi } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

interface DavetSatiri {
  user_id: string;
  ad: string;
  rol: string;
  telefon: string;
  daire_no: string | null;
  son_kanal: string | null;
  son_durum: string | null;
  son_hata: string | null;
  son_gonderim_at: string | null;
  used_at: string | null;
  son_gecerlilik: string;
}
interface DavetListesi {
  tesis_kodu: string | null;
  items: DavetSatiri[];
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const R_OLUMLU = "olumlu" as const;
const R_KRITIK = "kritik" as const;
const R_BILGI = "bilgi" as const;
const R_UYARI = "uyari" as const;

/** Davetin panel durumu — TEK yerde hesaplanir (renk + metin birlikte). */
function durumBilgisi(d: DavetSatiri): {
  anahtar: string;
  renk: typeof R_OLUMLU | typeof R_KRITIK | typeof R_BILGI | typeof R_UYARI;
} {
  if (d.used_at) return { anahtar: "davetDurumKullanildi", renk: R_OLUMLU };
  if (d.son_durum === "basarisiz") return { anahtar: "davetDurumGitmedi", renk: R_KRITIK };
  if (d.son_durum === "gonderildi" || d.son_durum === "iletildi")
    return { anahtar: "davetDurumGonderildi", renk: R_BILGI };
  return { anahtar: "davetDurumBekliyor", renk: R_UYARI };
}

export default function DavetlerSayfasi() {
  const t = useT();
  const toast = useToast();
  const { data, isLoading, error, mutate } = useSWR<DavetListesi>(
    "/api/davet",
    jsonFetcher,
  );

  async function yenidenGonder(satir: DavetSatiri) {
    try {
      await apiSend(`/api/davet/${satir.user_id}/yeniden`, "POST");
      toast.success(t("davetYenidenGonderildi"));
      await mutate();
    } catch (e) {
      toast.error(e instanceof ApiHatasi ? e.message : t("ortakHataOlustu"));
    }
  }

  const items = data?.items ?? [];

  const kolonlar: Kolon<DavetSatiri>[] = useMemo(
    () => [
      {
        id: "ad",
        baslik: t("tesisAdSoyad"),
        gizlenebilir: false,
        deger: (d) => d.ad,
        hucre: (d) => (
          <>
            <span style={{ fontWeight: 600 }}>{d.ad}</span>
            {d.daire_no ? (
              <span
                className="ms-1"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                · {d.daire_no}
              </span>
            ) : null}
          </>
        ),
      },
      {
        id: "telefon",
        baslik: t("davetTelefon"),
        hucre: (d) => (
          <span className="font-mono" style={{ fontSize: "var(--yz-fs-xs)" }}>
            {d.telefon}
          </span>
        ),
      },
      {
        id: "durum",
        baslik: t("davetDurum"),
        hucre: (d) => {
          const durum = durumBilgisi(d);
          return (
            <>
              <Rozet durum={durum.renk}>
                {t(durum.anahtar as Parameters<typeof t>[0])}
              </Rozet>
              {/* SEBEP GORUNUR KALIR: "gitmedi" tek basina yoneticiye ne
                  yapacagini soylemiyor; saglayici hatasi burada yaziyor. */}
              {d.son_durum === "basarisiz" && d.son_hata ? (
                <span
                  className="ms-2"
                  style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                >
                  {d.son_hata}
                </span>
              ) : null}
            </>
          );
        },
      },
      {
        id: "gonderim",
        baslik: t("davetSonGonderim"),
        darEkrandaGizle: true,
        hucre: (d) => (d.son_gonderim_at ? formatDateTime(d.son_gonderim_at) : "—"),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (d) =>
          d.used_at ? (
            <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {t("davetDurumKullanildi")}
            </span>
          ) : (
            <Dugme boy="kucuk" onClick={() => void yenidenGonder(d)}>
              {t("davetYenidenGonder")}
            </Dugme>
          ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-4">
      <div>
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("davetlerBaslik")}
        </h1>
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("davetlerAciklama")}
        </p>
      </div>

      {/* Saglayici yokken ELLE iletim: tesis kodunu kopyala. */}
      {data?.tesis_kodu ? (
        <Kart className="flex flex-wrap items-center gap-2 !p-3">
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("davetlerTesisKoduIpucu")}
          </span>
          <KopyaKod deger={data.tesis_kodu} etiket={t("tesisKayitKodu")} />
        </Kart>
      ) : null}

      <VeriTablosu<DavetSatiri>
        kolonlar={kolonlar}
        satirlar={items}
        satirId={(d) => d.user_id}
        hata={error ? t("ortakHataOlustu") : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("davetlerBos")}
      />
    </div>
  );
}
