// =========================================================================
// (P248 §3a) GIRDI UZUNLUK SINIRLARI — istemci kopyasi.
// =========================================================================
// TEK KAYNAK SUNUCUDUR: `backend/app/girdi_siniri.py` icindeki
// `ISTEMCI_SABITLERI`. Buradaki sayilar ONUNLA AYNI olmak ZORUNDA —
// `tests/girdi-siniri.test.ts` python dosyasini okuyup karsilastirir.
//
// NEDEN ISTEMCIDE DE: kullanici "istedigi kadar yazabiliyordu". Sunucu
// fazlasini 422 ile reddeder (asil koruma), ama kullanici 5000 karakter
// yazip ANCAK kaydederken ogrenmemeli: `maxLength` fazlasini YAZDIRMAZ.
//
// KURAL: istemci siniri sunucudakinden BUYUK olamaz (kullanici yazabildigi
// metni kaydedemezdi); mumkunse ESIT. Alanin semada kendine ozgu bir sayisi
// varsa (ornek: firma adi 150 — DB CHECK) cagiran o sayiyi yazar ve
// yanina `// sunucu: Sema.alan` yorumu koyar.
export const SINIR = {
  AD: 100,
  BASLIK: 200,
  EPOSTA: 254,
  PAROLA: 128,
  GIZLI: 500,
  URL: 2048,
  ADRES: 500,
  NOT: 2000,
  UZUN_NOT: 5000,
  UZUN_METIN: 20000,
  YASAL_METIN: 100000,
  KOD: 64,
  SLUG: 120,
  DOSYA_ADI: 255,
  ARAMA: 100,
  BLOK: 32,
  DAIRE_NO: 50,
  NFC_UID: 64,
  IBAN: 42,
} as const;

export type SinirAdi = keyof typeof SINIR;

/** Yalniz ISTEMCIDE olan sinirlar (sunucu bu alanlari metin olarak
 * almaz: tutar kurusa, sayi int'e cevrilip gider). SINIR'dan AYRI tutuldu —
 * `SINIR` sunucuyla BIREBIR esit olmak zorunda (kilit). */
export const ISTEMCI_SINIR = {
  /** Tutar / sayi metni ("1.250.000,50") — KURUS_UST_SINIR 10^13 bile 20 haneyi asmaz. */
  SAYI: 24,
  /** Donem "YYYY-MM". */
  DONEM: 7,
  /** Ice aktarimda YAPISTIRILAN ham tablo metni — istemcide ayristirilir,
   * sunucuya HUCRE HUCRE gider (her hucre `HUCRE`). 500 satirlik bir
   * yapistirma sigsin diye genis. */
  YAPISTIRMA: 500_000,
  /** Ice aktarim hucresi — sunucu: IceAktarimSatir.degerler (HucreMetni 1000). */
  HUCRE: 1000,
} as const;
