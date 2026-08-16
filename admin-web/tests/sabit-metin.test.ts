// TUR 47 — SABIT (cevrilmemis) METIN TARAMASI.
//
// Onceki taramalar TURKCE'YE OZGU HARF (ğ/ı/ş/İ) ya da anahtar kelime
// ariyordu. Bu yuzden "Tahakkuklar", "Tutar (TL)", "Blok etiketi", "Kat",
// "sil", "Temizlik", "Kontrol", "CSV indir", "var"/"yok" gibi ONLARCA metin
// yillarca gorulmedi — hicbiri TR'ye ozgu harf tasimiyor. Tur 41/42/44'te
// bunlar TEK TEK, o sayfa surulunce ortaya cikti.
//
// Bu tarama KARAKTERE degil KONUMA bakar: JSX metin dugumu ve kullaniciya
// gorunen oznitelikler (`label`, `title`, `placeholder`, `hint`,
// `aria-label`, `alt`...) DIZGE SABITI olamaz; `t("anahtar")` uzerinden
// gelmelidir. Dil bilgisinden bagimsizdir, dolayisiyla Ingilizce sabitleri
// de yakalar.
import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

/** Cevrilmesi GEREKMEYEN degerler: marka, teknik jeton, ornek/bicim. */
const IZINLI =
  /^(Yönetiyor|yonetio|yönetiyor|NFC|CSV|TL|TRY|ID|URL|API|SMS|QR|GPS|MinIO|JSON|HTTP|app_user|HH:MM|https?:\/\/\.\.\.|—|·|✓|→|[\d.,:/+-]+|[A-Z]-\d+|.{0,1})$/;

/** Kullaniciya GORUNEN oznitelikler. */
const GORUNEN_PROP =
  "label|title|placeholder|hint|baslik|subtitle|description|detail|aria-label|alt|emptyText|boslukMetni";
const OZNITELIK = new RegExp(`\\b(${GORUNEN_PROP})="([^"]{2,80})"`, "g");

/** TUR 59 — SUSLU PARANTEZLI dizge sabiti: `detail={"..."}`,
 * `label={'...'}`, `` detail={`${n} plan penceresi`} ``.
 *
 * Panonun dort KPI etiketi (`{turlar.length} plan penceresi`, `tur yok`,
 * `ilgilenilmeli`, `{n} turdan`) tam bu kalipla yazilmisti; SOZLUK ANAHTARLARI
 * ZATEN VARDI ve yedi dile cevrilmisti ama sayfa hicbirini kullanmiyordu.
 * Yani panonun amiral sayfasi alti dilde Turkce gosteriyordu ve ne panel
 * surusleri (TR sizintisina bakmiyorlar) ne de tur 47'nin taramasi (yalniz
 * `="..."` bicimine bakiyordu) bunu gordu. */
const IFADE_PROP = new RegExp(
  `\\b(${GORUNEN_PROP})=\\{([^}]*?)(?:"([^"]{2,80})"|'([^']{2,80})'|\`([^\`]{2,80})\`)`,
  "g",
);

/** JSX metin dugumu: `>metin<` (ifade `{...}` degil).
 *
 * TUR 59 DUZELTMESI — `\n` HARIC TUTULMUSTU, yani metin kendi satirindaysa
 * (Prettier uzun butonlari boyle sarar) tarama onu HIC GORMEDI:
 *
 *     <button ...>
 *       Okundu          <- bu satirda ne `>` ne `<` var
 *     </button>
 *
 * Panelde tam bu kalipla kalmis bir TR sizintisi vardi ve tur 59'un "kalin
 * yazi" surusu onu ALMANCA sayfada gosterdi. Simdi tarama satir satir degil
 * DOSYA BOYUNCA yapiliyor; satir numarasi eslesme konumundan hesaplanir. */
const METIN = />([^<>{}]{2,80})</g;

/** TUR 59 — KARISIK metin dugumu: metin + ifade ayni dugumde.
 *
 *     <span>Toplam {total} · {bas}-{son}</span>
 *
 * `METIN` suslu parantez GORDUGU ICIN bunu atliyordu; oysa "Toplam" cevrilmemis
 * bir metindir ve `ortakSayfalayici` anahtari ZATEN vardi. Panelin bildirim
 * sayfasi bu yuzden alti dilde "Toplam" yaziyordu. */
const KARISIK = [/>([^<>{}]{2,80})\{/g, /\}([^<>{}]{2,80})</g];

/** TUR 61 — UCLU IFADEDEKI dizge sabiti: `{kosul ? t("x") : "TR metin"}`.
 *
 * Tur 59 bu kalibi OZNITELIKLERDE (`label={...}`) yakaliyordu, JSX COCUGU
 * olarak degil. `/tenants/[id]` sayfasinda dort sizinti bu bicimde duruyordu
 * ("kurulum bekliyor", "aktif", "pasif", "parola belirlendi"). TR sizinti
 * SURUSU de kacirmisti: sozlukte "Aktif" buyuk harfle, sayfada "aktif" —
 * birebir eslesme olmadigi icin gorunmedi (surus artik buyuk/kucuk harf
 * duyarsiz karsilastiriyor). */
