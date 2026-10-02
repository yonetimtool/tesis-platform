import { redirect } from "next/navigation";

/**
 * (P251 §8) `/davetler` -> Kisiler › Davetler.
 *
 * Eski adres (yer imi, bildirim) calismaya devam eder; ekran artik tek
 * sayfanin sekmesi.
 */
export default function DavetlerYonlendirme() {
  redirect("/kisiler?sekme=davetler");
}
