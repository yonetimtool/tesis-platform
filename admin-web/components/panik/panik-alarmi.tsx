"use client";

/**
 * (P240 §1) GELEN ALARM — TAM EKRAN, KAPATILAMAZ.
 *
 * =========================================================================
 * NEDEN KAPATILAMAZ
 * =========================================================================
 * Istek: "alicida kapatilamayan ekran, 'gordum / gidiyorum' dugmesiyle".
 * Kapatilabilir bir bildirim, yogun bir ekranda REFLEKSLE kapatilir ve
 * alarm hic okunmadan kaybolur. Ekran ancak bir KARAR verilince gider.
 *
 * =========================================================================
 * (P249 §1b) IKI DENEYIM — mobille AYNI
 * =========================================================================
 * * TOPLU UYARI (deprem/yangin/gaz/tahliye): buyuk harfle kategori, ADIM
 *   ADIM talimat, yer ve saat; karar GUVENDEYIM / YARDIMA IHTIYACIM VAR.
 *   "Gidiyorum" burada anlamsiz.
 * * YARDIM CAGRISI (saglik/guvenlik tehdidi/diger): kim, nerede, telefon,
 *   kisa talimat; Gidiyorum / Gordum.
 * Baslik ve talimat SUNUCUDAN gelir (istegin dilinde, tek kaynak
 * `panik_talimat.py`). OLCULEN KUSUR (P243): bu katman sabit "ACIL DURUM
 * CAGRISI" ciziyordu, kategoriyi hic okumuyordu.
 *
 * =========================================================================
 * YOKLAMA (polling) — WEBSOCKET DEGIL
 * =========================================================================
 * Panelde canli kanal altyapisi YOK. On saniyelik yoklama, bir alarmi en
 * kotu ihtimalle 10 sn geç gosterir. Mobilde push ANINDA ulasiyor — panel
 * ikinci yuzeydir.
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
  kategori: string | null;
  toplu: boolean;
  baslik: string;
  talimat: string[];
  benim_yanitim: string | null;
  olusturan_ad: string | null;
  olusturan_telefon: string | null;
  daire_no: string | null;
  blok: string | null;
  checkpoint_ad: string | null;
  gps_lat: number | null;
  gps_lng: number | null;
  aciklama: string | null;
  son_24s_yanlis_alarm: number;
  gonderildi_at: string | null;
  created_at: string;
  tatbikat?: boolean;
};

const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;

function saat(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

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
  const baslik = alarm.baslik || t("panikGelenAlarm");

  return (
    <div
      data-test="panik-tam-ekran"
      role="alertdialog"
      aria-modal="true"
      aria-label={baslik}
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "var(--yz-danger-edge)" }}
    >
      <div
        className="max-h-full w-full max-w-lg overflow-y-auto rounded-lg p-6"
        style={{ background: "var(--yz-surface-1)" }}
      >
        {alarm.tatbikat && (
          // (P249 §2) TATBIKAT SERIDI — gercek alarmla karistirilamasin.
          <p
            data-test="panik-tatbikat-serit"
            className="mb-3 rounded p-2 text-center font-bold"
            style={{ background: "#FFD600", color: "#000" }}
          >
            {t("panikTatbikatSerit")}
          </p>
        )}
        <p
          data-test="panik-baslik"
          className="text-center font-bold"
          style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-danger-ink)" }}
        >
          {baslik}
        </p>

        {alarm.toplu ? (
          <div data-test="panik-toplu">
            <p className="mt-2 text-center" style={{ fontSize: "var(--yz-fs-body)" }}>
              {[yer, saat(alarm.gonderildi_at ?? alarm.created_at)
                ? t("panikAlarmSaati", { saat: saat(alarm.gonderildi_at ?? alarm.created_at) })
                : ""]
                .filter(Boolean)
                .join(" · ")}
            </p>
            <p className="mt-4 font-semibold" style={{ fontSize: "var(--yz-fs-h2)" }}>
              {t("panikTalimatBaslik")}
            </p>
            <ol className="mt-2 list-decimal space-y-2 ps-6" style={{ fontSize: "var(--yz-fs-body)" }}>
              {(alarm.talimat ?? []).map((adim, i) => (
                <li key={i} data-test={`panik-talimat-${i}`}>
                  {adim}
                </li>
              ))}
            </ol>
            {alarm.benim_yanitim && (
              <p className="mt-3 text-center font-semibold" data-test="panik-benim-yanitim">
                {alarm.benim_yanitim === "guvende" ? t("panikYanitGuvende") : t("panikYanitYardim")}
              </p>
            )}
            <div className="mt-4 flex flex-col gap-2">
              <Dugme
                type="button"
                tur={BIRINCIL}
                tamGenislik
                data-test="panik-guvendeyim"
                onClick={() => void isaretle("guvendeyim")}
              >
                {t("panikGuvendeyim")}
              </Dugme>
              <Dugme
                type="button"
                tur={IKINCIL}
                tamGenislik
                data-test="panik-yardim"
                onClick={() => void isaretle("yardim")}
              >
                {t("panikYardimIstiyorum")}
              </Dugme>
            </div>
          </div>
        ) : (
          <div className="text-center" data-test="panik-yardim-cagrisi">
            <p className="mt-2" data-test="panik-alarm-kim" style={{ fontSize: "var(--yz-fs-h2)" }}>
              {alarm.olusturan_ad ?? ""}
            </p>
            {yer && (
              <p data-test="panik-alarm-yer" style={{ fontSize: "var(--yz-fs-body)" }}>
                {yer}
              </p>
            )}
            {alarm.talimat?.[0] && (
              <p className="mt-2" data-test="panik-talimat-0">
                {alarm.talimat[0]}
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
              // (P249 §1b) SUNUCU yalniz guvenlik/yonetime ve yalniz
              // yardim cagrisinda doldurur.
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
        )}
      </div>
    </div>
  );
}
