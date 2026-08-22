import type { Metadata } from "next";

import { KayitFormu } from "@/components/KayitFormu";

export const metadata: Metadata = {
  title: "Yönetici Kaydı",
  description:
    "Yönetici hesabınızı oluşturun, e-postanızı doğrulayın ve sitenizi kurun.",
  // Kayit sayfasi arama sonucunda gorunmeli ama TEKIL olmali; ana
  // sayfadaki "Kayıt Ol" dugmesi de buraya bakiyor.
  alternates: { canonical: "/yonetici/kayit" },
};

export default function KayitSayfasi() {
  return (
    <section className="bolum">
      <div className="kapsayici grid gap-10 lg:grid-cols-[0.85fr_1.15fr] lg:gap-16">
        <div>
          <p className="etiket">Yönetici kaydı</p>
          <h1 className="mt-4 text-bolum">Hesabınızı oluşturun.</h1>
          <p className="mt-5 max-w-[42ch] leading-relaxed">
            Üç adım: bilgileriniz, e-posta doğrulaması, site adı. Sonunda
            Tesis ID’nizi hem ekranda görür hem e-postayla alırsınız.
          </p>
          <ul className="mt-8 space-y-3 text-kucuk text-soluk">
            <li>• Kredi kartı istenmez.</li>
            <li>• Telefonunuza SMS gönderilmez.</li>
            <li>• Tesis ID’yi yalnızca sizin eklediğiniz kişiler kullanabilir.</li>
          </ul>
        </div>
        <div className="max-w-xl">
          <KayitFormu />
        </div>
      </div>
    </section>
  );
}
