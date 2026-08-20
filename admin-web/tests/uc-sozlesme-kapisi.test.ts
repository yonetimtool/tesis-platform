// (P173) BFF'IN CAGIRDIGI HER UC SOZLESMEDE VAR MI — AYNI YOL, AYNI METOT.
//
// =========================================================================
// KILITLENEN KUSUR SINIFI — UCUNCU KEZ CIKMASIN
// =========================================================================
// Ayni sinif iki kez yasandi:
//   * P168: toplu daire olusturmada arayuz bir metotla cagirdi, backend
//     baska metot tanimladi -> 405.
//   * P172 sonrasi: `mesaj-ayarlari` BFF beyaz listesinde YOKTU -> vekil
//     kendi 404'unu dondu; `PUT` ve `POST /test` icin ise Next 405 verdi.
//     Ekran cizili, alanlar bos, "Kaydet" kaydetmiyordu.
//
// IKISINDE DE UC TAKIM YESILDI. Sebep basit: hicbir test BFF ile
// sozlesmeyi KARSILASTIRMIYORDU. Backend testleri backend'e, web testleri
// bilesenlere bakiyor; ARADAKI ESLESME olculmuyordu.
//
// =========================================================================
// BU KAPI NE OLCER
// =========================================================================
//  1. `lib/panel-vekil.ts` beyaz listesindeki her backend yolu sozlesmede
//     TANIMLI mi (okuma -> GET, yazma -> POST/PUT/PATCH'ten en az biri).
//  2. `app/api/**/route.ts` icindeki her `proxyJson`/`proxyBinary` cagrisi
//     — yol ve METOT — sozlesmede var mi.
//  3. Arayuzun cagirdigi her `/api/panel/<ad>` beyaz listede var mi.
//     Ikinci olayin TAM kendisi: ad listede yoksa vekil 404 doner.
//
// NEDEN SOZLESME UZERINDEN: `contracts/openapi.yaml` backend testleriyle
// GERCEK uygulamaya karsi dogrulaniyor (`test_yetki_kapsam`,
// `test_secdef_kapsam`). Yani sozlesmede olan sey backend'de de vardir;
// buradaki karsilastirma zinciri tamamlar.
//
// OLCMEZ: govde semalarinin uyumu. O ayri bir soru ve bu kapinin
// kapsaminda degil — ama 404/405 sinifi tamamen kapanir.
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { parse } from "yaml";

import { OKUMA, YAZMA } from "@/lib/panel-vekil";

import { taranacakKaynaklar } from "./tarama";

/** `contracts/openapi.yaml`taki yol -> tanimli metotlar. */
function sozlesmeYollari(): Map<string, Set<string>> {
  const ham = readFileSync("../contracts/openapi.yaml", "utf8");
  const cikti = new Map<string, Set<string>>();
  let suanki: string | null = null;
  for (const satir of ham.split("\n")) {
    // Yol girisleri IKI BOSLUKLA girintili ve `/` ile baslar.
    const yol = /^ {2}(\/[^\s:]*):\s*$/.exec(satir);
    if (yol) {
      suanki = yol[1];
      cikti.set(suanki, new Set());
      continue;
    }
    // Ust duzey bir baslik (girintisiz) yol bolumunu bitirir.
    if (/^\S/.test(satir)) suanki = null;
    if (!suanki) continue;
    const metot = /^ {4}(get|post|put|patch|delete):\s*$/.exec(satir);
    if (metot) cikti.get(suanki)!.add(metot[1].toUpperCase());
  }
  return cikti;
}

const SOZLESME = sozlesmeYollari();

/** (5) icin sozlesmenin TAM agaci — sema karsilastirmasi ozellik ister. */
const SOZLESME_HAM = parse(
  readFileSync("../contracts/openapi.yaml", "utf8"),
) as { paths?: Record<string, unknown>; components?: { schemas?: Record<string, unknown> } };

