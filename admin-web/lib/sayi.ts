// (P55) PARA OLMAYAN SAYILAR — Turkce yazim.
//
// `lib/money.ts` parayi kurus tam sayisi olarak tasir ve kendi bicimini
// kurar. Ama panelde para OLMAYAN ondalik sayilar da var (metrekare) ve
// onlar sunucudan JSON `number` olarak gelir: `120.5`. Ekrana oldugu gibi
// yazmak, Turkce'de NOKTANIN BINLIK AYIRICI olmasi yuzunden okuyani
// yaniltiyordu — P47'de tam bu sinif parada bulunmustu (`5000.00`).
//
// GRUPLAMA TEK YERDE: `binlikAyir` burada tanimlidir ve `money.ts` bunu
// ithal eder. Iki kopya tutmak, birinin duzeltilip digerinin unutulmasi
// demekti (P53'te numaralandirma haritalarinda tam bunun bedeli olculdu).

/** Uc haneli gruplama — `toLocaleString` KULLANILMAZ.
 *
 * (P48) `toLocaleString("tr-TR")` ICU verisine baglidir: kucuk-ICU ile
 * derlenmis bir Node/tarayicida `en-US`a duser ve `5,000` verir. Uc haneli
 * gruplama dilden bagimsiz basit bir kuraldir; ICU'ya bagimli olmak kazanci
 * olmayan bir ortam riski almakti.
 */
export function binlikAyir(tamsayi: number): string {
  const s = String(tamsayi);
  let out = "";
  for (let i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 === 0) out += ".";
    out += s[i];
  }
  return out;
}

/** `120.5` -> `"120,5"`, `1250` -> `"1.250"`, `null` -> `"—"`.
 *
 * ONDALIK BASAMAK SABITLENMEZ: metrekare `120` ise `"120,00"` yazmak
 * olculmemis bir hassasiyet gostermek olurdu. Sondaki sifirlar atilir.
 */
export function sayiBicimi(
  deger: number | null | undefined,
  bosluk = "—",
): string {
  if (deger == null || !Number.isFinite(deger)) return bosluk;
  const neg = deger < 0;
  const abs = Math.abs(deger);
  const tam = Math.floor(abs);
  // Ondalik kismi METINDEN alinir: `(abs - tam)` float artigi uretir
  // (0.1 + 0.2 sinifi) ve `120,50000000000001` gibi ciktilar verirdi.
  const metin = String(abs);
  const nokta = metin.indexOf(".");
  const ondalik = nokta === -1 ? "" : metin.slice(nokta + 1).replace(/0+$/, "");
  return `${neg ? "-" : ""}${binlikAyir(tam)}${ondalik ? `,${ondalik}` : ""}`;
}

/** Ayristirma sonucu: sayi, BOS (alan temizlenmek isteniyor) ya da GECERSIZ.
 *
 * UCUNU AYIRMAK ZORUNLUYDU: eski `numOrNull` hem bos girdiye hem de
 * `"120,5"` gibi ayristirilamayan girdiye `null` donuyordu ve cagiran
 * ikisini de "alani temizle" diye yorumluyordu. Yani Turkce yazimla
 * metrekare yazan kullanici, alani SESSIZCE SILDIRIYORDU.
 */
export type SayiSonuc =
  | { tur: "sayi"; deger: number }
  | { tur: "bos" }
  | { tur: "gecersiz" };

/** `"120,5"` ve `"120.5"` -> 120.5; `"1.250"` -> 1250; `""` -> bos.
 *
 * Kural `money.ts`teki ayirici kuralinin AYNISIDIR (virgul varsa nokta
 * binliktir; virgul yoksa tek nokta + en fazla iki hane ondaliktir) —
 * kullanici iki alanda ayni yazimi kullanabilmeli.
 */
export function sayiCoz(girdi: string): SayiSonuc {
  const s = girdi.trim();
  if (s === "") return { tur: "bos" };
  if (/\s/.test(s)) return { tur: "gecersiz" };

  const neg = s.startsWith("-");
  const govde = neg ? s.slice(1) : s;

  let tam: string;
  let ondalik = "";
  if (govde.includes(",")) {
    const parcalar = govde.split(",");
    if (parcalar.length !== 2 || parcalar[0] === "" || parcalar[1] === "") {
      return { tur: "gecersiz" }; // `120,` ya da `,5` — yarim giris
    }
    tam = parcalar[0].replace(/\./g, "");
    ondalik = parcalar[1];
  } else {
    const son = govde.lastIndexOf(".");
    if (son === govde.length - 1 && son !== -1) return { tur: "gecersiz" };
    if (son === 0) return { tur: "gecersiz" };
    if (son !== -1 && govde.indexOf(".") === son && govde.length - son - 1 <= 2) {
      tam = govde.slice(0, son);
      ondalik = govde.slice(son + 1);
    } else {
      tam = govde.replace(/\./g, "");
    }
  }
  if (!/^\d+$/.test(tam) || !/^\d*$/.test(ondalik)) return { tur: "gecersiz" };
  const deger = Number(`${tam}.${ondalik === "" ? "0" : ondalik}`);
  if (!Number.isFinite(deger)) return { tur: "gecersiz" };
  return { tur: "sayi", deger: neg ? -deger : deger };
}
