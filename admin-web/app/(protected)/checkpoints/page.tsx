import { redirect } from "next/navigation";

/**
 * (P251 §8) `/checkpoints` -> Devriye › NFC noktalari.
 *
 * Eski adres (yer imi, bildirim) calismaya devam eder; ekran artik tek
 * sayfanin sekmesi.
 */
export default function NoktalarYonlendirme() {
  redirect("/devriye?sekme=noktalar");
}