/** `/kargo/{id}` gibi degiskenli yollari kalipla esler. */
function sozlesmedeVar(yol: string, metot: string): boolean {
  const temiz = yol.split("?")[0];
  for (const [kalip, metotlar] of SOZLESME) {
    if (!metotlar.has(metot)) continue;
    // `{...}` yer tutucusu tek bir segmentle eslesir.
    const desen = new RegExp(
      "^" + kalip.replace(/\{[^}]+\}/g, "[^/]+").replace(/\//g, "\\/") + "$",
    );
    if (desen.test(temiz)) return true;
  }
  return false;
}

describe("sozlesme okunabiliyor", () => {
  it("yol tablosu BOS DEGIL — kapi sessizce yesil kalmasin", () => {
    // Yokluk iddialari bos kume uzerinde her zaman dogrudur. Ayristirici
    // bozulursa kapi hicbir sey olcmeden gecer; bu iddia onu engeller.
    expect(SOZLESME.size).toBeGreaterThan(150);
    expect(sozlesmedeVar("/mesaj-ayarlari", "GET")).toBe(true);
  });
});

describe("(1) BFF beyaz listesi sozlesmeyle uyumlu", () => {
  it("OKUMA yollarinin hepsi sozlesmede GET olarak var", () => {
    const eksik = Object.entries(OKUMA)
      .filter(([, yol]) => !sozlesmedeVar(yol, "GET"))
      .map(([ad, yol]) => `${ad} -> GET ${yol}`);
    expect(eksik, `sozlesmede yok:\n${eksik.join("\n")}`).toEqual([]);
  });

  it("YAZMA yollarinin hepsi sozlesmede bir YAZMA metoduyla var", () => {
    const eksik = Object.entries(YAZMA)
      .filter(
        ([, yol]) =>
          !["POST", "PUT", "PATCH", "DELETE"].some((m) => sozlesmedeVar(yol, m)),
      )
      .map(([ad, yol]) => `${ad} -> ${yol}`);
    expect(eksik, `sozlesmede yazma ucu yok:\n${eksik.join("\n")}`).toEqual([]);
  });
});

describe("(2) route.ts vekil cagrilari sozlesmede var", () => {
  it("her `proxyJson`/`proxyBinary` yolu+metodu tanimli", () => {
    // Sabit yollar. Sablon degiskeni (`${...}`) iceren yollar `[^/]+`
    // kaliba cevriliyor — sozlesmedeki `{id}` ile ayni sey.
    const cagri =
      /proxy(?:Json|Binary)\(\s*(?:`([^`]*)`|"([^"]*)")\s*,\s*"([A-Z]+)"/g;
    const ihlal: string[] = [];
    for (const [dosya, kaynak] of taranacakKaynaklar(["app/api"], [".ts"])) {
      for (const e of kaynak.matchAll(cagri)) {
        const ham = (e[1] ?? e[2]).split("?")[0];
        const metot = e[3];
        // Sablon degiskenini yer tutucuya cevir.
        const yol = ham.replace(/\$\{[^}]*\}/g, "{x}");
        if (!yol.startsWith("/")) continue; // degiskenle baslayan yol: atla
        // SONDAKI DEGISKEN SORGU DIZESI DE OLABILIR.
        //
        // `proxyJson(\`/me/etkinlik${q}\`, "GET")` — burada `q` bir yol
        // segmenti degil, `?a=b` bicimli bir SORGU. Yer tutucuyu oldugu
        // gibi birakmak `/me/etkinlik{x}` uretir ve sozlesmede
        // bulunamaz. Kapiyi ZAYIFLATMADAN cozum: yol ayirici GELMEDEN
        // biten bir yer tutucu icin, o tutucu OLMADAN da bakilir.
        // Gercek bir eksikte iki bicim de bulunamayacagi icin kapi yine
        // kirilir.
        const sorgusuz = yol.endsWith("{x}") && !yol.endsWith("/{x}")
          ? yol.slice(0, -3)
          : null;
        if (
          !sozlesmedeVar(yol, metot) &&
          !(sorgusuz && sozlesmedeVar(sorgusuz, metot))
        ) {
          ihlal.push(`${dosya}: ${metot} ${yol}`);
        }
      }
    }
    expect(
      ihlal,
      "BFF sozlesmede OLMAYAN bir uc cagiriyor — bu, ekranda 404/405 " +
        `demektir:\n${ihlal.join("\n")}`,
    ).toEqual([]);
  });
});

