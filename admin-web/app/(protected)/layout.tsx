import { cookies } from "next/headers";

import { AppShell } from "@/components/AppShell";
import { ToastProvider } from "@/components/Toast";
import { ACCESS_COOKIE } from "@/lib/cookies";
import { tokenRolu } from "@/lib/rol-token";

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
export default function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const rol = tokenRolu(cookies().get(ACCESS_COOKIE)?.value);
  return (
    <ToastProvider>
      <AppShell rol={rol}>{children}</AppShell>
    </ToastProvider>
  );
}