const UCLU = /([?:])\s*("([^"]{2,80})"|'([^']{2,80})')/g;

/** Ucluda cevrilmesi GEREKMEYEN teknik degerler.
 *
 * (P132) Vurgu ADLARI (`blue`/`green`/`orange`/`purple`) buraya eklendi:
 * bunlar tasarim sisteminin KIMLIKLERIDIR (`Vurgu` tipi), ekranda gorunen
 * metin degil. `red` zaten listedeydi; kalan dordunun disarida kalmasi
 * tutarsizlikti. */
const UCLU_TEKNIK =
  // (P154) `button|submit`: HTML `type` oznitelik degerleri. `GET|POST`
  // ile AYNI sinif — kullaniciya gorunen metin degil, protokol/teknik
  // sabit. Modal'in alt cubugu `kaydet` verilmisse dugme, verilmemisse
  // form gonderimi olur ve secim bir ucluyle yapilir.
  //
  // (P154 / Asama 7.2) `password|text`: yine `type` degerleri —
  // `ParolaAlani` goster/gizle icin ikisi arasinda gecer. Gorunen metin
  // olmadiklari icin cevrilecek bir sey yok.
  /^(rtl|ltr|asc|desc|GET|POST|PATCH|PUT|DELETE|button|submit|password|text|true|false|light|dark|auto|none|row|col|small|medium|large|default|platform|tenant|security|resident|yonetici|temizlik|kontrol|emerald|teal|amber|red|slate|indigo|blue|green|orange|purple|application[/]json|page|[a-z_]+_[a-z_]+)$/;

/** TAILWIND sinif dizgesi mi? Uclularin cogu `className` secimidir:
 * `kosul ? "bg-ink text-white" : "text-slate-600"`. Bunlar metin DEGIL. */
const SINIF_DIZGESI = /^[A-Za-z0-9\s:\/\[\]().%-]+$/;
function sinifMi(s: string): boolean {
  return SINIF_DIZGESI.test(s) && /[-:]/.test(s);
}


/** Yorumlari sil: yorum metni Turkce olabilir ve TARAMA DISIDIR.
 * (`https://` gibi protokol ciftini korumak icin `//` yalniz basi ya da
 * bosluktan sonra geldiginde yorum sayilir.) */
function yorumsuz(s: string): string {
  return s
    .replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ""))
    .split("\n")
    .map((l) => l.replace(/(^|\s)\/\/.*$/, "$1"))
    .join("\n");
}

function harfVar(s: string): boolean {
  return /[A-Za-zÇĞİÖŞÜçğıöşü]{2}/.test(s);
}

/**
 * (P137) Bir kaynaktaki cevrilmemis sabit metinler.
 *
 * NEDEN AYRI ISLEV: bu dosya "su yok" diyor ve yokluk iddialari desen
 * bozulunca da dogru cikar. P136 "tarama hic dosya gormedi" vakumunu
 * kapatti; bu, ikinci turu — "dosyalar okundu ama desen hicbir sey
 * eslestirmedi". Islev ayri oldugu icin SENTETIK bir orneğe kosulabiliyor
 * ve desenin gercekten atesledigi olculebiliyor (asagidaki kontroller).
 */
