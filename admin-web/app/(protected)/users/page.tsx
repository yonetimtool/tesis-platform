import { redirect } from "next/navigation";

import { rolunSekmesi } from "@/lib/kisiler";

/**
 * (P251 §8) `/users` -> `/kisiler` YONLENDIRMESI.
 *
 * Kisiler TEK giris + sekmeler oldu. Eski adres (yer imi, bildirim, eski
 * baglanti) calismaya devam eder; `?rol=resident` sakinler sekmesine,
 * digerleri personel sekmesine gider. Sayfa bileseni
 * `components/kisiler/kullanici-listesi.tsx`te yasiyor.
 */
export default async function UsersYonlendirme({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const rol = typeof sp.rol === "string" ? sp.rol : typeof sp.role === "string" ? sp.role : "";
  redirect(`/kisiler?sekme=${rolunSekmesi(rol)}`);
}
