"use client";

/**
 * (P240 §5c) AY TAKVIMI — ORTAK BILESEN.
 *
 * =========================================================================
 * NEDEN TASINDI
 * =========================================================================
 * Web'de gun secimi IKI FARKLI SEKILDE yapiliyordu:
 *   * vardiya ekleme modalinda ELDE cizilmis bir gun seridi (haftaya
 *     hizalanmayan, sarilabilir bir dugme yigini),
 *   * gorev formunda `<input type="datetime-local">` — tarayicinin kendi
 *     takvimi, yani her tarayicida BASKA bir goruntu.
 *
 * Kullanicinin olcumu: "gorev tarihi takvimden secilsin, mobildeki vardiya
 * plani takvimi gibi". Mobildeki `GunTakvimi` bir AY IZGARASIDIR (7 sutun,
 * haftaya hizali). Web'de ayni sey yoktu; bu dosya onu getiriyor ve iki
 * yuzey ayni goruntuye esitleniyor.
 *
 * =========================================================================
 * HAFTA PAZARTESI BASLAR (ISO-8601)
 * =========================================================================
 * P239 §4'te devriye gunleri icin ISO secilmisti (1=Pazartesi) ve
 * veritabani/Python ile tek numara kullaniliyor. Takvimin de ayni hafta
 * baslangicini kullanmasi, "pazartesi secildi" demenin iki ekranda ayni
 * sutuna denk gelmesini saglar.
 *
 * =========================================================================
 * GUN ADLARI SOZLUKTEN DEGIL, YERELDEN
 * =========================================================================
 * `Intl.DateTimeFormat(dil, { weekday: "short" })` yedi dilin gun adlarini
 * zaten biliyor. Sozluge 7x7 = 49 yeni anahtar eklemek, her birinin
 * cevrilmesi gereken ve yanlislikla Turkce kalabilecek 49 satir demekti
 * (mobildeki `gun_takvimi.dart` ile AYNI karar).
 *
 * =========================================================================
 * DOKUNMA HEDEFI 48x48 — ISTISNASIZ (P244 §10e)
 * =========================================================================
 * ONCEKI DURUM bir ACIK MADDEYDI: yukseklik 48 tutuluyor ama GENISLIK
 * dayatilmiyordu. Olcum: yedi sutunlu izgarada gun hucresi
 * 320/360/390 px ekranda 33.1 / 38.9 / 43.1 px'e dusuyor — yani 44 bile
 * tutulmuyordu. "Olculebilir iyilesme" denip birakilmisti.
 *
 * KARAR: erisilebilirlik hedefi istisna kabul etmez. Hucre artik
 * `minmax(3rem, 1fr)` — her zaman EN AZ 48x48.
 *
 * ARITMETIK: 7 x 48 + 6 x 4 (bosluk) = 360 px. Sayfa dolgusu dusuldugunde
 * 390 px ve uzeri ekranlar bunu SIGDIRIR; 320-375 arasi SIGDIRMAZ.
 *
 * DAR EKRANDA NE OLUR — YATAY KAYDIRMA, HAFTA GORUNUMU DEGIL.
 * Iki secenek vardi:
 *   * HAFTA GORUNUMUNE DUSMEK: 48'i tutar ama AYI gostermez. Takvimin
 *     tek varlik sebebi "ayin tamamini bir bakista gormek"; dar ekranda
 *     bunu kaldirmak, kucuk ekranda BASKA bir urun sunmak olurdu.
 *     Ustelik kendi ileri/geri gezinmesini ve kendi hatalarini getirir.
 *   * YATAY KAYDIRMA: ay izgarasi AYNEN kalir, yalnizca 320-375 px
 *     araliginda yana kayar. Depoda bu desen ZATEN var (`VeriTablosu`
 *     genis tabloyu boyle tasir) ve kap `tabIndex=0` + `role=region`
 *     tasir — klavye kullanicisi de kaydirabilmeli.
 * Ikincisi secildi: dokunma hedefi KOSULSUZ tutuluyor ve takvim her
 * ekranda AYNI sey olarak kaliyor.
 *
 * Bosluk dar ekranda 4px'te sabit; daraltmak 336 px'lik asgari genisligi
 * degistirmez (7x48 zaten 336) ve yalnizca hucreleri birbirine yapistirir.
 */
import { useMemo } from "react";

import { useI18n, useT } from "@/lib/i18n/kullan";

// UCLUDE/SABLONDA DIZE YAZILMAZ (depo kurali `sabit-metin`).
/** Hucre EN AZ 48px; kalan yer esit paylasilir. */
const IZGARA_SUTUNLARI = "repeat(7, minmax(3rem, 1fr))";
/** 7 x 48 + 6 x 4 bosluk = 360px. Altinda kap YATAY KAYAR. */
const IZGARA_ASGARI = "22.5rem";

