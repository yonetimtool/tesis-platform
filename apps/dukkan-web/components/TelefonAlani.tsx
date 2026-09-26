"use client";

/**
 * (P248 §2) TELEFON ALANI — dukkan-web ve tanitim-web ORTAK kopyasi.
 *
 * =========================================================================
 * NEDEN BURADA BIR KOPYA VAR, NEDEN admin-web'IN BILESENI DEGIL
 * =========================================================================
 * Iki uygulama AYRI Docker yapim baglamlarinda derleniyor
 * (`context: ../apps/<ad>`); paket disindan dosya import etmek imaja
 * giremez (bkz. `lib/hukuki.ts` ayni gerekce). admin-web'in bileseni
 * ayrica panelin tasarim sistemine (`--yz-*`, `AlanSarmal`) ve 7 dilli
 * sozluge bagli; bu iki site yalniz Turkce.
 *
 * NE PAYLASILIYOR, NASIL KILITLI:
 *  * MANTIK (bicim, ulke tablosu, uzunluk siniri, dogrulama, E.164):
 *    `lib/telefon.ts` + `lib/ulke-telefon.ts` admin-web'dekinin BIREBIR
 *    kopyasi.
 *  * BU DOSYA iki uygulamada BIREBIR ayni.
 *  admin-web `tests/telefon-kapsam.test.ts` ucunu de bayt bayt
 *  karsilastirir ve bu uygulamalarda ham telefon girdisi ararsa duser.
 *
 * DAVRANIS admin-web'dekiyle ayni: ulke kodu SECILIR (bos baslar — sessiz
 * `+90` yok), numara ulkeye gore bicimlenir, uzunluk sinirli, fazla hane
 * sessizce kesilmez SOYLENIR; yapistirilan `+49 ...` kendi ulkesini getirir.
 */
import { useId, useState } from "react";

import {
  ULKELER,
  telefonHatasi,
  telefonParcala,
  telefonUlkeyiDegistir,
  telefonUlusal,
  ulkeBul,
  ulusalTemizle,
  type TelefonHatasi,
} from "@/lib/telefon";

const HATA_METNI: Record<TelefonHatasi, string> = {
  bos: "Telefon numarası gerekli.",
  eksik: "Telefon numarası eksik.",
  gecersizOnEk: "Cep telefonu numarası 5 ile başlamalı.",
  tasma: "Telefon numarası çok uzun.",
  ulkeYok: "Ülke kodunu seçin.",
};

/** Ulusal kismin en uzun bicimli hali + 2 pay (sessiz kesme olmasin). */
const EN_COK_KARAKTER =
  Math.max(...ULKELER.map((u) => u.enCok)) +
  Math.ceil(Math.max(...ULKELER.map((u) => u.enCok)) / 2) +
  2;

export function telefonHataMetni(
  ham: string,
  zorunlu: boolean,
  sabitHat = false,
): string | null {
  const h = telefonHatasi(ham, zorunlu, sabitHat);
  return h ? HATA_METNI[h] : null;
}

export function TelefonAlani({
  etiket,
  deger,
  onDegisti,
  zorunlu = false,
  sabitHat = false,
  id,
  name,
  kutuSinifi = "",
  hataSinifi = "",
  yardim,
  yardimSinifi = "",
  etiketSinifi = "",
}: {
  etiket: string;
  /** Ham deger (`(+90) 541 922 23 88`); sunucuya `telefonNormalle` ile. */
  deger: string;
  onDegisti: (yeni: string) => void;
  zorunlu?: boolean;
  /** Isletme/iletisim numarasi: sabit hat da gecerli (TR `5` aranmaz). */
  sabitHat?: boolean;
  id?: string;
  name?: string;
  /** Sitenin kendi girdi sinifi (her iki kutuya da uygulanir). */
  kutuSinifi?: string;
  hataSinifi?: string;
  yardim?: string;
  yardimSinifi?: string;
  etiketSinifi?: string;
}) {
  const otoId = useId();
  const alanId = id ?? otoId;
  const [dokunuldu, setDokunuldu] = useState(false);
  const { ulke } = telefonParcala(deger);
  const [elleSecilen, setElleSecilen] = useState<string | null>(null);
  const secili =
    elleSecilen && ulkeBul(elleSecilen)?.arama === ulke?.arama
      ? elleSecilen
      : (ulke?.kod ?? "");
  const hata = dokunuldu ? telefonHataMetni(deger, zorunlu, sabitHat) : null;

  return (
    <div>
      <label htmlFor={alanId} className={etiketSinifi}>
        {etiket}
      </label>
      <div style={{ display: "flex", gap: "0.5rem" }}>
        <select
          aria-label="Ülke kodu"
          data-test="telefon-ulke"
          value={secili}
          onChange={(e) => {
            setElleSecilen(e.target.value || null);
            onDegisti(telefonUlkeyiDegistir(deger, e.target.value));
          }}
          className={kutuSinifi}
          // Sabit genislik SATIR ICI: sitenin `w-full` sinifi Tailwind'in
          // CSS sirasinda kazanir ve numara kutusu sifira inerdi (P236).
          style={{ width: "7.5rem", flexShrink: 0 }}
        >
          <option value="">Ülke</option>
          {ULKELER.map((u) => (
            <option key={u.kod} value={u.kod}>
              {/* BAYRAK YOK: yerlesik `<select>` klavyeyle GORUNEN metnin
                  basina gore atlar; `TR +90` yazan "T" ile bulunur. */}
              {`${u.kod} +${u.arama}`}
            </option>
          ))}
        </select>
        <input
          id={alanId}
          name={name}
          data-test="telefon-numara"
          inputMode="tel"
          autoComplete="tel-national"
          required={zorunlu || undefined}
          aria-invalid={hata ? true : undefined}
          className={`${kutuSinifi} ${hata ? hataSinifi : ""}`}
          style={{ minWidth: 0, flex: 1 }}
          maxLength={EN_COK_KARAKTER}
          placeholder="5XX XXX XX XX"
          value={
            ulke || !deger.includes("+") ? telefonUlusal(deger) : deger
          }
          onBlur={() => setDokunuldu(true)}
          onChange={(e) => {
            const yazilan = e.target.value;
            if (yazilan.includes("+") || yazilan.trim().startsWith("00")) {
              onDegisti(yazilan);
              return;
            }
            onDegisti(
              ulke ? `+${ulke.arama}${ulusalTemizle(yazilan)}` : yazilan,
            );
          }}
        />
      </div>
      {hata ? (
        <p role="alert" className={yardimSinifi} style={{ color: "#b91c1c" }}>
          {hata}
        </p>
      ) : yardim ? (
        <p className={yardimSinifi}>{yardim}</p>
      ) : null}
    </div>
  );
}
