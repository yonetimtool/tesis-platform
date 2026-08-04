import { headers } from "next/headers";

import { GirisFormu } from "@/components/GirisFormu";
import { konakYuzeyi } from "@/lib/yuzey";

// (P126 sonrasi) GIRIS EKRANI YUZEYE GORE — karar SUNUCUDA verilir.
//
// Istemcide `window.location.host`a bakmak da mumkundu ama ilk kare YANLIS
// formla boyanir, sonra ikinci formla degisirdi: kullanici tesis kodu alani
// gorup bir an sonra telefon alanina duserdi. Konak zaten istegin
// basligindadir; sunucuda okumak bedava ve titremesizdir.
export default async function LoginPage() {
  const baslikDeposu = await headers();
  const yuzey = konakYuzeyi(baslikDeposu.get("host"));
  return <GirisFormu yuzey={yuzey} />;
}
