import type { Metadata } from "next";

import { HukukiBelge } from "@/components/HukukiBelge";
import { KVKK_AYDINLATMA } from "@/lib/hukuki";

export const metadata: Metadata = {
  title: "KVKK Aydınlatma Metni — Yönetiyor",
  description: KVKK_AYDINLATMA.giris,
};

export default function Sayfa() {
  return <HukukiBelge {...KVKK_AYDINLATMA} />;
}
