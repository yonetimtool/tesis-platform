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
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { KopyaKod } from "@/components/KopyaKod";
import { PageHeader, btnGhost } from "@/components/form";
import { Tablo, TabloBasligi, Td, Th, Tr } from "@/components/tablo";
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

/** Davetin panel durumu — TEK yerde hesaplanir (renk + metin birlikte). */
function durumBilgisi(d: DavetSatiri): { anahtar: string; renk: string } {
  if (d.used_at) return { anahtar: "davetDurumKullanildi", renk: "bg-emerald-100 text-emerald-800" };
  if (d.son_durum === "basarisiz")
    return { anahtar: "davetDurumGitmedi", renk: "bg-red-100 text-red-800" };
  if (d.son_durum === "gonderildi" || d.son_durum === "iletildi")
    return { anahtar: "davetDurumGonderildi", renk: "bg-sky-100 text-sky-800" };
  return { anahtar: "davetDurumBekliyor", renk: "bg-amber-100 text-amber-800" };
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

  return (
    <div className="space-y-4">
      <PageHeader title={t("davetlerBaslik")} subtitle={t("davetlerAciklama")} />

      {/* Saglayici yokken ELLE iletim: tesis kodunu kopyala. */}
      {data?.tesis_kodu ? (
        <div className="flex flex-wrap items-center gap-2 rounded-kart border kart-kenar bg-yuzey-card p-3 text-sm">
          <span className="text-metin-muted">{t("davetlerTesisKoduIpucu")}</span>
          <KopyaKod deger={data.tesis_kodu} etiket={t("tesisKayitKodu")} />
        </div>
      ) : null}

      {error ? <p className="text-sm text-vurguInk-red">{t("ortakHataOlustu")}</p> : null}

      {isLoading ? (
        <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>
      ) : items.length === 0 ? (
        <EmptyState title={t("davetlerBos")} />
      ) : (
        <div className="overflow-hidden rounded-kart border kart-kenar bg-white">
          <div className="odak-ic overflow-x-auto" tabIndex={0}>
            <Tablo>
              <TabloBasligi>
                <Th>{t("tesisAdSoyad")}</Th>
                <Th>{t("davetTelefon")}</Th>
                <Th>{t("davetDurum")}</Th>
                <Th>{t("davetSonGonderim")}</Th>
                <Th />
              </TabloBasligi>
              <tbody>
                {items.map((d) => {
                  const durum = durumBilgisi(d);
                  return (
                    <Tr key={d.user_id}>
                      <Td>
                        <span className="font-medium">{d.ad}</span>
                        {d.daire_no ? (
                          <span className="ms-1 text-xs text-metin-muted">· {d.daire_no}</span>
                        ) : null}
                      </Td>
                      <Td className="font-mono text-xs">{d.telefon}</Td>
                      <Td>
                        <span
                          className={`rounded-full px-2 py-0.5 text-xs font-medium ${durum.renk}`}
                        >
                          {t(durum.anahtar as Parameters<typeof t>[0])}
                        </span>
                        {d.son_durum === "basarisiz" && d.son_hata ? (
                          <span className="ms-2 text-xs text-metin-muted">{d.son_hata}</span>
                        ) : null}
                      </Td>
                      <Td className="text-metin-body">
                        {d.son_gonderim_at ? formatDateTime(d.son_gonderim_at) : "—"}
                      </Td>
                      <Td hizala="end">
                        {d.used_at ? (
                          <span className="text-xs text-metin-muted">{t("davetDurumKullanildi")}</span>
                        ) : (
                          <button className={btnGhost} onClick={() => void yenidenGonder(d)}>
                            {t("davetYenidenGonder")}
                          </button>
                        )}
                      </Td>
                    </Tr>
                  );
                })}
              </tbody>
            </Tablo>
          </div>
        </div>
      )}
    </div>
  );
}
