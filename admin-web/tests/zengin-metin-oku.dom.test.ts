// @vitest-environment jsdom
// (P170) YASAL METIN GOVDESI HTML OLARAK BASILMAZ — ENJEKSIYON KILIDI.
//
// =========================================================================
// KILITLENEN KUSUR
// =========================================================================
// "Yasal Metinler" ekrani ilk yazimda govdeyi `dangerouslySetInnerHTML`
// ile basiyordu. Govde `contenteditable` uzerinden uretiliyor (oraya HTML
// YAPISTIRILABILIR), sunucu onu oldugu gibi sakliyor ve metin TESISTEKI
// HERKESE gosteriliyor — sakin, personel, denetci.
//
// Yani yuksek yetkili bir hesabin yazdigi tek satir, BASKA kullanicilarin
// oturumunda kod calistirabilirdi. Yayinci yetkili olsa da BASKASI ADINA
// is yapmak onun yetkisi degildir.
//
// OLCULEN: yaygin vektorlerin hicbiri CANLI KALMIYOR ve metin okunur
// kaliyor (yoksa "guvenli ama kullanilmaz" bir ekran olurdu).
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

import { zenginMetniOku } from "@/lib/zengin-metin-oku";

describe("zenginMetniOku", () => {
  it("METIN KORUNUR ve blok yapisi satira doner", () => {
    const cikti = zenginMetniOku(
      "<h2>Aydınlatma</h2><p>Kişisel verileriniz</p><p>işlenir.</p>",
    );
    expect(cikti).toContain("Aydınlatma");
    expect(cikti).toContain("Kişisel verileriniz");
    expect(cikti).toContain("işlenir.");
    // Bloklar birlesip tek satira YAPISMAZ.
    expect(cikti).toContain("\n");
  });

  it("`<img onerror>` CANLI KALMAZ", () => {
    const cikti = zenginMetniOku('<img src=x onerror="alert(1)">Metin');
    expect(cikti).not.toContain("onerror");
    expect(cikti).not.toContain("alert");
    expect(cikti).toContain("Metin");
  });

  it("`<svg onload>` ve `<iframe>` CANLI KALMAZ", () => {
    const cikti = zenginMetniOku(
      '<svg onload="alert(1)"></svg><iframe src="javascript:alert(2)"></iframe>Son',
    );
    expect(cikti).not.toContain("onload");
    expect(cikti).not.toContain("javascript:");
    expect(cikti).toContain("Son");
  });

  it("`<script>` GOVDESI metne SIZMAZ", () => {
    // `innerHTML` ile `<script>` calismaz — ama icerigi METIN olarak
    // gorunurdu ve kullanici yasal metnin ortasinda kod okurdu.
    const cikti = zenginMetniOku("<p>Once</p><script>alert(1)</script><p>Sonra</p>");
    expect(cikti).not.toContain("alert");
    expect(cikti).toContain("Once");
    expect(cikti).toContain("Sonra");
  });

  it("`javascript:` baglantisi TIKLANABILIR bir sey birakmaz", () => {
    const cikti = zenginMetniOku('<a href="javascript:alert(1)">Tıkla</a>');
    // Metin kalir, HEDEF kalmaz: bir `<a>` dugumu hic uretilmedi.
    expect(cikti).toBe("Tıkla");
  });

  it("CIZIM ATIL BELGEDE yapilir — ag istegi ve olay YOK", () => {
    // `DOMParser` + `text/html` atil bir belge uretir: `onerror`
    // tetiklenmez. Burada olculen sey, cagrinin hic patlamamasi ve
    // belgeye HICBIR dugum eklenmemis olmasi.
    const oncekiDugum = document.body.childNodes.length;
    zenginMetniOku('<img src="http://ornek.test/iz.gif" onerror="alert(1)">');
    expect(document.body.childNodes.length).toBe(oncekiDugum);
  });
});

describe("ekran HTML BASMIYOR", () => {
  it("`dangerouslySetInnerHTML` cagrisi YOK", () => {
    const kaynak = readFileSync("components/profil/yasal-metinler.tsx", "utf8");
    // Yorumda GECEBILIR (orada neden kullanilmadigi yaziyor); JSX
    // ozniteligi olarak gecmemeli.
    expect(kaynak).not.toMatch(/dangerouslySetInnerHTML=\{/);
    expect(kaynak).toContain("zenginMetniOku(data.govde)");
  });
});
