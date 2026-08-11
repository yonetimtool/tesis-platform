/**
 * (P154 / Asama 5) DAIRE NUMARASI ARALIK IFADESI — "3,5,7-12".
 *
 * Brief: "Daire numaralarini VIRGULLE TOPLU SECME ('3,5,7-12' aralik
 * destegini de degerlendir) ve secilenlerin niteligini toplu degistirme."
 *
 * DEGERLENDIRME SONUCU: aralik destegi VAR ama YALNIZ SAYISAL kuyruk
 * uzerinde. Daire numaralari bu urunde `A-1`, `A-2` gibi ONEK TASIR ve
 * "A-7 - A-12" yazdirmak kullaniciya is cikarmak olurdu; kullanici "7-12"
 * yazar, onek EKRANDAKI LISTEDEN gelir.
 *
 * AYRISTIRMA NEDEN SUNUCUDA DEGIL: ifade kullanicinin EKRANDA GORDUGU
 * listeye gore anlam kazanir — blok suzgeci acikken "7-12" baska daireleri
 * gosterir. Sunucuda cozmek, istemcinin gordugu kume ile sunucunun
 * anladigi kumenin AYRISMASI demekti ve yanlis daireye toplu islem
 * uygulamak geri alinmasi zor bir hatadir. Sunucuya KESINLESMIS kimlikler
 * gider.
 *
 * ESLESMEYEN PARCALAR SESSIZCE DUSMEZ: cagiran `bulunamayan`i kullaniciya
 * gosterir — "12 daire sectim" deyip 9'unu islemek en kotu sonuctur.
 */

export interface AralikSonucu {
  /** Ifadeye uyan satirlarin kimlikleri (ekrandaki sirayla). */
  idler: string[];
  /** Ifadede gecen ama listede KARSILIGI OLMAYAN parcalar. */
  bulunamayan: string[];
  /** Ifade hic ayristirilamadiysa (bos ya da tumuyle gecersiz). */
  gecersiz: boolean;
}

/** `A-7` -> 7 · `12` -> 12 · `zemin` -> null (sayisal kuyruk yok). */
export function sayisalKuyruk(no: string): number | null {
  const m = /(\d+)\s*$/.exec(no.trim());
  return m ? Number(m[1]) : null;
}

/**
 * Ifadeyi ekrandaki satirlara uygular.
 *
 * @param ifade   kullanicinin yazdigi metin ("3,5,7-12")
 * @param satirlar ekranda GORUNEN daireler (suzgec uygulanmis hâli)
 */
export function aralikCoz(
  ifade: string,
  satirlar: { id: string; no: string }[],
): AralikSonucu {
  const parcalar = ifade
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);
  if (parcalar.length === 0) {
    return { idler: [], bulunamayan: [], gecersiz: true };
  }

  // Ekrandaki numaralarin sayisal kuyruklari. AYNI KUYRUK BIRDEN FAZLA
  // SATIRA denk gelebilir (A-7 ve B-7): ikisi de secilir, cunku kullanici
  // suzgeci daraltmadiysa ikisini de goruyordur.
  const kuyruklar = satirlar.map((s) => ({ ...s, n: sayisalKuyruk(s.no) }));

  const secilen: string[] = [];
  const bulunamayan: string[] = [];

  for (const p of parcalar) {
    const araligi = /^(\d+)\s*-\s*(\d+)$/.exec(p);
    if (araligi) {
      const bas = Number(araligi[1]);
      const son = Number(araligi[2]);
      // TERS ARALIK DA CALISIR ("12-7"): kullanicinin niyeti belli ve
      // "gecersiz" demek, duzeltilecek bir sey olmayan bir hata olurdu.
      const [alt, ust] = bas <= son ? [bas, son] : [son, bas];
      const eslesen = kuyruklar.filter((k) => k.n !== null && k.n >= alt && k.n <= ust);
      if (eslesen.length === 0) bulunamayan.push(p);
      secilen.push(...eslesen.map((k) => k.id));
      continue;
    }

    // Tek deger: once SAYI olarak, sonra TAM NUMARA olarak denenir —
    // kullanici "A-7" de yazabilmeli.
    const n = /^\d+$/.test(p) ? Number(p) : null;
    const eslesen =
      n !== null
        ? kuyruklar.filter((k) => k.n === n)
        : kuyruklar.filter((k) => k.no.toLocaleLowerCase("tr") === p.toLocaleLowerCase("tr"));
    if (eslesen.length === 0) bulunamayan.push(p);
    secilen.push(...eslesen.map((k) => k.id));
  }

  return {
    idler: [...new Set(secilen)],
    bulunamayan,
    gecersiz: secilen.length === 0 && bulunamayan.length === parcalar.length,
  };
}
