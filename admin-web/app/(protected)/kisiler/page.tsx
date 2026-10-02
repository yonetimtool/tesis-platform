"use client";

/**
 * (P251 §8) KISILER — TEK GIRIS, SEKMELER.
 *
 * Kisiler eskiden UC sayfaya bolunmustu: Kullanicilar (herkesi ekler),
 * Sakinler (liste + sil, ekleme yok) ve Davetler (Iletisim grubunda).
 * Hepsi ayni kayit (`app_user`, rolu farkli) oldugu icin kullanici "neyi
 * nerede" sorusuyla kaliyordu. Artik tek sayfa, rol basina bir sekme:
 *
 *   Sakinler · Personel · Yoneticiler ve denetciler · Davetler
 *
 * Her sekme AYNI liste bilesenini bir rol KAPSAMIYLA cizer (bkz.
 * `KullaniciListesi`): "Ekle" bulunulan sekmenin rolune gore acilir,
 * sakin formu daire ve sifat alanlariyla, personel formu saha rolleriyle.
 *
 * SEKME ADRESTE (`?sekme=personel`): eski `/users`, `/residents`,
 * `/davetler` adresleri buraya yonlenir ve bildirimlerden gelen baglanti
 * dogru sekmeyi acar. Sekme degisince adres de degisir (yenileme ve geri
 * tusu ayni sekmeyi acar).
 *
 * MAAS KARTI: Personel sekmesinde her satirda maas karti durumu ve
 * "Maas karti olustur" eylemi var — ayni kisi hesap + kart olarak iki kez
 * yazilmasin (bkz. `MaasKartiEylemi`).
 *
 * SAKIN MODUNDA (P247) bu sayfa gorunmez: rota yonetim rollerine acik.
 */
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";

import { MaasKartiEylemi } from "@/components/kisiler/maas-karti-eylemi";
import DavetListesi from "@/components/kisiler/davet-listesi";
import KullaniciListesi from "@/components/kisiler/kullanici-listesi";
import SakinListesi from "@/components/kisiler/sakin-listesi";
import { Dugme, GomuluSayfa, SayfaBasligi, Sekmeler } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import { KISILER_SEKMELERI, SEKME_KAPSAMI, type KisilerSekmesi } from "@/lib/kisiler";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

const GORUNUM_LISTE = "liste" as const;
const GORUNUM_BLOKLAR = "bloklar" as const;
const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;
const KUCUK = "kucuk" as const;

const KISILER_YOLU = "/kisiler";

export default function KisilerPage() {
  const t = useT();
  const router = useRouter();
  const yol = usePathname();
  const [sekme, setSekme] = useSorguSecimi<KisilerSekmesi>("sekme", KISILER_SEKMELERI, "sakinler");
  const [sakinGorunumu, setSakinGorunumu] = useState<string>(GORUNUM_LISTE);

  function degis(id: string) {
    setSekme(id as KisilerSekmesi);
    router.replace(`${yol ?? KISILER_YOLU}?sekme=${id}`, { scroll: false });
  }

  return (
    <div>
      <SayfaBasligi baslik={t("kabukKisiler")} aciklama={t("kisilerAlt")} />
      <Sekmeler
        aktifId={sekme}
        onDegis={degis}
        sekmeler={[
          {
            id: "sakinler",
            baslik: t("kisilerSekmeSakinler"),
            icerik: (
              <GomuluSayfa>
                {/* "Kim nerede oturuyor" gorunumu (P220) korunur: liste
                    hesap odakli, bloklara gore gorunum daire odakli. */}
                <div className="mb-4 flex gap-2" role="group" aria-label={t("kisilerSekmeSakinler")}>
                  {[
                    [GORUNUM_LISTE, t("kisilerGorunumListe")],
                    [GORUNUM_BLOKLAR, t("kisilerGorunumBloklar")],
                  ].map(([deger, etiket]) => (
                    <Dugme
                      key={deger}
                      boy={KUCUK}
                      tur={sakinGorunumu === deger ? BIRINCIL : IKINCIL}
                      aria-pressed={sakinGorunumu === deger}
                      onClick={() => setSakinGorunumu(deger)}
                    >
                      {etiket}
                    </Dugme>
                  ))}
                </div>
                {sakinGorunumu === GORUNUM_BLOKLAR ? (
                  <SakinListesi />
                ) : (
                  <KullaniciListesi
                    kapsam={SEKME_KAPSAMI.sakinler}
                    baslik={t("kisilerSekmeSakinler")}
                  />
                )}
              </GomuluSayfa>
            ),
          },
          {
            id: "personel",
            baslik: t("kisilerSekmePersonel"),
            icerik: (
              <GomuluSayfa>
                <KullaniciListesi
                  kapsam={SEKME_KAPSAMI.personel}
                  baslik={t("kisilerSekmePersonel")}
                  ekEylem={(u) => <MaasKartiEylemi kullanici={u} />}
                />
              </GomuluSayfa>
            ),
          },
          {
            id: "yoneticiler",
            baslik: t("kisilerSekmeYoneticiler"),
            icerik: (
              <GomuluSayfa>
                <KullaniciListesi
                  kapsam={SEKME_KAPSAMI.yoneticiler}
                  baslik={t("kisilerSekmeYoneticiler")}
                />
              </GomuluSayfa>
            ),
          },
          {
            id: "davetler",
            baslik: t("kisilerSekmeDavetler"),
            icerik: (
              <GomuluSayfa>
                <DavetListesi />
              </GomuluSayfa>
            ),
          },
        ]}
      />
    </div>
  );
}
