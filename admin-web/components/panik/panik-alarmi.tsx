"use client";

/**
 * (P240 §1) GELEN ALARM — TAM EKRAN, KAPATILAMAZ.
 *
 * =========================================================================
 * NEDEN KAPATILAMAZ
 * =========================================================================
 * Istek: "alicida kapatilamayan ekran, 'gordum / gidiyorum' dugmesiyle".
 * Kapatilabilir bir bildirim, yogun bir ekranda REFLEKSLE kapatilir ve
 * alarm hic okunmadan kaybolur. Ekran ancak bir KARAR verilince gider:
 * "gordum" ya da "gidiyorum". Ikisi de sunucuya yazilir; takip olcumu
 * (kim gordu, kac saniyede mudahale edildi) tam olarak bunlardan uretilir.
 *
 * "Gidiyorum" GORMEYI DE KAPSAR (sunucu ikisini birlikte yazar): acil
 * durumda iki ayri dokunus istemek, olcum ugruna zaman harcamaktir.
 *
 * =========================================================================
 * YOKLAMA (polling) — WEBSOCKET DEGIL
 * =========================================================================
 * Panelde canli kanal altyapisi YOK. On saniyelik yoklama, bir alarmi en
 * kotu ihtimalle 10 sn geç gosterir; WebSocket getirmek bu tur icin yeni
 * bir altyapi (baglanti yonetimi, yeniden baglanma, olcek) demekti.
 * Mobilde push zaten ANINDA ulasiyor — panel ikinci yuzeydir.
 */
import useSWR from "swr";

import { Dugme } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

type Alarm = {
  id: string;
  tip: string;
  durum: string;
  olusturan_ad: string | null;
  olusturan_telefon: string | null;
  daire_no: string | null;
  blok: string | null;
  checkpoint_ad: string | null;
  gps_lat: number | null;
  gps_lng: number | null;
  aciklama: string | null;
  son_24s_yanlis_alarm: number;
};

const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;

export function PanikAlarmi() {
  const t = useT();
  const { data, mutate } = useSWR<Alarm[]>("/api/panik/aktif", jsonFetcher, {
    refreshInterval: 10_000,
  });
  const alarm = data?.[0];
  if (!alarm) return null;

  async function isaretle(eylem: string) {
    if (!alarm) return;
    await apiSend(`/api/panik/${alarm.id}/${eylem}`, "POST", {});
    await mutate();
  }

  const yer =
    alarm.daire_no
      ? `${alarm.blok ?? ""} ${alarm.daire_no}`.trim()
      : alarm.checkpoint_ad ??
        (alarm.gps_lat !== null ? `${alarm.gps_lat}, ${alarm.gps_lng}` : "");

  return (
    <div
      data-test="panik-tam-ekran"
      role="alertdialog"
      aria-modal="true"
      aria-label={t("panikGelenAlarm")}
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "var(--yz-danger-edge)" }}
    >
      <div
        className="w-full max-w-md rounded-lg p-6 text-center"
        style={{ background: "var(--yz-surface-1)" }}
      >
        <p style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-danger-ink)" }}>
          {t("panikGelenAlarm")}
        </p>
        <p className="mt-2" data-test="panik-alarm-kim" style={{ fontSize: "var(--yz-fs-h2)" }}>
          {alarm.olusturan_ad ?? ""}
        </p>
        {yer && (
          <p data-test="panik-alarm-yer" style={{ fontSize: "var(--yz-fs-body)" }}>
            {yer}
          </p>
        )}
        {alarm.aciklama && <p className="mt-1">{alarm.aciklama}</p>}
        {alarm.olusturan_telefon && (
          // ACIL DURUMDA NUMARA GOSTERILIR ve bu, gunluk iletisimdeki
          // riza kapisindan AYRI bir karardir (bkz. routers/panik.py).
          <a
            href={`tel:${alarm.olusturan_telefon}`}
            data-test="panik-alarm-telefon"
            className="odak-ic mt-2 inline-block underline"
            style={{ color: "var(--yz-accent-ink)" }}
          >
            {alarm.olusturan_telefon}
          </a>
        )}
        {alarm.son_24s_yanlis_alarm > 0 && (
          // BAGLAM, ENGEL DEGIL: alarmi kucumsemek icin degil, gidenin
          // ne bekleyecegini bilmesi icin.
          <p
            className="mt-2"
            data-test="panik-alarm-yanlis-sayaci"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("panikYanlisAlarmSayaci", { n: alarm.son_24s_yanlis_alarm })}
          </p>
        )}
        <div className="mt-4 flex flex-col gap-2">
          <Dugme
            type="button"
            tur={BIRINCIL}
            tamGenislik
            data-test="panik-mudahale"
            onClick={() => void isaretle("mudahale")}
          >
            {t("panikGidiyorum")}
          </Dugme>
          <Dugme
            type="button"
            tur={IKINCIL}
            tamGenislik
            data-test="panik-gordum"
            onClick={() => void isaretle("gordum")}
          >
            {t("panikGordum")}
          </Dugme>
        </div>
      </div>
    </div>
  );
}
