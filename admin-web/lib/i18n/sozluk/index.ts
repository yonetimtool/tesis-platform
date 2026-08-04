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

/// Tum sozlukler — SUNUCU tarafi icin.
///
/// (P132.5) BU NESNE ISTEMCIYE GITMEZ. Eskiden `I18nProvider` ("use
/// client") bunu dogrudan import ediyordu ve sonuc su oluyordu: YEDI DILIN
/// TAMAMI her rotanin istemci paketine giriyordu (~430 KB kaynak; olculen
/// ilk-yuk etkisi rota basina ~140 KB). Kullanici bir dil kullanir.
///
/// Artik: sunucu duzeni AKTIF sozlugu prop olarak gecer; dil degisince
/// istemci yalniz O DILI ceker (bkz. `./yukle` — AYRI MODUL olmasi sart,
/// cunku bu dosyanin statik importlari paketi geri getirirdi).
/// Yorumun eski hâli "dil degisiminde ag istegi olmaz" diyordu — dogruydu,
/// ama bedeli her ziyaretcinin hic kullanmayacagi alti sozlugu indirmesiydi.
export const SOZLUKLER: Record<Dil, Sozluk> = { tr, en, ar, ru, de, fr, es };