export function sabitMetinler(yol: string, dosyaMetni: string): string[] {
  const bulgular: string[] = [];
  {
    {
      const kaynak = yorumsuz(dosyaMetni);
      // Dosya boyunca metin dugumleri (cok satirli olanlar dahil).
      for (const m of kaynak.matchAll(METIN)) {
        const t = m[1].trim();
        // Cok satirli JSX ifadelerinin PARCASI (`(a.zaman`, `=== 1 && i`)
        // dizge sabiti degildir: operator/nokta iceren parcalari ele.
        if (!harfVar(t) || IZINLI.test(t)) continue;
        if (/[(){}[\]=&|!<>+*/]|\w\.\w|["`;]/.test(t)) continue;
        const satir = kaynak.slice(0, m.index).split("\n").length;
        if (kaynak.split("\n")[satir - 1]?.includes("eslint")) continue;
        bulgular.push(`${yol}:${satir}  ${t}`);
      }
      for (const kalip of KARISIK) {
        for (const m of kaynak.matchAll(kalip)) {
          const t = m[1].trim();
          if (!harfVar(t) || IZINLI.test(t)) continue;
          if (/[(){}[\]=&|!<>+*/]|\w\.\w|["`;,]/.test(t)) continue;
          const parcalar = m[1].split("\n").map((x) => x.trim()).filter(Boolean);
          if (parcalar.length !== 1) continue; // birden fazla parca = kod
          if (/\b(const|let|var|function|return|type|interface|import|export|class|new|await|Record|Promise)\b/.test(t)) continue;
          if (/:\s*[A-Za-z]/.test(t)) continue; // tip anotasyonu
          const satir = kaynak.slice(0, m.index).split("\n").length;
          bulgular.push(`${yol}:${satir}  ${t}`);
        }
      }
      const satirlar = kaynak.split("\n");
      satirlar.forEach((l, i) => {
        if (l.includes("eslint")) return;
        for (const m of l.matchAll(OZNITELIK)) {
          const t = m[2].trim();
          if (!harfVar(t) || IZINLI.test(t)) continue;
          bulgular.push(`${yol}:${i + 1}  ${m[1]}="${t}"`);
        }
        for (const m of l.matchAll(UCLU)) {
          const t = (m[3] ?? m[4] ?? "").trim();
          if (!harfVar(t) || IZINLI.test(t) || UCLU_TEKNIK.test(t)) continue;
          if (sinifMi(t)) continue;
          // URL/sorgu parcasi metin degildir: `?cascade=true`, `&x=1`.
          if (/^[?&]/.test(t) || /=/.test(t)) continue;
          // (P132) TIP BILDIRIMI UCLU DEGILDIR. `as?: "div" | "section"`
          // gibi OPSIYONEL BIR OZELLIGIN dizge-birlesim tipi, `?:` ikilisi
          // yuzunden uclu sanilıyordu. Gercek bir uclunun `?` ile `:`
          // arasinda bir IFADE vardir; burada `?` hemen `:` ile bitisiktir
          // ya da satir bir tip bildirimidir (`ad?: "a" | "b";`).
          if (/\w\s*\?\s*:/.test(l) && /;\s*$/.test(l.trim())) continue;
          // `t("anahtar")` argumani degil, DOGRUDAN dizge olmali.
          const onceki = l.slice(0, m.index);
          if (/\b(t|metin|ceviri)\s*\($/.test(onceki.trimEnd())) continue;
          // Nesne/dizi anahtari ya da tip birlesimi olabilir: `{ ad: "x" }`.
          // TUR 62 DUZELTMESI: bu kontrol ONCE her iki operatore uygulaniyordu
          // ve uclunun ILK dalini (`kosul ? "TR"`) HER ZAMAN atliyordu —
          // cunku oncesinde daima bir tanimlayici (`it.aktif`) durur. Sonuc:
          // `{it.aktif ? "Evet" : "—"}` gibi sizintilar gorunmuyordu (ikinci
          // dal "—" izinli oldugu icin hic bulgu cikmiyordu). `?` oncesinde
          // anahtar OLAMAZ; kontrol yalniz `:` icin anlamlidir.
          if (
            m[1] === ":" &&
            /[\w\]]\s*$/.test(onceki.replace(/["'][^"']*["']$/, "").trimEnd())
          ) {
            continue;
          }
          bulgular.push(`${yol}:${i + 1}  ucluda sabit: ${t}`);
        }
        for (const m of l.matchAll(IFADE_PROP)) {
          // Dizge `t(...)`/`metin(...)` ARGUMANI ise anahtardir, metin degil.
          if (/\b(t|metin|ceviri)\s*\(/.test(m[2])) continue;
          // `${...}` yer tutucularini cikar: kalan METIN cevrilmeli.
          const ham = (m[3] ?? m[4] ?? m[5] ?? "").replace(/\$\{[^}]*\}/g, "").trim();
          if (!harfVar(ham) || IZINLI.test(ham)) continue;
          bulgular.push(`${yol}:${i + 1}  ${m[1]}={...${ham}...}`);
        }
      });
    }
  }
  return bulgular;
}

describe("sabit metin taramasi (tur 47)", () => {
  it("JSX metinleri ve gorunen oznitelikler t() uzerinden gelir", () => {
    const bulgular: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      bulgular.push(...sabitMetinler(yol, readFileSync(yol, "utf8")));
    }
    expect(
      bulgular,
      `Cevrilmemis sabit metin (t("...") kullanin):\n${bulgular.join("\n")}`,
    ).toEqual([]);
  });

  // (P137) POZITIF KONTROL — desen GERCEKTEN atesliyor mu.
  //
  // Ustteki test BOS liste bekler. Desen bozulursa (bu oturumda koyu tema
  // kilidinde tam bu oldu: bir kacis hatasi regex'e backspace koymustu)
  // liste yine bos kalir ve test GECER. Bu blok sentetik bir sizinti
  // uretip yakalandigini olcer.
  it("POZITIF KONTROL: cevrilmemis JSX metni YAKALANIR", () => {
    expect(sabitMetinler("s.tsx", "<p>Kaydedildi</p>")).toHaveLength(1);
    expect(sabitMetinler("s.tsx", '<input placeholder="Ad soyad" />')).toHaveLength(1);
  });

  it("POZITIF KONTROL: t() uzerinden gelen metin RAHAT birakilir", () => {
    // Kilit IKI YONDE sinanir: yanlisi yakaliyor mu, DOGRUYU rahat
    // birakiyor mu. Yalniz ilki olculse "her seye sizinti" diyen bir
    // desen de gecerdi.
    expect(sabitMetinler("s.tsx", '<p>{t("ortakKaydedildi")}</p>')).toEqual([]);
    expect(sabitMetinler("s.tsx", '<input placeholder={t("ortakAdSoyad")} />')).toEqual([]);
  });
});
