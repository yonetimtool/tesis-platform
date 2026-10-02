// (P251 §8) DEVRIYE SAYFASININ SEKMELERI — tek kaynak.
//
// Eski `/checkpoints`, `/patrol-plans`, `/reports/patrols` adresleri bu
// sekmelere yonlenir. Guvenlik gorevlisi (mobil) yalniz TAKIBI gorur;
// noktalar ve planlar yonetim ve amir icindir — web yuzeyi zaten yalniz
// yonetime acik (P129), ayrim mobilde uygulanir.
export const DEVRIYE_SEKMELERI = ["takip", "noktalar", "planlar"] as const;
export type DevriyeSekmesi = (typeof DEVRIYE_SEKMELERI)[number];
