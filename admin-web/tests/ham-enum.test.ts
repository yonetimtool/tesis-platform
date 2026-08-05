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

import { taranacakDosyalar } from "./tarama";

// Sunucu semasinda numaralandirma olan alan adlari.
const ENUM_ALANLARI = [
  "durum", "tip", "kategori", "yontem", "kanal", "rol", "oncelik", "gun_tipi",
];


// (P66/P67) ALAN ADI ONEK ALABILIR. Once liste `actor_rol`u kacirmisti:
// "rol" yaziliydi ama alan `actor_rol`du ve `\b` sinirina takilmiyordu.
// Tek tek onek eklemek, bir sonraki `xxx_durum`u yine kacirmak demekti;
// kalip artik `(\w+_)?<alan>` kabul eder.
const KALIP = new RegExp(
  `(^|[^=\\w])\\{\\s*[a-z]\\w*\\.(?:\\w+_)?(${ENUM_ALANLARI.join("|")})\\b\\s*(\\?\\?[^}]*)?\\}`,
);

// SABLON DIZGELERI ONCE SILINIR: `t(`mesajDurum_${g.durum}`)` ve
// `key={`${a.tip}-...`}` bir sizinti DEGILDIR — ilki sozluk anahtari
// uretir, ikincisi ekrana hic cikmaz. Silmeden aranan kalip bunlari
// sizinti sayardi ve kilit dogru kodu hata gibi gosterirdi.
const sablonsuz = (satir: string) => satir.replace(/`[^`]*`/g, "``");

/**
 * Bir kaynaktaki HAM enum sizintilari.
 *
 * (P137) Tespit ayri isleve cikarildi ki sentetik ornekle iki yonde
 * sinanabilsin: desen bozulursa liste bos kalir ve `toEqual([])` GECER.
 */
export function hamEnumSizintilari(yol: string, kaynak: string): string[] {
  const sizanlar: string[] = [];
  kaynak.split("\n").forEach((satir, i) => {
    if (/HAM-ENUM-TAMAM/.test(satir)) return;
    if (KALIP.test(sablonsuz(satir))) {
      sizanlar.push(`${yol}:${i + 1} ${satir.trim()}`);
    }
  });
  return sizanlar;
}

describe("ham numaralandirma taramasi", () => {
  it("tel degeri JSX'e DOGRUDAN yazilmaz", () => {
    // `{x.durum}` / `{x.durum ?? "—"}` gibi dugumler. `t(...)`,
    // `enumAdi(...)` ya da bir bilesene PROP olarak verilenler
    // (`durum={x.durum}`) kapsam disidir — onlar zaten cevirir.
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      sizanlar.push(...hamEnumSizintilari(yol, readFileSync(yol, "utf8")));
    }
    expect(sizanlar).toEqual([]);
  });

  // (P137) POZITIF KONTROL — desen GERCEKTEN atesliyor mu.
  it("POZITIF KONTROL: ham enum YAKALANIR", () => {
    expect(hamEnumSizintilari("s.tsx", "<span>{x.durum}</span>")).toHaveLength(1);
    // Onekli alan da yakalanmali (P66'daki `actor_rol` kacigi).
    expect(hamEnumSizintilari("s.tsx", "<span>{a.actor_rol}</span>")).toHaveLength(1);
  });

  it("POZITIF KONTROL: cevrilen ve PROP olan kullanim RAHAT birakilir", () => {
    // Kilit iki yonde sinanir; yalniz yakalama olculse "her seye sizinti"
    // diyen bir desen de gecerdi.
    expect(hamEnumSizintilari("s.tsx", "<span>{enumAdi(t, TUR_DURUM, x.durum)}</span>")).toEqual([]);
    expect(hamEnumSizintilari("s.tsx", "<Chip durum={x.durum} />")).toEqual([]);
    expect(hamEnumSizintilari("s.tsx", "key={`${a.tip}-1`}")).toEqual([]);
  });
});