describe("(4) ARAYUZUN METODU sozlesmeyle uyusuyor", () => {
  it("`/api/panel/<ad>` cagrilarinin metodu backend'de tanimli", () => {
    // =====================================================================
    // (2) BUNU YAKALAYAMAZ — VE BU OLCULDU
    // =====================================================================
    // Genel vekilde (`[kaynak]/route.ts`) yol bir DEGISKENDIR (`yol`),
    // sabit degil; (2) yalniz sabit yollari tariyor. Deney yapildi:
    // vekilin `PUT` cagrisi `POST`a cevrildi ve (2) SESSIZ KALDI.
    //
    // Bu tam olarak P168'in sinifi: arayuz bir metotla cagirdi, backend
    // baska metot tanimladi -> 405, ve uc takim yesildi.
    //
    // Zincir burada uctan uca kapaniyor:
    //   ARAYUZUN METODU -> beyaz listedeki YOL -> SOZLESMEDEKI METOT
    //
    // SABIT COZUMLENIYOR: cagri yerleri cogu zaman `const UC = "..."`
    // kullaniyor. Cozmeseydik en yaygin bicim olcum disinda kalirdi.
    const bilinen = new Map<string, string>([
      ...Object.entries(OKUMA),
      ...Object.entries(YAZMA),
    ]);
    const ihlal: string[] = [];

    for (const [dosya, ham] of taranacakKaynaklar(
      ["app", "components"],
      [".tsx", ".ts"],
    )) {
      if (dosya.includes("app/api/")) continue;

      // Dosya ici sabitleri coz: `const UC = "/api/panel/x"`.
      let kaynak = ham;
      for (const sabit of ham.matchAll(
        /const\s+([A-Za-z_$][\w$]*)\s*=\s*"(\/api\/panel\/[^"]*)"/g,
      )) {
        kaynak = kaynak.replaceAll(sabit[1], `"${sabit[2]}"`);
      }

      const cagrilar: [string, string][] = [];
      // YAZMA: `apiSend(<yol>, "METOT")`.
      for (const e of kaynak.matchAll(
        /apiSend[^(]*\(\s*[`"]([^`"]*\/api\/panel\/[^`"]*)[`"]\s*,\s*"([A-Z]+)"/g,
      )) {
        cagrilar.push([e[1], e[2]]);
      }
      // OKUMA: `useSWR(<yol>, ...)` -> GET.
      for (const e of kaynak.matchAll(
        /useSWR[^(]*\(\s*[`"]([^`"]*\/api\/panel\/[^`"]*)[`"]/g,
      )) {
        cagrilar.push([e[1], "GET"]);
      }

      for (const [yol, metot] of cagrilar) {
        const ad = /\/api\/panel\/([a-z0-9-]+)/.exec(yol)?.[1];
        if (!ad) continue;
        const arka = bilinen.get(ad);
        // Beyaz listede olmayanlar (3)'un isi; burada tekrar bildirilmez.
        if (!arka) continue;
        // ALT KAYNAK: `/api/panel/anketler/${id}` -> `/anketler/{x}`.
        // Kok yola bakmak, alt kaynak cagrilarini yanlislikla ihlal
        // sayardi (olculdu: alti tane).
        const kuyruk = yol
          .split(`/api/panel/${ad}`)[1]
          ?.split("?")[0]
          ?.replace(/\$\{[^}]*\}/g, "{x}") ?? "";
        const tam = `${arka}${kuyruk}`;
        if (!sozlesmedeVar(tam, metot)) {
          ihlal.push(`${dosya}: ${metot} ${yol} -> ${metot} ${tam}`);
        }
      }
    }

    expect(
      ihlal,
      "Arayuz bir metotla cagiriyor, backend o metodu TANIMLAMIYOR — " +
        `ekranda 405 demektir:\n${ihlal.join("\n")}`,
    ).toEqual([]);
  });
});

