import { cookies, headers } from "next/headers";

import { AppShell } from "@/components/AppShell";
import { DonusCubugu } from "@/components/DonusCubugu";
import { IlkGirisTuru } from "@/components/IlkGirisTuru";
import { PanikAlarmi } from "@/components/panik/panik-alarmi";
import { SunucuDurumu } from "@/components/SunucuDurumu";
import { ToastProvider } from "@/components/Toast";
import { ACCESS_COOKIE } from "@/lib/cookies";
import { tokenRolu } from "@/lib/rol-token";
import { konakYuzeyi } from "@/lib/yuzey";

// Korumali alan duzeni. Oturum kontrolu middleware'de yapilir.
//
// (P126.7) ROL SUNUCUDA COZULUR ve kabuga baslangic degeri olarak verilir.
// Boylece menu ILK CIZIMDE dogru gelir; istemciden `/api/me` beklemek,
// sakine yonetim menusunu bir kare boyunca gostermek ya da menuyu bos
// birakmak demekti. Cerez httpOnly oldugu icin bunu yalniz sunucu yapabilir.
//
// ACCESS CEREZI 15 DAKIKADA DUSER, refresh 30 gundur: o aralikta buradan
// `null` doner. Kabuk bu durumda `/api/me`ye sorar (BFF refresh akisini
// tetikler) — yani deger BAYATLASA DA menu kendini toparlar.
// (P126 sonrasi) YUZEY DE SUNUCUDA COZULUR. Kabuk bunu `window.location`dan
// okuyordu ve SUNUCU CIZIMINDE `window` YOKTUR: ilk kare `app.*`ta bile
// PLATFORM menusuyle boyaniyordu — sakine bir an icin "Tesisler" baglantisi
// gorunuyor, logo `/tenants`e isaret ediyordu (olculdu: sunucu HTML'inde tek
// baglanti `href="/tenants"`). Konak zaten istegin basliginda; okumak bedava.
export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const cerezler = await cookies();
  const baslikDeposu = await headers();
  const rol = tokenRolu(cerezler.get(ACCESS_COOKIE)?.value);
  const yuzey = konakYuzeyi(baslikDeposu.get("host"));
  return (
    <ToastProvider>
      <AppShell rol={rol} yuzey={yuzey}>
        {/* (P154 / Asama 7.4) Bagimlilik yonlendirmesinin "geri donus"
            ayagi. Duzende TEK KEZ: `?donus=` tasiyan her sayfada
            kendiliginden gorunur, tasimayan hicbir sayfada gorunmez.
            Her hedef ekrana ayri bir "geri don" dugmesi koymak, ayni
            davranisi dokuz kez yazmak olurdu. */}
        <DonusCubugu />
        {/* (P171 duzeltme) API'YE ULASILAMIYOR DURUMU — TEK YERDE.
            Kabugun ICINDE: menu ve ust bar YERINDE kalir, yalniz sayfa
            icerigi durum ekraniyla degisir. Kullanici nerede oldugunu
            kaybetmemeli ve cikis yapabilmeli. */}
        <SunucuDurumu>{children}</SunucuDurumu>
        {/* (P243 §5a) SOS TETIKLEME WEB'DEN KALDIRILDI.
            ==================================================================
            GEREKCE
            ==================================================================
            Acil durumda kimse bilgisayar basina kosmaz; telefon elde
            olur. P240'ta dugme her sayfaya konmustu ("alarm gec
            kalmasin") ama YANLIS YUZEYDE hizli olmak, hizli olmak
            degildir.

            ALARM TAKIBI KALDI ve kalmasi sart: yonetici gelen alarmi
            GORUR, "gordum"/"mudahale" der, kapatir (`/panik` sayfasi).
            Kalkan sey yalniz TETIKLEME.

            `PanikAlarmi` (tam ekran gelen alarm katmani) DA KALDI:
            bilgisayar basindaki yoneticiye alarmin ULASMASI, onun
            alarmi BASLATMASINDAN bagimsiz bir ihtiyac. */}
        <PanikAlarmi />
        {/* (P243 §6d) ILK GIRIS TURU — DUZENDE TEK KEZ.
            Hangi sayfadan girilirse girilsin cikar (yeni yonetici
            dogrudan `/dashboard`a duser, `/kurulum`a degil) ve rol
            kapisini kendi icinde uygular. */}
        <IlkGirisTuru />
      </AppShell>
    </ToastProvider>
  );
}
