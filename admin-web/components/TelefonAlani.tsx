"use client";

/**
 * (P166 §9) TELEFON ALANI — TEK BILESEN, her form ona baglanir.
 *
 * =========================================================================
 * NEDEN BIR BILESEN, NEDEN "her sayfada `telefonGiris` cagir" YETMEDI
 * =========================================================================
 * `lib/telefon.ts` P123'ten beri duruyor ve dokuz ekran onu cagiriyordu.
 * Ama cagirdiklari sey YALNIZCA BICIMLEMEYDI (`telefonGiris`); DOGRULAMA
 * (`telefonHatasi`) dokuzun BESINDE yoktu ve `/tanimlar`in personel/firma
 * defterlerinde HICBIRI yoktu — orada alan duz `tip: "metin"`ti, yani
 * kullanici sinirsiz rakam yazabiliyordu. Kerem'in bildirdigi kusur tam
 * olarak buydu.
 *
 * "Her forma tek satir dogrulama ekle" cozumu, ONUNCU formda yine
 * unutulacak bir cozumdur. Alan bir BILESEN olunca bicimleme, uzunluk
 * siniri, klavye tipi, yer tutucu, `autoComplete` ve HATA METNI birlikte
 * gelir — unutulacak bir parca kalmaz.
 *
 * =========================================================================
 * HATA NE ZAMAN GORUNUR
 * =========================================================================
 * YAZARKEN DEGIL, ALANDAN CIKINCA (ya da gonderim denendiginde). Ilk
 * harfte "eksik numara" yazmak, kullaniciyi daha bir sey yapmadan
 * azarlamaktir. `dokunuldu` bayragi bunu yonetir; disaridan `hata`
 * verildiginde (gonderimde sunucunun/formun buldugu hata) bayrak
 * BEKLENMEZ — o hata zaten kullanicinin bir eylemine cevaptir.
 */
import { useState } from "react";

import { Alan, AlanSarmal } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { telefonGiris, telefonHatasi, type TelefonHatasi } from "@/lib/telefon";

/** Hata KIMLIGI -> sozluk anahtari. Cumle cizim katmaninda kalir. */
const HATA_ANAHTARI: Record<TelefonHatasi, SozlukAnahtari> = {
  bos: "telefonHataBos",
  eksik: "telefonHataEksik",
  gecersizOnEk: "telefonHataOnEk",
};

/** Kutunun kaldirabilecegi en uzun bicimli metin: `0543 199 29 04`. */
const EN_COK_KARAKTER = 14;

export function telefonHataMetni(
  ham: string,
  zorunlu: boolean,
  t: (a: SozlukAnahtari) => string,
): string | null {
  const h = telefonHatasi(ham, zorunlu);
  return h ? t(HATA_ANAHTARI[h]) : null;
}

export function TelefonAlani({
  etiket,
  deger,
  onDegisti,
  zorunlu = false,
  hata,
  ipucu,
  id,
  disabled,
  autoFocus,
}: {
  etiket: string;
  /** Ham deger — bicimleme BURADA yapilir, cagiran taraf saklamak zorunda degil. */
  deger: string;
  onDegisti: (yeni: string) => void;
  zorunlu?: boolean;
  /** Disaridan gelen hata (gonderim/sunucu). Alan kendi hatasini EZMEZ. */
  hata?: string | null;
  ipucu?: string;
  id?: string;
  disabled?: boolean;
  autoFocus?: boolean;
}) {
  const t = useT();
  const [dokunuldu, setDokunuldu] = useState(false);
  const kendiHatasi = dokunuldu ? telefonHataMetni(deger, zorunlu, t) : null;

  return (
    <AlanSarmal
      etiket={etiket}
      zorunlu={zorunlu}
      id={id}
      hata={hata ?? kendiHatasi}
      ipucu={ipucu ?? t("telefonIpucu")}
    >
      {(b) => (
        <Alan
          {...b}
          // `type="tel"` DEGIL `inputMode="tel"`: `type="tel"` bazi
          // tarayicilarda kendi bicimlemesini dayatir ve bizimkiyle
          // catisir. Aradigimiz sey KLAVYE, dogrulama degil.
          inputMode="tel"
          autoComplete="tel"
          // BICIMLEME CIZIMDE UYGULANIR (fikirsiz/idempotent): kullanici
          // ne yapistirirsa yapistirsin kutuda `0543 199 29 04` gorunur.
          value={telefonGiris(deger)}
          onChange={(e) => onDegisti(e.target.value)}
          onBlur={() => setDokunuldu(true)}
          maxLength={EN_COK_KARAKTER}
          placeholder={t("telefonYerTutucu")}
          disabled={disabled}
          autoFocus={autoFocus}
        />
      )}
    </AlanSarmal>
  );
}