describe("(3) arayuzun cagirdigi panel kaynaklari beyaz listede", () => {
  it("`/api/panel/<ad>` adlarinin hepsi tanimli", () => {
    // Ikinci olayin TAM kendisi: `mesaj-ayarlari` listede yoktu ve vekil
    // KENDI 404'unu donuyordu — istek sunucuya HIC gitmiyordu, bu yuzden
    // backend log'unda iz de yoktu.
    const desen = /\/api\/panel\/([a-z0-9-]+)/g;
    const bilinen = new Set([...Object.keys(OKUMA), ...Object.keys(YAZMA)]);
    // Kendi `route.ts`i olan ozel yollar (beyaz listeye tabi degil).
    const ozel = new Set(["arama", "dokumanlar", "karar-pdf", "rapor", "uyari-yapildi"]);
    const ihlal = new Set<string>();
    for (const [dosya, kaynak] of taranacakKaynaklar(
      ["app", "components"],
      [".tsx", ".ts"],
    )) {
      if (dosya.includes("app/api/")) continue; // vekilin kendisi
      for (const e of kaynak.matchAll(desen)) {
        const ad = e[1];
        if (bilinen.has(ad) || ozel.has(ad)) continue;
        // AD DINAMIK KURULMUS OLABILIR: `/api/panel/ice-aktarim-${tur}`
        // gibi. Yakalanan parca `ice-aktarim-` olur. Kapiyi
        // ZAYIFLATMADAN cozum: bu bir ONEKTIR ve beyaz listede o onekle
        // baslayan EN AZ BIR kayit olmali. Hicbiri yoksa ihlal —
        // dinamik ad, listede hicbir karsiligi olmayan bir kaynaga
        // gidiyor demektir.
        if (ad.endsWith("-") && [...bilinen].some((k) => k.startsWith(ad))) {
          continue;
        }
        ihlal.add(`${dosya}: ${ad}`);
      }
    }
    expect(
      [...ihlal],
      "Arayuz beyaz listede OLMAYAN bir panel kaynagi cagiriyor — vekil " +
        `404 doner:\n${[...ihlal].join("\n")}`,
    ).toEqual([]);
  });
});

