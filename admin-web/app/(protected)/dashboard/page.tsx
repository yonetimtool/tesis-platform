"use client";

// (P132.3) PANO — mobil ana ekranin bilgi hiyerarsisi, GENIS EKRAN duzeni.
//
// MOBIL SIRA: karsilama → hizli ozet (istatistik) → vardiya/tur durumu →
// son hareketler → kamera seridi. Web'de ayni sira KORUNUR ama tek sutun
// yerine iki sutuna acilir: solda zaman cizgisi (turlar + alarmlar), sagda
// baglam (konum haritasi). Kamera seridi en altta, tam genislikte.
//
// NEDEN AYNI SIRA: iki urun arasinda gecen bir yonetici, aradigi seyi ayni
// SIRADA bulmali. Geniş ekran icin yeniden siralamak, "web baska bir urun"
// hissini uretirdi — sikayetin kendisi buydu.
//
// FRAMER-MOTION KALDIRILDI (P132.5): pano acilirken kartlarin sirayla
// suzulmesi 40 KB'lik bir kutuphane bedeliyle geliyordu. Ayni etki CSS
// animasyonuyla (`animate-yuksel`, gecikme degiskeni) 0 KB'a alindi;
// `prefers-reduced-motion` globals.css'te zaten saygi goruyor.
import useSWR from "swr";

import { KameraSeridi } from "@/components/KameraSeridi";
import { SiteHarita } from "@/components/SiteHarita";
import {
  BolumBasligi,
  BosDurum,
  Chip,
  HareketSatiri,
  HataDurumu,
  IstatistikKarti,
  Kart,
  SayfaBasligi,
  Yukleniyor,
  type Vurgu,
} from "@/components/tasarim";
import { BILDIRIM_TIP, TUR_DURUM, enumAdi } from "@/lib/enum-adlari";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type {
  AktifTur,
  DashboardLive,
  Kamera,
  KameraListResponse,
  TenantSettings,
} from "@/lib/types";

// Durum -> vurgu KIMLIGI (renk degil): renk token'da, anlam burada.
const DURUM_VURGU: Record<string, Vurgu> = {
  bekliyor: "orange",
  tamamlandi: "green",
  kacirildi: "red",
};

function Ikon({ d }: { d: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-6 w-6"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={d} />
    </svg>
  );
}

const YOL = {
  tur: "M4 18l5-7 5 4 6-9",
  onay: "M20 6L9 17l-5-5",
  saat: "M12 7.5V12l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
  zil: "M6 9a6 6 0 1 1 12 0c0 4 1.5 5 2 6H4c.5-1 2-2 2-6ZM10 20a2 2 0 0 0 4 0",
};

