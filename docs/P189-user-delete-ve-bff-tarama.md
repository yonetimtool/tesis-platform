# P189 — Kullanıcı silinemiyor (405) + BFF eksik-rota taraması

## Sorun
`DELETE /api/users/{id}` → **405 Method Not Allowed**. Web'deki sil düğmesi bu
ucu çağırıyor ama karşılığı yok (P173'teki BFF eksik-rota sınıfı).

## 1) Backend DELETE /users/{id} var mı?
**Var** (P186'da kaldırılmadı). `users.py:delete_user` mevcuttu; sunucu tarafı
yetki (`_yonetim_kapisi`), kendini-silememe (409), denetim kaydı hepsi vardı.
Eksik olan yalnızca **admin-web BFF vekili**: `app/api/users/[id]/route.ts`
yalnız `GET` + `PATCH` export ediyordu, `DELETE` **yoktu** → Next.js 405 döner.

## 2) BFF DELETE rotası eklendi
`app/api/users/[id]/route.ts`'e `DELETE` handler eklendi (`proxyJson(/users/{id},
"DELETE")`).

## 3) Yumuşak mı sert mi silme — KARAR: AKILLI SİLME
`delete_user` HAM `db.delete` idi ve geçmişi olan (şikayet/talep/devriye
okutma/finans — FK RESTRICT) kullanıcıda **IntegrityError** fırlatıyordu: yönetici
"sil" deyince veri bütünlüğünü bozan bir hata alıyordu. Artık **self-servis
hesap-silme ve sakin-çıkarma ile AYNI** akıllı silme kullanılır
(`hesabi_sil_veya_anonimlestir`):
- **geçmiş YOK** → satır gerçekten gider (`deleted=true`),
- **geçmiş VAR** → kimlik alanları temizlenir, `is_active=false`; defter/denetim
  satırları KALIR (`deleted=false`).

**Gerekçe:** sert silme geçmişi olan kullanıcıda ya bütünlüğü bozar ya (FK
RESTRICT) hiç çalışmaz. Anonimleştirme KVKK'yı (kişisel veri silinir) ve
referans bütünlüğünü (yasal saklanan kayıtlar durur) birlikte sağlar; platformun
geri kalanıyla tutarlıdır. Yanıt artık `200 {deleted:bool}`; web "silindi" ya da
"geçmişi olduğu için anonimleştirildi" mesajını gösterir (yeni i18n anahtarı).

## 4) Davet / daire / oturum
- **Davet:** bekleyen davet **geçersiz kılınır** (satır silinir) — hesap
  gidince/anonimleşince davet bağı tüketilemez olmalı.
- **Daire:** aktif `unit_resident` bağları kapatılır (anonimleştirmede); sert
  silmede satır zaten hesapla gider.
- **Oturum:** `is_active=false` sonraki giriş/yenilemeyi reddeder; cihaz/push
  kayıtları silinir. Access jetonu durumsuz ve kısa ömürlü → doğal olarak biter.

## 5) Yetki (sunucu tarafı) + 6) Denetim
`_yonetim_kapisi` — yönetici yalnız yönettiği rolleri siler, kümesi dışını (örn.
admin) silemez; RLS tenant sınırı zaten var. Denetim: `Action.USER_DELETE`,
meta `{rol, mod: hard_delete|anonymize}` — **hassas değer YOK** (eskiden `ad`
yazılıyordu; kaldırıldı).

## BFF EKSİK-ROTA TARAMASI (P173 kapısı)
Web'in çağırdığı **her** non-GET `/api/...` ucu, eşleşen BFF `route.ts`'te o
metodu export ediyor mu — 57 çağrı tarandı. `panel/[kaynak]/[id]` genel vekili
(icra-dosyaları/mesaj-şablonları/anketler PATCH/DELETE) yanlış-pozitifti.
**İki gerçek eksik daha bulundu ve düzeltildi:**

1. **`PATCH /api/kargo/{id}`** (kargo teslim işaretleme) — BFF'te `kargo/[id]`
   rotası yoktu (yalnız `kargo/route.ts` GET+POST). Backend'de `PATCH
   /kargo/{id}` var. → `app/api/kargo/[id]/route.ts` eklendi.
2. **`POST /api/panel/finans-hareketler/{id}/iptal`** (finans hareket iptali) —
   `panel/[kaynak]/[id]` vekili yalnız 2 segmenti karşılıyor; üç-segmentli
   eylem rotası (`[kaynak]/[id]/iptal`) yoktu. Backend'de `POST
   /finans/hareketler/{id}/iptal` var. → `app/api/panel/[kaynak]/[id]/iptal/
   route.ts` eklendi (kaynak whitelist'ten çözülür, "iptal" eylemi sabit).

Her iki yeni rota UUID doğrular (yol-traversal savunması, panel vekiliyle aynı).

## Test
`test_yapi_yonetimi` güncellendi (204→200, `deleted=true`) + yeni regresyon:
bağlantılı kullanıcı silme 200 döner (405/500 değil). Contract testi (openapi
DELETE yanıtı 200 ResidentDeleteOut) yeşil. Backend tam takım + admin-web koşuldu.
