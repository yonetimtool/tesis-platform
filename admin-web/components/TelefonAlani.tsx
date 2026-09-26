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
import { useId, useState } from "react";

import { UlkeSecici } from "@/components/UlkeSecici";
import { Alan, AlanSarmal } from "@/components/ui";
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
  kimlikTelefonMu,
  telefonBicimle,
  ulkeBul,
  ulkeEtiketi,
  type TelefonHatasi,
} from "@/lib/telefon";

/** (P248 §2) Tarayici ipuclari — cevrilecek metin DEGIL, HTML deger kumesi. */
const KLAVYE = { kimlik: "email", telefon: "tel" } as const;
const OTOMATIK_DOLDURMA = { kimlik: "username", telefon: "tel-national" } as const;

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
  sabitHat = false,
): string | null {
  const h = telefonHatasi(ham, zorunlu, sabitHat);
  return h ? t(HATA_ANAHTARI[h]) : null;
}

/**
 * (P248 §2) TEK BILESEN, UC KULLANIM — ikinci bir telefon bileseni YAZILMAZ.
 *
 *  * VARSAYILAN: etiketli form alani (kullanici ekleme ekrani ve digerleri).
 *  * `cercevesiz`: etiket/ipucu/hata satiri CIZILMEZ, etiket `aria-label`
 *    olur. Tablo hucresi (Excel ice aktarim) ve kendi etiketini ceken
 *    ekranlar (giris vitrini) icin. Bicim, ulke kodu ve sinir AYNI.
 *  * `kimlik`: tek alanli giris (P205) — "e-posta VEYA telefon". Alan
 *    rakam/`+` ile baslayinca TELEFON moduna gecer (ulke secici belirir,
 *    numara bicimlenir); harf ya da `@` gorulunce e-posta modunda kalir.
 *    Karar ve gerekcesi `lib/telefon.ts` `kimlikTelefonMu`da.
 *
 * NEDEN AYNI `<input>`: kimlik modunda kip degisirken numara kutusu
 * YENIDEN KURULMAZ (ulke secici solunda belirir, girdi yerinde kalir).
 * Yeniden kurulsaydi odak ve imlec ilk rakamda kaybolurdu.
 */
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
  cercevesiz = false,
  kimlik = false,
  varsayilanUlke,
  kutuSinifi,
  kutuStili,
  dataTest = "telefon-numara",
  onPaste,
  name,
  placeholder,
  sabitHat = false,
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
  /** (P248 §2) Etiket satiri yok — tablo hucresi / kendi etiketli ekran. */
  cercevesiz?: boolean;
  /** (P248 §2) "E-posta veya telefon" tek alani (giris). */
  kimlik?: boolean;
  /** (P248 §2) Ulkesiz yazilan numaraya varsayilan ulke (YALNIZ giris:
   *  giris hicbir sey SAKLAMAZ, yanlis tahmin yalnizca 401 uretir). */
  varsayilanUlke?: string;
  /** (P248 §2) Kendi paletini tasiyan ekranlar (giris vitrini) icin. */
  kutuSinifi?: string;
  kutuStili?: React.CSSProperties;
  dataTest?: string;
  onPaste?: React.ClipboardEventHandler<HTMLInputElement>;
  name?: string;
  placeholder?: string;
  /** (P248 §2) Firma/tedarikci numarasi: sabit hat da gecerli. */
  sabitHat?: boolean;
}) {
  const t = useT();
  const otoId = useId();
  const [dokunuldu, setDokunuldu] = useState(false);
  // KIMLIK MODUNDA e-posta yazilirken telefon dogrulamasi YAPILMAZ.
  const telefonModu = !kimlik || kimlikTelefonMu(deger);
  const kendiHatasi =
    dokunuldu && telefonModu && !kimlik
      ? telefonHataMetni(deger, zorunlu, t, sabitHat)
      : null;
  const { ulke: cozulen } = telefonParcala(deger);

  // SECILEN ULKE AYRI TUTULUR cunku `+1`i US ve CA, `+7`yi RU ve KZ
  // paylasir: degerden geri cozulen ulke HER ZAMAN listedeki ilki olur ve
  // kullanicinin sectigi CA, bir sonraki cizimde US'e ATLARDI. Saklanan
  // deger acisindan fark yok (ayni E.164), ama kutunun kullanicinin
  // secimini unutmasi hatali gorunur.
  const [elleSecilen, setElleSecilen] = useState<string | null>(null);
  // (P248 §2) Ulkesiz numarada TERCIH: once kullanicinin sectigi, sonra
  // varsayilan. Kimlik kipinde numara silinip yeniden yazilinca secilen
  // ulke (DE) unutulup TR'ye dusmesin — olcumde tam olarak bu oldu.
  const tercih =
    (elleSecilen ? ulkeBul(elleSecilen) : null) ??
    (varsayilanUlke ? ulkeBul(varsayilanUlke) : null);
  const ulke = cozulen ?? (telefonModu ? tercih : null);
  const secili =
    elleSecilen && ulkeBul(elleSecilen)?.arama === ulke?.arama
      ? elleSecilen
      : (ulke?.kod ?? "");

  const gorunenHata = hata ?? kendiHatasi;

  function numaraDegisti(yazilan: string) {
    if (kimlik) {
      // (P248 §2) TELEFON MODUNDA YALNIZ BOSLUK: `+49 151` yazilirken
      // `+49` ulke kutusuna gecer ve numara kutusu BOSALIR; ardindan gelen
      // bosluk e-posta moduna dusurup ulkeyi KAYBETTIRIYORDU (Playwright
      // olcumu: `+49 151...` -> `+90151...`, 401). Bosluk yok sayilir.
      if (kimlikTelefonMu(deger) && yazilan !== "" && yazilan.trim() === "") {
        return;
      }
      // E-POSTA MODU: metin OLDUGU GIBI; ilk rakam/`+` telefona gecirir.
      if (!kimlikTelefonMu(yazilan)) {
        onDegisti(yazilan);
        return;
      }
      // Telefon modunda numara SILINDI: alan bos (notr) moda doner.
      if (
        kimlikTelefonMu(deger) &&
        !ulusalTemizle(yazilan) &&
        !yazilan.includes("+")
      ) {
        onDegisti("");
        return;
      }
    }
    // YAPISTIRILAN METIN KENDI ULKE KODUNU GETIRDIYSE o kazanir:
    // rehberden kopyalanan numara `+49 171...` diye gelir ve
    // kullanicinin ayrica listeden Almanya'yi secmesini beklemek,
    // bilgi elimizdeyken yapilan gereksiz bir istektir.
    if (yazilan.includes("+") || yazilan.trim().startsWith("00")) {
      onDegisti(yazilan);
      return;
    }
    // (P248 §2) Kimlik modunda ILK yazim (e-postadan telefona gecis)
    // ham metni tasir: `0532...` bastaki `0` ile TR'ye cozulur.
    if (kimlik && !kimlikTelefonMu(deger)) {
      const p = telefonParcala(yazilan);
      const u = p.ulke ?? tercih;
      onDegisti(u ? telefonBicimle(ulusalTemizle(p.haneler), u) : yazilan);
      return;
    }
    onDegisti(ulke ? `+${ulke.arama}${ulusalTemizle(yazilan)}` : yazilan);
  }

  const govde = (b: {
    id: string;
    "aria-invalid": boolean | undefined;
    "aria-describedby": string | undefined;
  }) => (
    <div className="flex gap-2">
      {/* (P236) GENISLIK SARMALAYICI DIVDE, BILESENIN USTUNDE DEGIL.
          =========================================================
          OLCULEN KUSUR: `Secim` bilesenine dogrudan `w-32 shrink-0` sinifi vermistim.
          `Secim` KENDI sinifinda `w-full` tasiyor ve ikisi de `width`
          kuruyor; hangisinin kazandigi CLASS SIRASINA DEGIL, Tailwind'in
          URETTIGI CSS SIRASINA bagli. Olculdu (tailwind 3.4.6 ciktisi):
              .w-32  { width: 8rem }   <- once
              .w-full{ width: 100% }   <- SONRA, yani KAZANAN
          Sonuc: select %100 genislik aliyor, `shrink-0` yuzunden
          KUCULMUYOR ve numara alani SIFIR GENISLIGE iniyor. Kullanici
          ulkeyi secebiliyor ama numarayi YAZAMIYOR.
          jsdom DUZEN HESAPLAMAZ — DOM testlerinin hepsi gecti. */}
      {/* ULKE KODU ELLE YAZILMAZ, SECILIR. Kutu bos baslar: onceden
          secili bir `+90`, kutuya hic bakmadan yabanci numara yazan
          kullanicinin numarasini SESSIZCE Turk numarasina cevirirdi —
          ve telefon GLOBAL BENZERSIZ anahtar oldugu icin bu, ya
          baskasinin numarasiyla cakisma ya da erisilemez bir hesap
          demektir. Bir kerelik tek dokunusun karsiligi budur; TR
          listenin BASINDA. */}
      {telefonModu ? (
        <div className={cercevesiz && !kimlik ? "w-28 shrink-0" : "w-32 shrink-0"}>
          {/* (P236) ARANABILIR SECICI — elli ulkede yerlesik `<select>`
              yazarak atlamayi yalniz GORUNEN metne gore yapiyordu ve o
              metin artik `🇹🇷 +90`; kullanici "TR" yazip bulamazdi.
              Mobilde P233'ten beri arama kutulu alt sayfa vardi. */}
          <UlkeSecici
            deger={secili}
            etiket={t("telefonUlkeEtiket")}
            disabled={disabled}
            hatali={Boolean(gorunenHata)}
            kutuSinifi={kutuSinifi}
            kutuStili={kutuStili}
            onDegisti={(kod) => {
              setElleSecilen(kod || null);
              onDegisti(telefonUlkeyiDegistir(deger, kod));
            }}
          />
        </div>
      ) : null}
      {/* `min-w-0`: flex ogesinin varsayilan `min-width:auto` degeri,
          icerik genisliginin altina inmesini engeller ve uzun bir
          yer tutucu kutuyu tasirirdi. */}
      <div className="min-w-0 flex-1">
        <Alan
          {...b}
          data-test={dataTest}
          name={name}
          aria-label={cercevesiz ? etiket : undefined}
          // `type="tel"` DEGIL `inputMode="tel"`: `type="tel"` bazi
          // tarayicilarda kendi bicimlemesini dayatir ve bizimkiyle
          // catisir. Aradigimiz sey KLAVYE, dogrulama degil.
          // (P248 §2) KIMLIK MODUNDA klavye `email`: telefon klavyesinde
          // harf yok ve e-postaya donmek imkansiz olurdu.
          inputMode={kimlik ? KLAVYE.kimlik : KLAVYE.telefon}
          autoComplete={kimlik ? OTOMATIK_DOLDURMA.kimlik : OTOMATIK_DOLDURMA.telefon}
          className={kutuSinifi}
          style={kutuStili}
          hatali={Boolean(gorunenHata)}
          // BICIMLEME CIZIMDE UYGULANIR (fikirsiz/idempotent): kullanici
          // ne yapistirirsa yapistirsin kutuda `541 922 23 88` gorunur.
          // (P248 §2) `+` yazildi ama ulke HENUZ cozulmedi (`+4`): ham
          // metin gosterilir. Bicimleyici `+`yi yutsaydi kullanici bir
          // sonraki rakamda ulke kodunu kaybederdi (yazilan `4` -> TR).
          value={
            telefonModu && (cozulen || !deger.includes("+"))
              ? telefonUlusal(deger)
              : deger
          }
          onChange={(e) => numaraDegisti(e.target.value)}
          onPaste={onPaste}
          onBlur={() => setDokunuldu(true)}
          // Kimlik modunda sinir e-postaya gore (RFC 5321: 254).
          maxLength={kimlik && !telefonModu ? 254 : EN_COK_KARAKTER}
          placeholder={placeholder ?? t("telefonYerTutucu")}
          disabled={disabled}
          autoFocus={autoFocus}
          required={kimlik && zorunlu ? true : undefined}
        />
      </div>
    </div>
  );

  if (cercevesiz) {
    return govde({
      id: id ?? otoId,
      "aria-invalid": gorunenHata ? true : undefined,
      "aria-describedby": undefined,
    });
  }

  return (
    <AlanSarmal
      etiket={etiket}
      zorunlu={zorunlu}
      id={id}
      hata={gorunenHata}
      ipucu={ipucu ?? t("telefonIpucu")}
    >
      {govde}
    </AlanSarmal>
  );
}
