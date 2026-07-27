import type { tr } from "./tr";

/// Sozluk TIPI kaynak dilden (tr) turer: bir anahtar orada eklenince diger
/// alti dil derlenmez ve `npx tsc` eksigi tek tek sayar. Ceviriyi calisma
/// anina birakan "missing key" uyarilarindan bilincli olarak kacinilmistir.
export type Sozluk = Record<keyof typeof tr, string>;
export type SozlukAnahtari = keyof typeof tr;