// =========================================================================
// (5) YANIT SEMASI — arayuz, sozlesmenin VAAT ETMEDIGI bir alani okuyor mu
// =========================================================================
// P173'te kurulan kapi YALNIZ yol ve metot dogruluyordu. Bu bolum yanit
// GOVDESINI ekliyor: arayuzun ZORUNLU ilan ettigi her alan, sozlesmenin o
// ucun basarili yanitinda VAAT ETTIGI bir alan olmali.
//
// YON TEK TARAFLI ve bilincli: sozlesmede olup arayuzun okumadigi alan
// SORUN DEGIL (uc daha fazla sey donebilir). Ters yon kusurdur: olmayan
// bir alani okumak 'undefined' uretir ve ekranda sessiz bir bosluk ya da
// bir istisna olur.
//
// KAPSAM DAR VE BU ACIKCA YAZILI: yalniz `useSWR<Tip>(...)` bicimindeki,
// ayni dosyada `interface Tip` ile tanimlanmis cagrilar karsilastirilabilir
// (satir ici tipler ve karmasik jenerikler statik olarak baglanamiyor).
// Bugun ESLESEN SAYISI asagida bir alt sinirla kilitli — kapsam
// dusurulurse test kirilir, yani kapi sessizce bosalmaz.
describe("(5) yanit semasi — arayuz olmayan alani okumasin", () => {
  const semalar: Record<string, unknown> = (SOZLESME_HAM.components ?? {})
    .schemas ?? {};

  function duz(s: unknown, derinlik = 0): Record<string, unknown> | null {
    if (derinlik > 6 || !s || typeof s !== "object") return null;
    const o = s as Record<string, unknown>;
    if (typeof o.$ref === "string") {
      const ad = o.$ref.split("/").pop() as string;
      return duz(semalar[ad], derinlik + 1);
    }
    if (o.type === "array") return duz(o.items, derinlik + 1);
    if (o.properties) return o;
    for (const k of ["allOf", "oneOf", "anyOf"]) {
      const alt = o[k];
      if (Array.isArray(alt)) {
        for (const a of alt) {
          const r = duz(a, derinlik + 1);
          if (r) return r;
        }
      }
    }
    return null;
  }

  function yanitSemasi(yol: string): Record<string, unknown> | null {
    const p = (SOZLESME_HAM.paths ?? {})[yol] as
      | Record<string, Record<string, unknown>>
      | undefined;
    const g = p?.get;
    if (!g) return null;
    for (const kod of ["200", "201"]) {
      const r = (g.responses as Record<string, Record<string, unknown>>)?.[kod];
      const icerik = r?.content as Record<string, { schema?: unknown }> | undefined;
      if (icerik) return duz(Object.values(icerik)[0]?.schema);
    }
    return null;
  }

  it("arayuzun ZORUNLU alanlari sozlesmede VAAT EDILMIS", () => {
    const sabitD = /const\s+([A-Za-z_$][\w$]*)\s*=\s*"(\/api\/panel\/[^"]*)"/g;
    const swrD = /useSWR<([^>]+)>\(\s*([`"]?)([^,`")]*)/g;
    const alanD = /^[ \t]*([a-zA-Z_][\w]*)(\??):/gm;

    const ihlal: string[] = [];
    let karsilastirilan = 0;

    for (const [dosya, kaynak] of taranacakKaynaklar(["app", "components"], [
      ".tsx",
    ])) {
      const sabitler = new Map<string, string>();
      for (const m of kaynak.matchAll(sabitD)) sabitler.set(m[1], m[2]);

      for (const m of kaynak.matchAll(swrD)) {
        const tipIfade = m[1].trim();
        let yol = m[3].trim();
        if (!m[2] && sabitler.has(yol)) yol = sabitler.get(yol)!;
        const ad = /\/api\/panel\/([a-z0-9-]+)/.exec(yol)?.[1];
        if (!ad || !(ad in OKUMA)) continue;

        let sema = yanitSemasi(OKUMA[ad]);
        if (!sema) continue;

        // `{ items: X[] }` sarmali: sozlesmede de `items` dizisine in.
        const sarmal = /^\{\s*items:\s*([A-Za-z_$][\w$]*)\[\]\s*\}$/.exec(tipIfade);
        let tip: string;
        if (sarmal) {
          tip = sarmal[1];
          const ic = (sema.properties as Record<string, unknown>)?.items;
          const icSema = ic ? duz(ic) : null;
          if (!icSema) continue;
          sema = icSema;
        } else {
          tip = tipIfade.replace("[]", "").trim();
        }
        if (!/^[A-Za-z_$][\w$]*$/.test(tip)) continue;

        const govde = new RegExp(`interface ${tip} \\{([\\s\\S]*?)\\n\\}`).exec(
          kaynak,
        );
        if (!govde) continue;

        const zorunlu = [...govde[1].matchAll(alanD)]
          .filter((a) => a[2] !== "?")
          .map((a) => a[1]);
        const vaat = new Set(Object.keys(sema.properties ?? {}));
        karsilastirilan++;
        const eksik = zorunlu.filter((a) => !vaat.has(a));
        if (eksik.length) {
          ihlal.push(`${dosya}: ${tip} <- GET ${OKUMA[ad]} — ${eksik.join(", ")}`);
        }
      }
    }

    // KAPSAM KILIDI: karsilastirma kumesi bosalirsa yokluk iddiasi her
    // zaman dogru cikar ve kapi hicbir sey olcmeden yesil kalir.
    expect(
      karsilastirilan,
      "sema karsilastirmasi bosaldi — kapi artik olcmuyor",
    ).toBeGreaterThanOrEqual(7);

    expect(
      ihlal,
      "Arayuz, sozlesmenin VAAT ETMEDIGI bir alani ZORUNLU okuyor — " +
        `ekranda 'undefined' demektir:\n${ihlal.join("\n")}`,
    ).toEqual([]);
  });
});
