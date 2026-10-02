import { redirect } from "next/navigation";

/**
 * (P251 §8) `/patrol-plans` -> Devriye › Planlar.
 *
 * Eski adres (yer imi, bildirim) calismaya devam eder; ekran artik tek
 * sayfanin sekmesi.
 */
export default function PlanlarYonlendirme() {
  redirect("/devriye?sekme=planlar");
}
