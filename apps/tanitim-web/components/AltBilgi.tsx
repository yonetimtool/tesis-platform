import Link from "next/link";

import { APP_ADRESI, ILETISIM_EPOSTA } from "@/config/site";
import { Logo } from "./Logo";
import { MagazaDugmeleri } from "./MagazaDugmeleri";

/**
 * (P177 §2) ZENGIN ALTBILGI.
 *
 * Koyu zemin (`lacivert`) — sayfanin tek koyu blogu ve bilincli:
 * altbilgi bir kapanistir, sayfanin bittigini renk degistirerek soyler.
 * Uzerindeki metin `maviAcik` (#B9D4F0) ile 9.83 kontrast tasiyor.
 *
 * HUKUKI BAGLANTILAR BURADA TOPLANIR: uc belge (kullanici sozlesmesi,
 * KVKK aydinlatma, cerez politikasi) hem kayit formundan hem buradan
 * erisilir. Kayit formundaki bag KAPATILAMAZ (onay kutusunun yaninda
 * olmali); buradaki, kaydolmayan ziyaretci icin.
 */
export function AltBilgi() {
  return (
    <footer className="bg-lacivert text-maviAcik">
      <div className="kapsayici grid gap-10 py-16 md:grid-cols-[1.4fr_1fr_1fr] md:gap-8">
        <div className="space-y-4">
          <Logo koyu />
          <p className="max-w-[38ch] text-kucuk">
            Site ve apartman yönetimi için tek uygulama: aidat, arıza,
            duyuru, rezervasyon ve güvenlik turları bir arada.
          </p>
          <MagazaDugmeleri koyu />
        </div>

        <nav aria-label="Site bağlantıları">
          <h2 className="mb-3 text-etiket uppercase text-white">Site</h2>
          <ul className="space-y-2 text-kucuk">
            <li><Link className="hover:text-white" href="/yonetici">Yöneticiyim</Link></li>
            <li><Link className="hover:text-white" href="/site-sakini">Site sakiniyim</Link></li>
            <li><Link className="hover:text-white" href="/yonetici#hesaplayici">Fiyat hesapla</Link></li>
            <li><Link className="hover:text-white" href="/yonetici/kayit">Kayıt ol</Link></li>
            <li>
              <a className="hover:text-white" href={APP_ADRESI} rel="noreferrer noopener">
                Giriş yap
              </a>
            </li>
          </ul>
        </nav>

        <nav aria-label="Yasal bağlantılar">
          <h2 className="mb-3 text-etiket uppercase text-white">Yasal</h2>
          <ul className="space-y-2 text-kucuk">
            <li><Link className="hover:text-white" href="/kullanici-sozlesmesi">Kullanıcı Sözleşmesi</Link></li>
            <li><Link className="hover:text-white" href="/kvkk-aydinlatma">KVKK Aydınlatma Metni</Link></li>
            <li><Link className="hover:text-white" href="/cerez-politikasi">Çerez Politikası</Link></li>
            <li>
              <a className="hover:text-white" href={`mailto:${ILETISIM_EPOSTA}`}>
                {ILETISIM_EPOSTA}
              </a>
            </li>
          </ul>
        </nav>
      </div>

      <div className="border-t border-white/15">
        <div className="kapsayici flex flex-col gap-2 py-6 text-kucuk sm:flex-row sm:items-center sm:justify-between">
          <p>Yönetiyor</p>
          {/* KVKK metinlerinin dedigi seyin AYNISI, pazarlama cumlesi
              degil: bu sitede ucuncu taraf analitik ya da reklam cerezi
              KULLANILMIYOR (§0 — Google Analytics/harici izleyici yasak). */}
          <p>Bu sitede reklam çerezi ve üçüncü taraf analitik kullanılmaz.</p>
        </div>
      </div>
    </footer>
  );
}
