import type { Metadata } from "next";
import Link from "next/link";

import { MagazaDugmeleri } from "@/components/MagazaDugmeleri";

/**
 * (P177 §2) SITE SAKINI SAYFASI — KAYIT FORMU YOK.
 *
 * =========================================================================
 * BU SAYFADA NEDEN FORM YOK
 * =========================================================================
 * Sartname: "Sakin SITEDEN KAYIT OLMAZ." Sebep bir tercih degil bir
 * guvenlik kurali: bir sitenin sakin listesi o sitenin verisidir ve
 * kimin sakin oldugunu YONETICI bilir. Kendi kendine kaydolabilen bir
 * form, Tesis ID'yi ogrenen herkesi o sitenin sakini yapardi.
 *
 * Sayfa bu yuzden yalnizca AKISI ANLATIR ve iki magaza dugmesi tasir.
 * Buraya bir "on kayit" formu eklemek, sonucu yoneticinin onay
 * kuyruguna dusen bir yol acmak olurdu — yani ayni kapiyi arka
 * taraftan.
 */
export const metadata: Metadata = {
  title: "Site sakiniyim",
  description:
    "Site sakinleri siteden kayıt olmaz. Yöneticiniz sizi ekler, " +
    "e-postanıza Tesis ID gelir, kaydınızı mobil uygulamadan tamamlarsınız.",
};

const ADIMLAR = [
  {
    no: "01",
    baslik: "Yöneticiniz sizi ekler",
    metin:
      "Site yönetimi sizi sistemde tanımlar. Bu adım siz bir şey yapmadan olur.",
  },
  {
    no: "02",
    baslik: "E-postanıza bilgi gelir",
    metin:
      "Gelen e-postada sitenizin Tesis ID’si ve uygulama mağaza bağlantıları vardır.",
  },
  {
    no: "03",
    baslik: "Uygulamayı indirirsiniz",
    metin: "App Store ya da Google Play’den Yönetiyor’u kurarsınız.",
  },
  {
    no: "04",
    baslik: "Kaydınızı tamamlarsınız",
    metin:
      "Uygulamada “Kayıt Ol” deyip rolünüzü seçer, Tesis ID’yi girer ve e-postanıza gelen kodu yazarsınız.",
  },
];

export default function SakinSayfasi() {
  return (
    <>
      <section className="border-b border-cizgi">
        <div className="kapsayici py-16 sm:py-24">
          <p className="etiket">Site sakiniyim</p>
          <h1 className="mt-4 max-w-[18ch] text-dev">
            Kaydınızı uygulamadan tamamlarsınız.
          </h1>
          <p className="mt-6 max-w-[54ch] text-[1.125rem] leading-relaxed text-govde">
            Bu siteden kayıt olunmaz. Sizi sisteme site yönetiminiz ekler;
            gerisi telefonunuzda birkaç dakika sürer.
          </p>
          <div className="mt-10">
            <MagazaDugmeleri />
          </div>
        </div>
      </section>

      <section className="bolum border-b border-cizgi">
        <div className="kapsayici">
          <p className="etiket">Nasıl olur</p>
          <h2 className="mt-4 max-w-[20ch] text-bolum">Dört adım.</h2>
          <ol className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {ADIMLAR.map((a) => (
              <li key={a.no} className="kart">
                <p className="text-[1.75rem] font-extrabold leading-none tracking-[-0.04em] text-mavi">
                  {a.no}
                </p>
                <h3 className="mt-4 text-kartbaslik">{a.baslik}</h3>
                <p className="mt-2 text-kucuk leading-relaxed text-govde">{a.metin}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="bolum border-b border-cizgi">
        <div className="kapsayici grid gap-10 lg:grid-cols-2 lg:gap-16">
          <div className="kart">
            <h2 className="text-kartbaslik">E-posta gelmediyse</h2>
            <p className="mt-3 leading-relaxed text-govde">
              Site yönetiminize başvurun. Sisteme hangi e-posta adresiyle
              eklendiğinizi doğrulatın ve daveti yeniden göndermelerini
              isteyin. Kayıt, yalnızca yöneticinin eklediği e-posta adresiyle
              tamamlanabilir.
            </p>
          </div>
          <div className="kart">
            <h2 className="text-kartbaslik">Tesis ID’yi biri paylaştıysa</h2>
            <p className="mt-3 leading-relaxed text-govde">
              Tesis ID tek başına yetmez. Kayıt için e-posta adresinizin
              yöneticinin listesinde olması ve o adrese gelen kodu girmeniz
              gerekir. Bu üç şart birlikte aranır.
            </p>
          </div>
        </div>
      </section>

      <section className="bolum">
        <div className="kapsayici">
          <p className="etiket">Siteyi siz mi yönetiyorsunuz?</p>
          <h2 className="mt-4 max-w-[24ch] text-bolum">
            Yönetici kaydı ayrı bir yerden yapılır.
          </h2>
          <div className="mt-8">
            <Link href="/yonetici" className="dugme-birincil">
              Yönetici sayfasına git
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
