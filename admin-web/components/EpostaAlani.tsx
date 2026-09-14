"use client";

/**
 * (P233 §4) E-POSTA ALANI — TEK bilesen, her form ona baglanir.
 *
 * `TelefonAlani`nin ikizi ve ayni gerekceyle var (P166 §9): "her forma tek
 * satir dogrulama ekle" cozumu, YEDINCI formda yine unutulur. Alan bir
 * BILESEN olunca uzunluk siniri, bicim denetimi, klavye tipi,
 * `autoComplete` ve HATA METNI birlikte gelir.
 *
 * =========================================================================
 * HATA NE ZAMAN GORUNUR
 * =========================================================================
 * YAZARKEN DEGIL, ALANDAN CIKINCA. `a@` yazan kullaniciya daha ikinci
 * harfte "bicim gecersiz" demek, adresini yazmasini bitirmeden azarlamaktir.
 */
import { useState } from "react";

import { Alan, AlanSarmal } from "@/components/ui";
import {
  EPOSTA_SINIR,
  epostaHatasi,
  type EpostaHatasi,
} from "@/lib/eposta";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/** Hata KIMLIGI -> sozluk anahtari. Cumle cizim katmaninda kalir. */
const HATA_ANAHTARI: Record<EpostaHatasi, SozlukAnahtari> = {
  bos: "epostaHataBos",
  bicim: "epostaHataBicim",
  yerelUzun: "epostaHataYerelUzun",
  cokUzun: "epostaHataCokUzun",
};

export function epostaHataMetni(
  ham: string,
  zorunlu: boolean,
  t: (a: SozlukAnahtari) => string,
): string | null {
  const h = epostaHatasi(ham, zorunlu);
  return h ? t(HATA_ANAHTARI[h]) : null;
}

export function EpostaAlani({
  etiket,
  deger,
  onDegisti,
  zorunlu = false,
  hata,
  ipucu,
  id,
  disabled,
  autoFocus,
  readOnly,
  /** Testlerin alani bulmasi icin; verilmezse `eposta-alani`. */
  kanca,
}: {
  etiket: string;
  deger: string;
  onDegisti: (yeni: string) => void;
  zorunlu?: boolean;
  /** Disaridan gelen hata (gonderim/sunucu). Alan kendi hatasini EZMEZ. */
  hata?: string | null;
  ipucu?: string;
  id?: string;
  disabled?: boolean;
  autoFocus?: boolean;
  readOnly?: boolean;
  kanca?: string;
}) {
  const t = useT();
  const [dokunuldu, setDokunuldu] = useState(false);
  const kendiHatasi = dokunuldu ? epostaHataMetni(deger, zorunlu, t) : null;

  return (
    <AlanSarmal
      etiket={etiket}
      zorunlu={zorunlu}
      id={id}
      hata={hata ?? kendiHatasi}
      ipucu={ipucu}
    >
      {(b) => (
        <Alan
          {...b}
          data-test={kanca ?? "eposta-alani"}
          // `type="email"` DEGIL `inputMode="email"`: `type="email"`
          // tarayicinin KENDI dogrulama balonunu getirir, bizim
          // (cevrilmis) hata metnimizle catisir ve iki ayri dilde iki ayri
          // cumle gosterir.
          inputMode="email"
          autoComplete="email"
          value={deger}
          onChange={(e) => onDegisti(e.target.value)}
          onBlur={() => setDokunuldu(true)}
          // SINIR SESSIZ DEGIL: `maxLength` fazlasini yutar ama kullanici
          // 254'e zaten pratikte hic ulasmaz; ulasirsa `cokUzun` hatasi
          // once gorunur (dogrulama kirpilmamis degeri okur).
          maxLength={EPOSTA_SINIR + 2}
          disabled={disabled}
          readOnly={readOnly}
          autoFocus={autoFocus}
        />
      )}
    </AlanSarmal>
  );
}
