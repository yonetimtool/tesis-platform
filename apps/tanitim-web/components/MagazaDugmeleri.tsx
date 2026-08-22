import { APP_STORE_ADRESI, PLAY_ADRESI } from "@/config/site";

/**
 * (P177 §2) MAGAZA DUGMELERI.
 *
 * ADRES BOSSA DUGME CIZILMEZ. App Store numeric id'si henuz yok; bos bir
 * id ile "App Store'dan indirin" yazan ve 404'e giden bir dugme
 * gostermek, hic gostermemekten kotudur. Ayni kural backend'de
 * (`settings.app_store_url`) ve panelde (`lib/magaza.ts`) da gecerli —
 * uc yuzey ayni davranir.
 *
 * RESMI ROZET GORSELI KULLANILMIYOR: Apple ve Google'in rozetleri
 * kendi CDN'lerinden servis edilir ve sartname dis ag bagimliligini
 * yasakliyor. Rozetleri depoya kopyalamak ise marka kilavuzlarina tabi
 * (olcu, bosluk, dil varyanti) ve yanlis kullanimi magaza denetiminde
 * sorun cikarir. Metin dugmesi ikisini de yapmaz.
 */
export function MagazaDugmeleri({ koyu = false }: { koyu?: boolean }) {
  const sinif = koyu ? "dugme-koyu" : "dugme-ikincil";
  if (!PLAY_ADRESI && !APP_STORE_ADRESI) return null;
  return (
    <div className="flex flex-wrap gap-3">
      {PLAY_ADRESI ? (
        <a className={sinif} href={PLAY_ADRESI} rel="noreferrer noopener" target="_blank">
          Google Play’den indir
        </a>
      ) : null}
      {APP_STORE_ADRESI ? (
        <a className={sinif} href={APP_STORE_ADRESI} rel="noreferrer noopener" target="_blank">
          App Store’dan indir
        </a>
      ) : null}
    </div>
  );
}
