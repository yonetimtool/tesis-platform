"use client";

// (P168 §4.2) ZENGIN METIN EDITORU — e-posta sablonu govdesi.
//
// =========================================================================
// NEDEN DIS KUTUPHANE YOK
// =========================================================================
// Brief kalin/italik/alti-cizili/ustu-cizili, listeler, hizalama, yazi
// tipi/boyut, baslik seviyesi, bicimi temizle ve gorsel ekleme istiyor.
// Bunlarin hepsi tarayicinin KENDI duzenleme motorunda var.
//
// Bir editor kutuphanesi (TipTap/Quill/Slate) 100-300 kB'lik bir bagimlilik
// ve kendi tema/RTL/erisilebilirlik dunyasini getirir. Panelin tamaminda
// `--yz-*` token'lariyla kurulmus bir tasarim sistemi var; ucuncu taraf bir
// editorun ic stilleriyle ugrasmak, o sistemi ikinci kez yazmak olurdu.
//
// =========================================================================
// `document.execCommand` KULLANILIYOR VE BU BILINCLI BIR TAVIZ
// =========================================================================
// API resmen "deprecated" — ama YERINE KONAN BIR SEY YOK: HTML Editing
// API'nin ikamesi hicbir tarayicida sevk edilmedi ve execCommand butun
// guncel tarayicilarda calisiyor. Alternatif, secim/aralik (`Range`)
// uzerinde kendi bicimlendirme motorumuzu yazmakti; bu, iyi test edilmis
// bir tarayici ozelligini elle yeniden uretmek demekti.
//
// SINIR YAZILI: bir gun execCommand gercekten kaldirilirsa bu dosya
// degisir, cagiranlar degismez — govde disariya HER ZAMAN HTML olarak
// verilir.
//
// =========================================================================
// GUVENLIK: URETILEN HTML GUVENILIR DEGILDIR
// =========================================================================
// Bu editor yoneticinin yazdigi HTML'i uretir ve sunucuya oyle gider.
// Panelde geri gosterilirken `dangerouslySetInnerHTML` KULLANILMAZ —
// onizleme duz metne cevrilir. E-posta istemcisi zaten kendi
// temizligini yapar.