export default function DashboardPage() {
  const t = useT();
  const { data, error, isLoading } = useSWR<DashboardLive>(
    "/api/dashboard/live",
    jsonFetcher,
    { refreshInterval: 15000, revalidateOnFocus: true },
  );
  // (P132.5) N+1 YOK: pano acilisinda UC istek atilir ve ucu de AYRI
  // veridir (canli tur durumu, tesis konumu, kameralar). Kamera ve konum
  // 15 saniyede bir YENILENMEZ — konum degismez, kamera listesi nadiren
  // degisir; yalnizca `dashboard/live` doner. Ayni SWR anahtarlari
  // ilgili sayfalarda da kullanildigi icin gezinirken yeniden istenmez.
  const { data: tesis } = useSWR<TenantSettings>("/api/tenant/settings", jsonFetcher, {
    revalidateOnFocus: false,
  });
  const { data: kameraYanit } = useSWR<KameraListResponse>(
    "/api/cameras?limit=50&offset=0",
    jsonFetcher,
    { revalidateOnFocus: false },
  );

  const turlar = data?.aktif_turlar ?? [];
  const tamamlanan = turlar.filter((x) => x.durum === "tamamlandi").length;
  const bekleyen = turlar.filter((x) => x.durum === "bekliyor").length;
  const kacirilan = turlar.filter((x) => x.durum === "kacirildi").length;
  const alarmlar = data?.son_alarmlar ?? [];
  const kameralar: Kamera[] = kameraYanit?.items ?? [];

  return (
    <div className="space-y-bolum">
      <SayfaBasligi
        baslik={t("kabukCanliPanel")}
        aciklama={
          data ? t("panelGuncellendiTam", { zaman: formatDateTime(data.generated_at) }) : undefined
        }
      />

      {/* Hata KUTUSU canli bolgedir: pano 15 sn'de bir yenilenir ve kutu
          SONRADAN gelir; `role="alert"` HataDurumu icinde. */}
      {error ? <HataDurumu mesaj={error.message} /> : null}

      {/* --- HIZLI OZET: dort istatistik karti ------------------------- */}
      {isLoading && !data ? (
        <div className="grid grid-cols-1 gap-izgara min-[420px]:grid-cols-2 lg:grid-cols-4">
          {[0, 1, 2, 3].map((i) => (
            <Yukleniyor key={i} satir={2} />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-izgara min-[420px]:grid-cols-2 lg:grid-cols-4">
          <IstatistikKarti
            vurgu="blue"
            ikon={<Ikon d={YOL.tur} />}
            deger={String(turlar.length)}
            etiket={t("panelBugunkuTurlar")}
            href="/patrol-plans"
          />
          <IstatistikKarti
            vurgu="green"
            ikon={<Ikon d={YOL.onay} />}
            deger={String(tamamlanan)}
            etiket={t("panelTamamlanan")}
            href="/reports/patrols"
          />
          <IstatistikKarti
            vurgu="orange"
            ikon={<Ikon d={YOL.saat} />}
            deger={String(bekleyen)}
            etiket={t("panelBekleyen")}
            href="/patrol-plans"
          />
          <IstatistikKarti
            vurgu={alarmlar.length ? "red" : "purple"}
            ikon={<Ikon d={YOL.zil} />}
            deger={String(alarmlar.length)}
            etiket={t("panelAktifAlarm")}
            href="/notifications"
          />
        </div>
      )}

      {/* --- IKI SUTUN: solda zaman cizgisi, sagda baglam -------------- */}
      <div className="grid gap-bolum lg:grid-cols-3">
        <div className="space-y-bolum lg:col-span-2">
          {/* Vardiya/tur durumu */}
          <section>
            <BolumBasligi baslik={t("panelBugunkuTurlar")} href="/patrol-plans" />
            {isLoading && !data ? (
              <Yukleniyor satir={4} />
            ) : turlar.length === 0 ? (
              <BosDurum baslik={t("panelTurYokBugun")} />
            ) : (
              <Kart>
                <ul>
                  {turlar.map((tur: AktifTur) => (
                    <HareketSatiri
                      key={tur.patrol_window_id}
                      vurgu={DURUM_VURGU[tur.durum] ?? "blue"}
                      ikon={<Ikon d={YOL.tur} />}
                      baslik={tur.patrol_plan_ad ?? tur.patrol_plan_id.slice(0, 8)}
                      alt={`${formatDateTime(tur.pencere_baslangic)} – ${formatDateTime(tur.pencere_bitis)}`}
                      sag={
                        <span className="flex items-center gap-2">
                          <span className="tabular-nums">
                            {tur.okutulan_checkpoint_sayisi ?? 0}/
                            {tur.beklenen_checkpoint_sayisi ?? 0}
                          </span>
                          <Chip vurgu={DURUM_VURGU[tur.durum] ?? "blue"}>
                            {enumAdi(t, TUR_DURUM, tur.durum)}
                          </Chip>
                        </span>
                      }
                    />
                  ))}
                </ul>
              </Kart>
            )}
          </section>

          {/* Son hareketler (alarmlar) */}
          <section>
            <BolumBasligi baslik={t("panelSonAlarmlar")} href="/notifications" />
            {isLoading && !data ? (
              <Yukleniyor satir={3} />
            ) : alarmlar.length === 0 ? (
              <BosDurum baslik={t("panelAlarmYok")} />
            ) : (
              <Kart>
                <ul>
                  {alarmlar.map((a, i) => (
                    <HareketSatiri
                      key={`${a.tip}-${a.olusma_zamani}-${i}`}
                      vurgu="red"
                      ikon={<Ikon d={YOL.zil} />}
                      baslik={a.mesaj}
                      alt={enumAdi(t, BILDIRIM_TIP, a.tip)}
                      sag={formatDateTime(a.olusma_zamani)}
                    />
                  ))}
                </ul>
              </Kart>
            )}
          </section>
        </div>

        {/* Baglam sutunu: tesis konumu */}
        <div className="space-y-bolum">
          <SiteHarita
            lat={tesis?.konum_lat}
            lon={tesis?.konum_lon}
            ad={tesis?.konum_ad ?? tesis?.ad}
          />
        </div>
      </div>

      {/* --- KAMERA SERIDI: tam genislik, en altta -------------------- */}
      <KameraSeridi kameralar={kameralar} />
    </div>
  );
}
