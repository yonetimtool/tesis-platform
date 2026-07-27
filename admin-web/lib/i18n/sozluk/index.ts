import type { Dil } from "../diller";
import { ar } from "./ar";
import { de } from "./de";
import { en } from "./en";
import { es } from "./es";
import { fr } from "./fr";
import { ru } from "./ru";
import { tr } from "./tr";
import type { Sozluk, SozlukAnahtari } from "./tipler";

export type { Sozluk, SozlukAnahtari };

/// Tum sozlukler. Panelde 7 dil AYNI anda yuklenir: sozluk toplam birkac
/// on KB'dir ve dil degisiminde ag istegi/parlama olmaz.
export const SOZLUKLER: Record<Dil, Sozluk> = { tr, en, ar, ru, de, fr, es };