import { useEffect, useRef, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

// UCLUDE/CAGRIDA DIZE YAZILMAZ (depo kurali `sabit-metin`): bunlar
// tarayici komut adlaridir, kullanici metni DEGIL.
const KOMUT_BOLD = "bold";
const KOMUT_ITALIC = "italic";
const KOMUT_UNDERLINE = "underline";
const KOMUT_STRIKE = "strikeThrough";
const KOMUT_OL = "insertOrderedList";
const KOMUT_UL = "insertUnorderedList";
const KOMUT_SOL = "justifyLeft";
const KOMUT_ORTA = "justifyCenter";
const KOMUT_SAG = "justifyRight";
const KOMUT_BASLIK = "formatBlock";
const KOMUT_TEMIZLE = "removeFormat";
const KOMUT_FONT = "fontName";
const KOMUT_BOYUT = "fontSize";
const KOMUT_GORSEL = "insertImage";

interface Arac {
  komut: string;
  deger?: string;
  etiket: SozlukAnahtari;
  /** Dugmede gorunen kisa isaret. Ikon yerine harf: on dort arac icin on
   *  dort ikon cizmek, hicbirini taninir kilmazdi. */
  isaret: string;
  kalin?: boolean;
  italik?: boolean;
  altCizgi?: boolean;
  ustCizgi?: boolean;
}

const ARACLAR: Arac[] = [
  { komut: KOMUT_BOLD, etiket: "zenginKalin", isaret: "B", kalin: true },
  { komut: KOMUT_ITALIC, etiket: "zenginItalik", isaret: "I", italik: true },
  { komut: KOMUT_UNDERLINE, etiket: "zenginAltiCizili", isaret: "U", altCizgi: true },
  { komut: KOMUT_STRIKE, etiket: "zenginUstuCizili", isaret: "S", ustCizgi: true },
  { komut: KOMUT_OL, etiket: "zenginNumarali", isaret: "1." },
  { komut: KOMUT_UL, etiket: "zenginMadde", isaret: "•" },
  { komut: KOMUT_SOL, etiket: "zenginSola", isaret: "⌐" },
  { komut: KOMUT_ORTA, etiket: "zenginOrtala", isaret: "≡" },
  { komut: KOMUT_SAG, etiket: "zenginSaga", isaret: "¬" },
  { komut: KOMUT_TEMIZLE, etiket: "zenginTemizle", isaret: "⌫" },
];

const BASLIKLAR = ["p", "h1", "h2", "h3"];
const FONTLAR = ["Arial", "Georgia", "Tahoma", "Verdana"];
/** `fontSize` komutu 1-7 arasi ESKI olcegi kullanir (px degil). */
const BOYUTLAR = ["1", "2", "3", "4", "5", "6", "7"];
const BOS = "";
// UCLUDE/SABLONDA DIZE YAZILMAZ (depo kurallari `sabit-metin` ve i18n
// sablon taramasi). Bunlar CSS degerleri ve komut adlari — kullanici
// metni DEGIL — o yuzden sozluge degil bu sabitlere cikiyorlar.
const CSS_ALTI_CIZILI = "underline";
const CSS_USTU_CIZILI = "line-through";
const CSS_ITALIK = "italic";
const KENAR_ODAK = "var(--yz-border-w) solid var(--yz-accent)";
const KENAR_NORMAL = "var(--yz-border-w) solid var(--yz-border)";

export interface ZenginMetinProps {
  deger: string;
  onDegisti: (html: string) => void;
  /** Erisilebilir ad — `aria-label` olarak kullanilir. */
  etiket: string;
  /** Imlecin oldugu yere metin eklemek icin (etiket cipleri). */
  ekleRef?: React.MutableRefObject<((metin: string) => void) | null>;
}

export function ZenginMetin({ deger, onDegisti, etiket, ekleRef }: ZenginMetinProps) {
  const t = useT();
  const kutuRef = useRef<HTMLDivElement | null>(null);
  const [odakli, setOdakli] = useState(false);

  // DIS DEGER ICERI YAZILIR ama YALNIZ FARKLIYSA: her cizimde
  // `innerHTML` atamak, kullanicinin imlecini her tusta basa atardi.
  useEffect(() => {
    const k = kutuRef.current;
    if (k && k.innerHTML !== deger) k.innerHTML = deger;
  }, [deger]);

  // ETIKET CIPLERI ICIN: imlecin oldugu yere metin ekler. Cagiran
  // bilesen (`ref`) bunu tutar; ciplerin editorun ic yapisini bilmesi
  // gerekmesin.
  useEffect(() => {
    if (!ekleRef) return;
    ekleRef.current = (metin: string) => {
      kutuRef.current?.focus();
      document.execCommand("insertText", false, metin);
      onDegisti(kutuRef.current?.innerHTML ?? BOS);
    };
    return () => {
      ekleRef.current = null;
    };
  }, [ekleRef, onDegisti]);

  function calistir(komut: string, komutDegeri?: string) {
    // ODAK ONCE EDITORE: dugmeye tiklamak odagi dugmeye tasir ve komut
    // hicbir secime uygulanmaz — "tiklıyorum bir sey olmuyor" sinifi.
    kutuRef.current?.focus();
    document.execCommand(komut, false, komutDegeri);
    onDegisti(kutuRef.current?.innerHTML ?? BOS);
  }

  const dugmeStili = (a: Arac) => ({
    fontWeight: a.kalin ? 700 : 400,
    fontStyle: a.italik ? CSS_ITALIK : undefined,
    textDecoration: a.altCizgi
      ? CSS_ALTI_CIZILI
      : a.ustCizgi
        ? CSS_USTU_CIZILI
        : undefined,
    fontSize: "var(--yz-fs-sm)",
    color: "var(--yz-text)",
  });

  return (
    <div>
      <div
        role="toolbar"
        aria-label={t("zenginAracCubugu")}
        className="flex flex-wrap items-center gap-1 p-1"
        style={{
          borderTopLeftRadius: "var(--yz-radius-btn)",
          borderTopRightRadius: "var(--yz-radius-btn)",
          border: "var(--yz-border-w) solid var(--yz-border)",
          borderBottom: "none",
          background: "var(--yz-metal-1)",
        }}
      >
        {ARACLAR.map((a) => (
          <button
            key={a.komut}
            type="button"
            title={t(a.etiket)}
            aria-label={t(a.etiket)}
            // `onMouseDown` + `preventDefault`: `onClick` beklerken
            // tarayici odagi dugmeye tasir ve SECIM KAYBOLUR.
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => calistir(a.komut, a.deger)}
            className="odak-ic min-w-8 rounded px-2 py-1"
            style={dugmeStili(a)}
          >
            {a.isaret}
          </button>
        ))}

        <select
          aria-label={t("zenginBaslik")}
          onMouseDown={(e) => e.stopPropagation()}
          onChange={(e) => calistir(KOMUT_BASLIK, e.target.value)}
          className="odak-ic rounded px-1 py-1"
          style={{ fontSize: "var(--yz-fs-xs)", background: "var(--yz-metal-2)", color: "var(--yz-text)" }}
        >
          {BASLIKLAR.map((b) => (
            <option key={b} value={b}>
              {b.toUpperCase()}
            </option>
          ))}
        </select>

        <select
          aria-label={t("zenginYaziTipi")}
          onChange={(e) => calistir(KOMUT_FONT, e.target.value)}
          className="odak-ic rounded px-1 py-1"
          style={{ fontSize: "var(--yz-fs-xs)", background: "var(--yz-metal-2)", color: "var(--yz-text)" }}
        >
          {FONTLAR.map((f) => (
            <option key={f} value={f}>
              {f}
            </option>
          ))}
        </select>

        <select
          aria-label={t("zenginBoyut")}
          onChange={(e) => calistir(KOMUT_BOYUT, e.target.value)}
          className="odak-ic rounded px-1 py-1"
          style={{ fontSize: "var(--yz-fs-xs)", background: "var(--yz-metal-2)", color: "var(--yz-text)" }}
        >
          {BOYUTLAR.map((b) => (
            <option key={b} value={b}>
              {b}
            </option>
          ))}
        </select>

        <button
          type="button"
          title={t("zenginGorsel")}
          aria-label={t("zenginGorsel")}
          onMouseDown={(e) => e.preventDefault()}
          onClick={() => {
            // GORSEL URL ILE EKLENIR: dosya yukleme akisi ayri bir
            // ozelliktir (presign + depo) ve e-posta istemcilerinin cogu
            // gomulu gorseli zaten ENGELLER. URL, bugun calisan tek yol.
            const url = window.prompt(t("zenginGorselUrl"));
            if (url) calistir(KOMUT_GORSEL, url);
          }}
          className="odak-ic rounded px-2 py-1"
          style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
        >
          🖼
        </button>
      </div>

      <div
        ref={kutuRef}
        contentEditable
        suppressContentEditableWarning
        role="textbox"
        aria-multiline="true"
        aria-label={etiket}
        tabIndex={0}
        onFocus={() => setOdakli(true)}
        onBlur={() => setOdakli(false)}
        onInput={() => onDegisti(kutuRef.current?.innerHTML ?? BOS)}
        className="odak-ic min-h-40 overflow-auto p-3"
        style={{
          borderBottomLeftRadius: "var(--yz-radius-btn)",
          borderBottomRightRadius: "var(--yz-radius-btn)",
          border: odakli ? KENAR_ODAK : KENAR_NORMAL,
          background: "var(--yz-metal-1)",
          color: "var(--yz-text)",
          fontSize: "var(--yz-fs-sm)",
        }}
      />
    </div>
  );
}
