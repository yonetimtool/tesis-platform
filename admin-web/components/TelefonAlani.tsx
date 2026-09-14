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

import { Alan, AlanSarmal, Secim } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import {
  ULKELER,
  telefonGiris,
  telefonHatasi,
  telefonParcala,
  telefonUlkeyiDegistir,
  telefonUlusal,
  ulusalTemizle,
  ulkeBul,
  ulkeEtiketi,
  type TelefonHatasi,
} from "@/lib/telefon";

/** Hata KIMLIGI -> sozluk anahtari. Cumle cizim katmaninda kalir. */
const HATA_ANAHTARI: Record<TelefonHatasi, SozlukAnahtari> = {
  bos: "telefonHataBos",
  eksik: "telefonHataEksik",
  gecersizOnEk: "telefonHataOnEk",
  // (P227 §3) FAZLA HANE SESSIZCE KESILMEZ, SOYLENIR.
  tasma: "telefonHataTasma",
  // (P233 §3) ULKE SECILMEDEN NUMARA GECERLI SAYILMAZ.
  ulkeYok: "telefonHataUlkeYok",
};

/** (P227 §3 · P233 §3) Kutunun kabul ettigi en uzun metin.
 *
 * Sinir, EN UZUN ulkenin bicimli numarasina gore hesaplanir ve iki
 * karakter PAY birakilir. Payin sebebi P227 §3'te olculdu: sinir tam
 * oturursa tarayici fazla karakteri SESSIZCE yutar ve kullanici "fazla
 * hane girdim" hatasini HIC goremez — yani `maxLength` uzerinden sessiz
 * kesmeyi geri getirmis oluruz.
 *
 * Ulke kodu AYRI kutuda oldugu icin bu sayi yalnizca ulusal kismi kapsar:
 * en cok hane + aralarindaki bosluklar.
 */
const EN_COK_KARAKTER =
  Math.max(...ULKELER.map((u) => u.enCok)) +
  Math.ceil(Math.max(...ULKELER.map((u) => u.enCok)) / 2) +
  2;

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
  const { ulke } = telefonParcala(deger);

  // SECILEN ULKE AYRI TUTULUR cunku `+1`i US ve CA, `+7`yi RU ve KZ
  // paylasir: degerden geri cozulen ulke HER ZAMAN listedeki ilki olur ve
  // kullanicinin sectigi CA, bir sonraki cizimde US'e ATLARDI. Saklanan
  // deger acisindan fark yok (ayni E.164), ama kutunun kullanicinin
  // secimini unutmasi hatali gorunur.
  const [elleSecilen, setElleSecilen] = useState<string | null>(null);
  const secili =
    elleSecilen && ulkeBul(elleSecilen)?.arama === ulke?.arama
      ? elleSecilen
      : (ulke?.kod ?? "");

  return (
    <AlanSarmal
      etiket={etiket}
      zorunlu={zorunlu}
      id={id}
      hata={hata ?? kendiHatasi}
      ipucu={ipucu ?? t("telefonIpucu")}
    >
      {(b) => (
        <div className="flex gap-2">
          {/* ULKE KODU ELLE YAZILMAZ, SECILIR. Kutu bos baslar: onceden
              secili bir `+90`, kutuya hic bakmadan yabanci numara yazan
              kullanicinin numarasini SESSIZCE Turk numarasina cevirirdi —
              ve telefon GLOBAL BENZERSIZ anahtar oldugu icin bu, ya
              baskasinin numarasiyla cakisma ya da erisilemez bir hesap
              demektir. Bir kerelik tek dokunusun karsiligi budur; TR
              listenin BASINDA. */}
          <Secim
            data-test="telefon-ulke"
            aria-label={t("telefonUlkeEtiket")}
            className="w-32 shrink-0"
            hatali={Boolean(hata ?? kendiHatasi)}
            value={secili}
            onChange={(e) => {
              setElleSecilen(e.target.value || null);
              onDegisti(telefonUlkeyiDegistir(deger, e.target.value));
            }}
            disabled={disabled}
          >
            <option value="">{t("telefonUlkeSec")}</option>
            {ULKELER.map((u) => (
              <option key={u.kod} value={u.kod}>
                {`${u.bayrak} ${ulkeEtiketi(u)}`}
              </option>
            ))}
          </Secim>
          <Alan
            {...b}
            data-test="telefon-numara"
            // `type="tel"` DEGIL `inputMode="tel"`: `type="tel"` bazi
            // tarayicilarda kendi bicimlemesini dayatir ve bizimkiyle
            // catisir. Aradigimiz sey KLAVYE, dogrulama degil.
            inputMode="tel"
            autoComplete="tel-national"
            // BICIMLEME CIZIMDE UYGULANIR (fikirsiz/idempotent): kullanici
            // ne yapistirirsa yapistirsin kutuda `541 922 23 88` gorunur.
            value={telefonUlusal(deger)}
            onChange={(e) => {
              const yazilan = e.target.value;
              // YAPISTIRILAN METIN KENDI ULKE KODUNU GETIRDIYSE o kazanir:
              // rehberden kopyalanan numara `+49 171...` diye gelir ve
              // kullanicinin ayrica listeden Almanya'yi secmesini beklemek,
              // bilgi elimizdeyken yapilan gereksiz bir istektir.
              if (yazilan.includes("+") || yazilan.trim().startsWith("00")) {
                onDegisti(yazilan);
                return;
              }
              onDegisti(
                ulke ? `+${ulke.arama}${ulusalTemizle(yazilan)}` : yazilan,
              );
            }}
            onBlur={() => setDokunuldu(true)}
            maxLength={EN_COK_KARAKTER}
            placeholder={t("telefonYerTutucu")}
            disabled={disabled}
            autoFocus={autoFocus}
          />
        </div>
      )}
    </AlanSarmal>
  );
}
