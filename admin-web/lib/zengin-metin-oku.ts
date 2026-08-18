"use client";

/**
 * (P170) ZENGIN METNI GUVENLE GOSTERME — `dangerouslySetInnerHTML` YOK.
 *
 * =========================================================================
 * NEDEN BU DOSYA VAR: BIR REGRESYON DUZELTMESI
 * =========================================================================
 * "Yasal Metinler" ekrani ilk yazildiginda govdeyi
 * `dangerouslySetInnerHTML` ile basiyordu. Bu, depoda IKI YERDE ACIKCA
 * yazilmis bir karari bozuyordu:
 *
 *   * `components/ZenginMetin.tsx` dosya basi: "Bu editor yoneticinin
 *     yazdigi HTML'i uretir... Panelde geri gosterilirken
 *     `dangerouslySetInnerHTML` KULLANILMAZ."
 *   * mobil `yasal_metinler_screen.dart`: "HTML'i yorumlamak, yoneticinin
 *     yazdigi isaretlemeyi CALISTIRMAK olurdu."
 *
 * =========================================================================
 * NEDEN GERCEKTEN TEHLIKELI (yetkili yaziyor olsa bile)
 * =========================================================================
 * Govde `contenteditable` uzerinden uretiliyor ve oraya HTML YAPISTIRILABILIR.
 * `<script>` `innerHTML` ile calismaz, ama `<img onerror>`, `<svg onload>`,
 * `<iframe>` ve `javascript:` baglantilari CALISIR.
 *
 * Sunucu govdeyi oldugu gibi sakliyor ve bu metin TESISTEKI HERKESE
 * gosteriliyor: sakin, personel, denetci. Yani yuksek yetkili bir hesabin
 * (ya da o hesabi ele geciren birinin) yazdigi bir satir, BASKA
 * kullanicilarin oturumunda kod calistirabilirdi. Yayinci yetkili olsa da
 * BASKASI ADINA is yapmak onun yetkisi degildir.
 *
 * =========================================================================
 * COZUM: METNE CEVIR — TEMIZLEME KUTUPHANESI DEGIL
 * =========================================================================
 * `DOMParser` + `text/html` ATIL bir belge uretir: betik calismaz, `onerror`
 * tetiklenmez, ag istegi gitmez. Cikan sey metindir; enjeksiyon YUZEYI YOK.
 *
 * TEMIZLEYICI (DOMPurify) BILINCLI OLARAK SECILMEDI:
 *   * Sorunun KOKU sunucunun govdeyi denetlemeden saklamasi. Istemci
 *     temizleyicisi bunu duzeltmez, uzerini orter — ve mobil ayni govdeyi
 *     bagimsiz cizdigi icin orada korumasiz kalirdi.
 *   * Dogru kalici cozum YAZMA ANINDA, denetlenmis bir kutuphaneyle
 *     (`bleach`/`nh3`) beyaz liste uygulamak. O bir arka uc karari ve
 *     BU TURUN KAPSAMINDA DEGIL; raporda adiyla birakiliyor.
 *
 * BEDELI: kalin/madde/baslik gibi bicimlendirme web'de KAYBOLUR. Metnin
 * kendisi ve satir yapisi korunur; mobil zaten duz metin cizyordu, yani
 * iki yuzey artik AYNI seyi gosteriyor.
 */

/** Sonrasina satir sonu konacak blok ogeler. */
const BLOK = new Set([
  "P", "DIV", "LI", "UL", "OL", "BR", "TR", "SECTION", "ARTICLE",
  "H1", "H2", "H3", "H4", "H5", "H6", "BLOCKQUOTE", "PRE", "HR",
]);

/**
 * HTML govdeyi, satir yapisini koruyarak DUZ METNE cevirir.
 *
 * Sunucuda `DOMParser` yoktur; orada govde ZATEN cizilmiyor (veri
 * istemcide cekiliyor) ama kanca yine de guvenli tarafa duser.
 */
export function zenginMetniOku(html: string): string {
  if (typeof DOMParser === "undefined") return html;

  const belge = new DOMParser().parseFromString(html, "text/html");
  const parcalar: string[] = [];

  const gez = (dugum: Node): void => {
    // METIN DUGUMU: tek gercek icerik kaynagi.
    if (dugum.nodeType === 3) {
      parcalar.push(dugum.nodeValue ?? "");
      return;
    }
    if (dugum.nodeName === "BR") {
      parcalar.push("\n");
      return;
    }
    // BETIK VE STIL ICERIGI ATILIR: metin dugumu olarak gorunurler ama
    // okunacak bir sey degil, KOD'durlar.
    if (dugum.nodeName === "SCRIPT" || dugum.nodeName === "STYLE") return;

    dugum.childNodes.forEach(gez);
    if (BLOK.has(dugum.nodeName)) parcalar.push("\n");
  };

  gez(belge.body);
  // Ust uste bosluklar TEK bos satira iner: `<div><p>` gibi ic ice
  // bloklar aksi halde metni delik desik gosterirdi.
  return parcalar.join("").replace(/\n{3,}/g, "\n\n").trim();
}