/** `2026-09-17` + n gun -> ISO gun. UTC ile: yerel saat kaydirmaz. */
export function gunEkle(iso: string, n: number): string {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** ISO gun -> ISO haftagunu (1=Pazartesi ... 7=Pazar). */
export function isoHaftaGunu(iso: string): number {
  const js = new Date(`${iso}T00:00:00Z`).getUTCDay(); // 0=Pazar
  return js === 0 ? 7 : js;
}

/** Ay (`YYYY-MM`) icindeki tum gunler. */
function ayinGunleri(ay: string): string[] {
  const ilk = `${ay}-01`;
  const hedefAy = new Date(`${ilk}T00:00:00Z`).getUTCMonth();
  const out: string[] = [];
  for (let i = 0; i < 31; i++) {
    const g = gunEkle(ilk, i);
    if (new Date(`${g}T00:00:00Z`).getUTCMonth() !== hedefAy) break;
    out.push(g);
  }
  return out;
}

export function AyTakvimi({
  ay,
  secili,
  onSec,
  kanca,
  enErken,
  etiketli = true,
}: {
  /** Gosterilecek ay — `YYYY-MM`. */
  ay: string;
  /** Secili gunler (ISO). Tekil secimde tek elemanli. */
  secili: ReadonlySet<string>;
  /** Bir gune tiklandi. Cagiran tekil/coklu davranisa KENDI karar verir. */
  onSec: (gun: string) => void;
  /** `data-test` oneki: hucreler `${kanca}-gun-${iso}` olur. */
  kanca: string;
  /** Bundan ONCEKI gunler kapali (orn. gecmise son tarih verilmesin). */
  enErken?: string;
  /** Haftagunu basligi cizilsin mi (dar baglamda kapatilabilir). */
  etiketli?: boolean;
}) {
  const { dil } = useI18n();
  const t = useT();
  const gunler = useMemo(() => ayinGunleri(ay), [ay]);

  // Ayin ILK gununun haftagunu: izgaranin basina o kadar BOS hucre.
  // Hizalama olmadan "pazartesi" sutunu her ay kayar ve takvim
  // takvim gibi OKUNMAZ.
  const bosluk = gunler.length > 0 ? isoHaftaGunu(gunler[0]) - 1 : 0;

  const gunAdlari = useMemo(() => {
    const bicim = new Intl.DateTimeFormat(dil, { weekday: "short" });
    // 2026-09-14 PAZARTESI — ISO sirasi icin capa.
    return [0, 1, 2, 3, 4, 5, 6].map((i) =>
      bicim.format(new Date(Date.UTC(2026, 8, 14 + i))),
    );
  }, [dil]);

  return (
    // KAYDIRILABILIR KAP: `tabIndex=0` + `role=region` — klavye
    // kullanicisi de yatay kaydirabilmeli (WCAG 2.1.1). Ad verilmeden
    // `role=region` erisilebilirlik agacinda adsiz bir bolge birakir.
    <div
      data-test={`${kanca}-takvim`}
      className="odak-ic overflow-x-auto"
      tabIndex={0}
      role="region"
      aria-label={t("takvimBolgesi")}
    >
      <div style={{ minWidth: IZGARA_ASGARI }}>
      {etiketli && (
        <div
          className="grid gap-1"
          aria-hidden="true"
          style={{
            gridTemplateColumns: IZGARA_SUTUNLARI,
            fontSize: "var(--yz-fs-xs)",
            color: "var(--yz-text-3)",
          }}
        >
          {gunAdlari.map((ad) => (
            <div key={ad} className="text-center">
              {ad}
            </div>
          ))}
        </div>
      )}
      <div className="grid gap-1" style={{ gridTemplateColumns: IZGARA_SUTUNLARI }}>
        {Array.from({ length: bosluk }, (_, i) => (
          <div key={`bos-${i}`} />
        ))}
        {gunler.map((g) => {
          const isaretli = secili.has(g);
          const kapali = enErken !== undefined && g < enErken;
          return (
            <button
              key={g}
              type="button"
              data-test={`${kanca}-gun-${g}`}
              aria-pressed={isaretli}
              disabled={kapali}
              // TARIHIN TAMAMI ERISILEBILIR ADDA: hucrede yalniz gun
              // SAYISI yaziyor; ekran okuyucu "17" duyar ve hangi ay
              // oldugunu bilemez.
              aria-label={g}
              className="odak-ic tabular-nums"
              style={{
                // 48x48 — KOSULSUZ (yukseklik burada, genislik izgara
                // sutununda: `minmax(3rem, 1fr)`).
                minHeight: "3rem",
                fontSize: "var(--yz-fs-sm)",
                borderRadius: "var(--yz-radius-sm)",
                border: "var(--yz-border-w) solid var(--yz-border)",
                opacity: kapali ? 0.4 : undefined,
                color: isaretli ? "var(--yz-on-fill)" : "var(--yz-text-2)",
                background: isaretli ? "var(--yz-metal-accent)" : undefined,
              }}
              onClick={() => onSec(g)}
            >
              {Number(g.slice(8, 10))}
            </button>
          );
        })}
      </div>
      </div>
    </div>
  );
}
