import { cookies, headers } from "next/headers";

import { AppShell } from "@/components/AppShell";
import { DonusCubugu } from "@/components/DonusCubugu";
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
      </AppShell>
    </ToastProvider>
  );
}
