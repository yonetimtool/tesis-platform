// (P53) HAM TEL DEGERI EKRANDA — sinif kilidi.
//
// Sunucu numaralandirmalari tel degeriyle doner (`basarili`, `zimmetli`,
// `kacirilan_tur`). Bir JSX dugumunde bunu OLDUGU GIBI yazmak iki hataydi:
// kullanici alt cizgili teknik jeton goruyordu ve dil degistirdiginde
// hicbir sey degismiyordu. P51 bunu bildirimler sayfasinda buldu; P53
// supurmesi ayni sizintiyi BES yerde daha buldu — panoda, aidatta,
// demirbasta, tur raporunda ve daire detayinda.
//
// Kilit, numaralandirma tasidigi BILINEN alan adlarini hedefler. Serbest
// metin alanlari (`ad`, `mesaj`, `kategori_ad`) kapsam disidir: onlar
// zaten kullanicinin yazdigi metindir ve cevrilmez.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

// Sunucu semasinda numaralandirma olan alan adlari.
const ENUM_ALANLARI = [
  "durum", "tip", "kategori", "yontem", "kanal", "rol", "oncelik", "gun_tipi",
];

function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (ad.endsWith(".tsx")) cikti.push(yol);
  }
  return cikti;
}

describe("ham numaralandirma taramasi", () => {
  it("tel degeri JSX'e DOGRUDAN yazilmaz", () => {
    // `{x.durum}` / `{x.durum ?? "—"}` gibi dugumler. `t(...)`,
    // `enumAdi(...)` ya da bir bilesene PROP olarak verilenler
    // (`durum={x.durum}`) kapsam disidir — onlar zaten cevirir.
    // (P66/P67) ALAN ADI ONEK ALABILIR. Once liste `actor_rol`u kacirmisti:
    // "rol" yaziliydi ama alan `actor_rol`du ve `\\b` sinirina takilmiyordu.
    // Tek tek onek eklemek, bir sonraki `xxx_durum`u yine kacirmak demekti;
    // kalip artik `(\\w+_)?<alan>` kabul eder.
    const kalip = new RegExp(
      `(^|[^=\\w])\\{\\s*[a-z]\\w*\\.(?:\\w+_)?(${ENUM_ALANLARI.join("|")})\\b\\s*(\\?\\?[^}]*)?\\}`,
    );
    // SABLON DIZGELERI ONCE SILINIR: `t(`mesajDurum_${g.durum}`)` ve
    // `key={`${a.tip}-...`}` bir sizinti DEGILDIR — ilki sozluk anahtari
    // uretir, ikincisi ekrana hic cikmaz. Silmeden aranan kalip bunlari
    // sizinti sayardi ve kilit dogru kodu hata gibi gosterirdi.
    const sablonsuz = (satir: string) => satir.replace(/`[^`]*`/g, "``");
    const sizanlar: string[] = [];
    for (const yol of [...dosyalar("app"), ...dosyalar("components")]) {
      readFileSync(yol, "utf8")
        .split("\n")
        .forEach((satir, i) => {
          if (/HAM-ENUM-TAMAM/.test(satir)) return;
          if (kalip.test(sablonsuz(satir))) {
            sizanlar.push(`${yol}:${i + 1} ${satir.trim()}`);
          }
        });
    }
    expect(sizanlar).toEqual([]);
  });
});
