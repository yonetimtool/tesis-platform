import { headers } from "next/headers";

import { GirisFormu } from "@/components/GirisFormu";
import { girisRedKarari, konakYuzeyi, mobilYalnizRol } from "@/lib/yuzey";

// (P126 sonrasi) GIRIS EKRANI YUZEYE GORE — karar SUNUCUDA verilir.
//
// Istemcide `window.location.host`a bakmak da mumkundu ama ilk kare YANLIS
// formla boyanir, sonra ikinci formla degisirdi: kullanici tesis kodu alani
// gorup bir an sonra telefon alanina duserdi. Konak zaten istegin
// basligindadir; sunucuda okumak bedava ve titremesizdir.
export default async function LoginPage({
  searchParams,
}: {
  searchParams?: Record<string, string | string[] | undefined>;
}) {
  const baslikDeposu = await headers();
  const yuzey = konakYuzeyi(baslikDeposu.get("host"));
  return <GirisFormu yuzey={yuzey} ilkRed={ilkRedAnahtari(searchParams)} />;
}

/**
 * (P248 §1) Middleware mobil-yalniz rolun artakalan oturumunu kapatip
 * buraya `?neden=mobil_uygulama&rol=...` ile yollar. Mesaj AYNI karardan
 * (`girisRedKarari`) gelir — giris rotasinin 403'uyle birebir.
 *
 * ROL ADRES CUBUGUNDAN OKUNUR ve bu bir yetki DEGIL: yalniz hangi metnin
 * gosterilecegini secer; mobil-yalniz olmayan bir rol yazilirsa hicbir
 * sey gosterilmez (uydurma adresle yanlis bir red cumlesi cizilmesin).
 */
function ilkRedAnahtari(arama: Record<string, string | string[] | undefined> | undefined) {
  if (arama?.neden !== "mobil_uygulama") return undefined;
  const rol = typeof arama.rol === "string" ? arama.rol : null;
  if (!mobilYalnizRol(rol)) return undefined;
  // Mobil-yalniz rolun cumlesi TESIS yuzeyinin kararidir (magaza + rol
  // adi); panelde "panel platform icindir" demek onu yanlis yere yollardi.
  return girisRedKarari(rol, "tesis").anahtar;
}
