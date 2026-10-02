import { redirect } from "next/navigation";

/**
 * (P251 §8) `/residents` -> Kisiler › Sakinler.
 *
 * Eski adres (yer imi, bildirim) calismaya devam eder; ekran artik tek
 * sayfanin sekmesi.
 */
export default function ResidentsYonlendirme() {
  redirect("/kisiler?sekme=sakinler");
}
