import { redirect } from "next/navigation";

/**
 * (P251 §8) `/reports/patrols` -> Devriye › Takip.
 *
 * Eski adres (yer imi, bildirim) calismaya devam eder; ekran artik tek
 * sayfanin sekmesi.
 */
export default function DevriyeRaporuYonlendirme() {
  redirect("/devriye?sekme=takip");
}
