"use client";

// (P250 §1) AD + SOYAD — iki ayri, ikisi de zorunlu alan.
//
// Kullanici ekleme, profil, davet tamamlama, kayit ve platform yonetici
// formlari BU bileseni kullanir; kural tek yerde (`lib/kisi-adi.ts`).
// Yazarken bicimlenir (ad kelime basi buyuk, soyad tamami buyuk, Turkce
// harf kuraliyla); kaydederken cagiran `adBicimle`/`soyadBicimle` ile son
// bicimi (kirpma + tek bosluk) uygular. Sunucu da ayni kurali uygular.
import { Alan, AlanSarmal } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import { adBicimle, soyadBicimle } from "@/lib/kisi-adi";

export function AdSoyadAlanlari({
  ad,
  soyad,
  onAd,
  onSoyad,
  disabled,
  adSinir = 150,
  kanca = "kisi",
  adHata,
  soyadHata,
}: {
  ad: string;
  soyad: string;
  onAd: (v: string) => void;
  onSoyad: (v: string) => void;
  disabled?: boolean;
  /** Sunucudaki `ad` siniri — uca gore 100/120/150. */
  adSinir?: number;
  /** `data-test` oneki: `<kanca>-ad`, `<kanca>-soyad`. */
  kanca?: string;
  adHata?: string | null;
  soyadHata?: string | null;
}) {
  const t = useT();
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <AlanSarmal etiket={t("kisiAd")} zorunlu hata={adHata}>
        {(b) => (
          <Alan
            {...b}
            data-test={`${kanca}-ad`}
            maxLength={adSinir}
            autoComplete="given-name"
            value={ad}
            onChange={(e) => onAd(adBicimle(e.target.value, true))}
            disabled={disabled}
            required
          />
        )}
      </AlanSarmal>
      <AlanSarmal etiket={t("kisiSoyad")} zorunlu hata={soyadHata}>
        {(b) => (
          <Alan
            {...b}
            data-test={`${kanca}-soyad`}
            maxLength={100 /* sunucu: AdSoyadGirdisi.soyad (_G.AD) */}
            autoComplete="family-name"
            value={soyad}
            onChange={(e) => onSoyad(soyadBicimle(e.target.value, true))}
            disabled={disabled}
            required
          />
        )}
      </AlanSarmal>
    </div>
  );
}
