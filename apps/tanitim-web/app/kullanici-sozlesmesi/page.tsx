import type { Metadata } from "next";

import { HukukiBelge } from "@/components/HukukiBelge";
import { KULLANICI_SOZLESMESI } from "@/lib/hukuki";

export const metadata: Metadata = {
  title: "Kullanıcı Sözleşmesi — Yönetiyor",
  description: KULLANICI_SOZLESMESI.giris,
};

export default function Sayfa() {
  return <HukukiBelge {...KULLANICI_SOZLESMESI} />;
}
