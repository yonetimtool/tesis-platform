// (P126.7) ACCESS TOKEN'DAN ROL — TEK yer.
//
// Rol iki yerde birden gerekiyor: giris kapisi (hangi yuzeye alinacak) ve
// kabuk menusu (hangi baglantilar cizilecek). Ikinci bir kopya yazmak,
// birinin duzeltilip otekinin sessizce eskimesi demekti.
//
// IMZA DOGRULANMAZ ve bu BILINCLIDIR: token'i backend'in kendisi verdi ve
// cerezi httpOnly. Buradan okunan rol YALNIZCA NE CIZILECEGINI belirler;
// gercek yetki her istekte backend RBAC'ta zorlanir (contracts/auth.md §4).
// Yani token'i kurcalayan biri menude fazladan bir baglanti gorebilir —
// tiklayinca 403 alir. Gorunurluk yetkilendirme degildir.

/** JWT govdesindeki `role` iddiasi; cozulemezse `null`. */
export function tokenRolu(access: string | undefined | null): string | null {
  if (!access) return null;
  try {
    const govde = access.split(".")[1] ?? "";
    // `Buffer` DEGIL `atob`: bu modulu Edge calisma zamanindaki middleware
    // de kullaniyor ve orada `Buffer` YOKTUR. `atob` ikisinde de var.
    // base64url -> base64 cevrimi elle yapilir (`-_` ve eksik dolgu).
    const b64 = govde.replace(/-/g, "+").replace(/_/g, "/");
    const dolgulu = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    // `atob` bayt dizesi verir; Turkce karakter iceren bir ad UTF-8
    // olarak yeniden cozulmelidir (rol icin sart degil ama govde
    // JSON.parse'a girecek).
    const bayt = Uint8Array.from(atob(dolgulu), (c) => c.charCodeAt(0));
    const json = new TextDecoder().decode(bayt);
    const rol = (JSON.parse(json) as { role?: unknown }).role;
    return typeof rol === "string" && rol ? rol : null;
  } catch {
    return null;
  }
}
