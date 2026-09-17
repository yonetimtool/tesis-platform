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
 * DOKUNMA HEDEFI 44px
 * =========================================================================
 * Hucre `min-h/min-w` 2.75rem = 44px: tasarim sisteminin dokunma hedefi.
 * Onceki serit 2.25rem (36px) idi ve bu bir DOKUNMA hedefi degil, yogun
 * baglam olcusudur.
 */
import { useMemo } from "react";

import { useI18n } from "@/lib/i18n/kullan";

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
    <div data-test={`${kanca}-takvim`}>
      {etiketli && (
        <div
          className="grid grid-cols-7 gap-1"
          aria-hidden="true"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
        >
          {gunAdlari.map((ad) => (
            <div key={ad} className="text-center">
              {ad}
            </div>
          ))}
        </div>
      )}
      <div className="grid grid-cols-7 gap-1">
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
                minWidth: "2.75rem",
                minHeight: "2.75rem",
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
  );
}
