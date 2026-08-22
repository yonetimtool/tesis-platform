import type { Metadata } from "next";
import Link from "next/link";

import { FiyatHesaplayici } from "@/components/FiyatHesaplayici";
import { KDV_UYARISI } from "@/config/fiyat";

/**
 * (P177 §2) YONETICI SAYFASI — IKI BIRINCIL EYLEM YAN YANA.
 *
 * "Kayıt Ol" AYRI BIR SAYFAYA gider; "Fiyat Hesapla" AYNI SAYFANIN
 * altindaki hesaplayiciya yumusak kaydirir. Sartnamenin acik maddesi ve
 * dogru olan da bu: fiyat bir SORUDUR, kayit bir KARARDIR. Fiyati gormek
 * icin sayfa degistirmek, karar vermeden once ziyaretciyi bir forma
 * sokmak olurdu.
 *
 * Yumusak kaydirma `globals.css`teki `scroll-behavior: smooth` ile
 * geliyor; `scroll-padding-top` yapiskan basligin hedefi ortmesini
 * engelliyor. Hareketi azalt tercihinde ikisi de kapanir.
 */
export const metadata: Metadata = {
  title: "Yöneticiyim",
  description:
    "Siteyi siz kurarsınız: kaydolun, site adını yazın, Tesis ID’nizi alın. " +
    "Yıllık maliyeti daire sayınıza göre hesaplayın.",
};

const NE_YAPARSINIZ = [
  "Blokları ve daireleri tanımlarsınız (tek tek ya da Excel’le).",
  "Sakin, güvenlik ve tesis görevlilerini eklersiniz; herkese Tesis ID’li e-posta gider.",
  "Aidat borçlandırmasını yapar, tahsilatı işlersiniz.",
  "Gelen arıza ve talepleri iş emrine çevirip görevliye atarsınız.",
  "Duyuru yayınlar, ortak alan rezervasyon kurallarını belirlersiniz.",
  "Güvenlik turu planlarını kurar, gecikmeleri alarm olarak görürsünüz.",
];

export default function YoneticiSayfasi() {
  return (
    <>
      <section className="border-b border-cizgi">
        <div className="kapsayici py-16 sm:py-24">
          <p className="etiket">Yöneticiyim</p>
          <h1 className="mt-4 max-w-[16ch] text-dev">Siteyi siz kurarsınız.</h1>
          <p className="mt-6 max-w-[52ch] text-[1.125rem] leading-relaxed text-govde">
            Kaydolduğunuzda size bir Tesis ID verilir. Sitenizdeki herkes o
            ID ile uygulamaya katılır; kimin katılabileceğine siz karar
            verirsiniz.
          </p>

          {/* IKI BIRINCIL EYLEM YAN YANA — sartname §2. */}
          <div className="mt-10 flex flex-col gap-3 sm:flex-row">
            <Link href="/yonetici/kayit" className="dugme-birincil">
              Kayıt Ol
            </Link>
            <a href="#hesaplayici" className="dugme-ikincil">
              Fiyat Hesapla
            </a>
          </div>
        </div>
      </section>

      <section className="bolum border-b border-cizgi">
        <div className="kapsayici grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
          <div>
            <p className="etiket">Panelde ne yaparsınız</p>
            <h2 className="mt-4 text-bolum">Yönetimin tamamı web panelinde.</h2>
            <p className="mt-5 max-w-[40ch] leading-relaxed">
              Yöneticiler ve denetçiler tarayıcıdan çalışır. Saha ekibi ve
              sakinler mobil uygulamayı kullanır.
            </p>
          </div>
          <ul className="space-y-3">
            {NE_YAPARSINIZ.map((m) => (
              <li key={m} className="flex gap-3 leading-relaxed">
                <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-mavi" />
                {m}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section id="hesaplayici" className="bolum">
        <div className="kapsayici">
          <p className="etiket">Fiyat hesapla</p>
          <h2 className="mt-4 max-w-[22ch] text-bolum">
            Yıllık maliyet daire sayısına bağlı.
          </h2>
          <p className="mt-5 max-w-[54ch] leading-relaxed">
            Kademe yok, paket yok. Sitenizdeki daire sayısını yazın, yıllık
            tutarı görün. {KDV_UYARISI}
          </p>

          <div className="mt-10 max-w-3xl">
            <FiyatHesaplayici />
          </div>

          <div className="mt-10">
            <Link href="/yonetici/kayit" className="dugme-birincil">
              Kayıt Ol
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
