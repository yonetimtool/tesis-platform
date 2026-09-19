"use client";

/**
 * (P241 §2) TAKVIM GORUNUMU — klasik ay izgarasi.
 *
 * =========================================================================
 * NEDEN "AY" GORUNUMUNUN YANINA, ONUN YERINE DEGIL
 * =========================================================================
 * `ay` gorunumu YATAY bir serittir: satir = kisi, sutun = gun. "Ali bu ay
 * hangi gunler calisiyor" sorusunu yanitlar.
 *
 * Takvim GUN eksenlidir: "12 Mart'ta kimler var". Ikisi ayni veriden
 * turer ama ayni cizimle gosterilemez — birinde kisi satirdir, otekinde
 * gun hucredir. Birini otekiyle degistirmek, bir soruyu yanitlarken
 * digerini kaybetmek olurdu.
 *
 * =========================================================================
 * PAZARTESI BASLANGICLI
 * =========================================================================
 * Hafta baslangici `AyTakvimi` ile AYNI (ISO, pazartesi): iki takvim
 * yan yana farkli baslarsa kullanici hangisinin dogru oldugunu bilemez.
 */
import { useMemo } from "react";

import { useT } from "@/lib/i18n/kullan";

/**
 * Bilesen KENDI tipini TANIMLAMAZ, cagirandan alir (jenerik).
 *
 * Kopya bir tip yazmak, sayfadaki `Blok`/`CizelgeKisi` degistiginde
 * sessizce eskir ve derleyici bunu GORMEZDI (yapisal esleme ikisini de
 * kabul ederdi). Bu yuzden gereken ALANLAR kisitlanir, tip cagirandan
 * gelir.
 */
type BlokTaban = {
  plan_id: string;
  tarih: string;
  baslar: string;
  yayinlandi_at: string | null;
};
type KisiTaban<B extends BlokTaban> = {
  user_id: string;
  ad: string;
  bloklar: B[];
};

/** `2026-03-02T08:00:00` -> `08:00`. */
function ss(damga: string): string {
  return damga.slice(11, 16);
}

function isoGun(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(
    d.getDate(),
  ).padStart(2, "0")}`;
}

export function TakvimGorunumu<
  B extends BlokTaban,
  K extends KisiTaban<B>,
>({
  baslangic,
  personel,
  bugun,
  onBlok,
}: {
  baslangic: string;
  personel: K[];
  bugun: string;
  onBlok: (kisi: K, blok: B) => void;
}) {
  const t = useT();

  /** Ayin ilk gununun icinde bulundugu ISO haftasinin pazartesisi. */
  const hucreler = useMemo(() => {
    const ilk = new Date(`${baslangic.slice(0, 7)}-01T00:00:00`);
    const kaydir = (ilk.getDay() + 6) % 7;
    const bas = new Date(ilk);
    bas.setDate(bas.getDate() - kaydir);
    return Array.from({ length: 42 }, (_, i) => {
      const d = new Date(bas);
      d.setDate(d.getDate() + i);
      return { gun: isoGun(d), ayIci: d.getMonth() === ilk.getMonth() };
    });
  }, [baslangic]);

  /** gun -> [(kisi, blok)] */
  const gunlere = useMemo(() => {
    const harita = new Map<string, { kisi: K; blok: B }[]>();
    for (const k of personel) {
      for (const b of k.bloklar) {
        const liste = harita.get(b.tarih) ?? [];
        liste.push({ kisi: k, blok: b });
        harita.set(b.tarih, liste);
      }
    }
    return harita;
  }, [personel]);

  const gunAdlari = useMemo(() => {
    // GUN ADLARI `Intl`DEN: elle yazilan yedi kisaltma, yedi dilde
    // yedi kez yazilmak zorunda kalirdi.
    const bic = new Intl.DateTimeFormat(undefined, { weekday: "short" });
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(2026, 2, 2 + i); // 2 Mart 2026 = pazartesi
      return bic.format(d);
    });
  }, []);

  return (
    <div data-test="vardiya-takvim">
      <div className="grid grid-cols-7 gap-px">
        {gunAdlari.map((ad) => (
          <div
            key={ad}
            className="px-1 pb-1 text-center"
            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
          >
            {ad}
          </div>
        ))}
        {hucreler.map((h) => {
          const kayitlar = gunlere.get(h.gun) ?? [];
          return (
            <div
              key={h.gun}
              data-test={`vardiya-takvim-gun-${h.gun}`}
              className="min-h-24 rounded-md border p-1"
              style={{
                borderColor:
                  h.gun === bugun ? "var(--yz-accent-edge)" : "var(--yz-border)",
                borderWidth: "var(--yz-border-w)",
                // AY DISI GUNLER SOLUK — ama gizli DEGIL: ayin ilk
                // haftasina tasan bir gece vardiyasi gorunmeli.
                opacity: h.ayIci ? 1 : 0.5,
                background: "var(--yz-surface-1)",
              }}
            >
              <div
                className="tabular-nums"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
              >
                {h.gun.slice(8)}
              </div>
              {kayitlar.slice(0, 4).map(({ kisi, blok }) => (
                <button
                  key={blok.plan_id}
                  type="button"
                  data-test={`vardiya-takvim-blok-${blok.plan_id}`}
                  onClick={() => onBlok(kisi, blok)}
                  className="odak-ic mt-1 block w-full truncate rounded px-1 text-start"
                  style={{
                    fontSize: "var(--yz-fs-xs)",
                    color: "var(--yz-text)",
                    background: "var(--yz-surface-2)",
                    borderInlineStart: blok.yayinlandi_at
                      ? "3px solid var(--yz-accent-edge)"
                      : "3px dashed var(--yz-border)",
                  }}
                >
                  {ss(blok.baslar)} {kisi.ad}
                </button>
              ))}
              {kayitlar.length > 4 && (
                <span
                  style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                >
                  {t("vardiyaRolGrupSayisi", { n: kayitlar.length - 4 })}
                </span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
