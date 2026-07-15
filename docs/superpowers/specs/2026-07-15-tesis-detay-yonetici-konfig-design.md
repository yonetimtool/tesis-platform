# Tesis Detay & Yönetici Konfigürasyonu (admin-web)

**Tarih:** 2026-07-15
**Kapsam:** Platform admininin, admin-web *Tesisler* bölümünde bir tesise girip o
tesisin **yönetici hesabını** yönetmesi ve **tenant'ı silmesi**.

## Bağlam

Onboarding Model A ([[auth-onboarding-3-parca-plan]]) ile admin, isimsiz tenant +
yönetici açar; yönetici ilk girişte tesisi adlandırır. Site içeriği (duyuru, ortak
alan, kural, blok/daire, sakin & personel credential'ları) **yöneticinin işi** —
mobil uygulamada, tenant-kapsamlı API'lerle. Bu spec o kısma dokunmaz.

Admin-web *Tesisler* şu an yalnız tenant **oluşturma + listeleme** yapıyor. Bu spec
bir **tesis detay sayfası** ekler: yöneticinin credential/kimlik yönetimi + tenant
silme.

## Mimari

`tenant(id)` alt tabloları `ON DELETE CASCADE` → tenant silinince tüm verisi
(yönetici app_user satırı dahil) temizlenir. `app_user` RLS altında olduğundan
cross-tenant okuma/yazma **owner-sahipli SECURITY DEFINER** fonksiyonlarla yapılır
(mevcut `create_tenant_with_yonetici` / `list_all_tenants` deseni). Tüm uçlar
`require_role("admin")` ile korunur.

**Bir tenant = bir yönetici** varsayımı: yalnız admin `POST /tenants` ile yönetici
açar (tenant başına bir); yönetici yalnız saha personeli + sakin açar. Fonksiyonlar
tenant'ın **en erken oluşturulmuş** `role='yonetici'` satırını "the yönetici" kabul
eder.

## Backend

### Migration — yeni SECURITY DEFINER fonksiyonlar (0001 içine)
- `tenant_detail(p_tenant_id uuid)` → `RETURNS TABLE(tenant_id, tenant_ad,
  kurulum_tamamlandi, tenant_created_at, yonetici_id, yonetici_ad, telefon,
  is_active, password_set)`. Tenant + en erken yöneticiyi döndürür (yönetici yoksa
  yönetici alanları NULL).
- `update_tenant_yonetici(p_tenant_id, p_user_id, p_ad, p_telefon, p_is_active)` →
  ilgili app_user'ı (tenant + role=yonetici + id eşleşmesi) günceller. NULL parametre
  = o alan değişmez. Telefon global benzersiz → çakışmada `unique_violation`.
- `reset_tenant_yonetici_credential(p_tenant_id, p_user_id, p_temp_code_hash)` →
  `password_hash=NULL, password_set=false, temp_code_hash=<yeni>, setup_token=NULL`.
- `delete_tenant(p_tenant_id)` → `DELETE FROM tenant WHERE id=p_tenant_id` (cascade).
  RESTRICT FK'lere (scan/task_completion/asset_assignment/complaint → app_user)
  takılırsa test aşamasında çözülür (gerekirse fonksiyon içinde önce alt temizlik).

Hepsi `SECURITY DEFINER SET search_path=''`, `REVOKE ... FROM PUBLIC` + `GRANT
EXECUTE ... TO app_rw`. Downgrade'e `DROP FUNCTION` satırları eklenir.

### Router (`app/routers/tenants.py`)
- `GET /tenants/{tenant_id}` → `TenantAdminDetail`
- `PATCH /tenants/{tenant_id}/yonetici` (`TenantYoneticiUpdate` {ad?, phone?,
  is_active?}) → güncel `TenantAdminDetail`. Telefon çakışması → 409. Yönetici yoksa
  → 404.
- `POST /tenants/{tenant_id}/yonetici/reset-credential` → `{temp_code}` (yeni tek
  seferlik kod). Yönetici yoksa → 404.
- `DELETE /tenants/{tenant_id}` → 204. Bilinmeyen tenant → 404.

### Şemalar (`app/schemas.py`)
- `TenantAdminDetail` {tenant_id, ad, kurulum_tamamlandi, created_at,
  yonetici: TenantYoneticiOut | None}
- `TenantYoneticiOut` {id, ad, telefon, is_active, password_set}
- `TenantYoneticiUpdate` {ad?: str(2..120), phone?: str, is_active?: bool}
- `TenantYoneticiResetOut` {temp_code: str}

## admin-web

- **Liste satırı tıklanabilir** → `next/link` ile `/tenants/[id]`.
- **`app/(protected)/tenants/[id]/page.tsx`:** yönetici kartı (ad, telefon, durum,
  kurulum durumu/tesis adı) + işlemler:
  1. *Parola sıfırla / geçici kod üret* → `temp_code` alert (kopyalanabilir).
  2. *Düzenle* (ad/telefon) — inline form → PATCH.
  3. *Aktif/Pasif* toggle → PATCH `is_active`.
  4. *Tesisi sil* — tesis adını yazarak onay → DELETE → listeye dön.
- **API proxy route'ları:** `app/api/tenants/[id]/route.ts` (GET, DELETE),
  `app/api/tenants/[id]/yonetici/route.ts` (PATCH),
  `app/api/tenants/[id]/yonetici/reset-credential/route.ts` (POST).

## Sözleşmeler
- `contracts/openapi.yaml`: yeni path'ler + şemalar.
- `contracts/auth.md`: RBAC tablosuna yeni admin uçları (§1.4/§ matris).

## Test (`backend/tests/test_tenants.py`)
- Detay getir (tenant + yönetici alanları).
- Yönetici ad/telefon güncelle; telefon çakışması → 409.
- reset-credential → yeni temp_code ile yönetici tekrar ilk-giriş akışına düşer
  (`password_setup_required=true`).
- Aktif/pasif → pasif yöneticinin girişi engellenir.
- delete tenant → GET /tenants listesinde yok; RBAC: yalnız admin (403 diğerleri).
- Cascade: seed verili tenant silinebiliyor (RESTRICT'e takılmıyor).

## Riskler
- **delete_tenant RESTRICT:** scan/task_completion/asset_assignment/complaint →
  app_user `ON DELETE RESTRICT`. Tenant cascade sırasında sıralama sorun çıkarırsa
  fonksiyon içinde bağımlı satırlar önce silinir. Test ile doğrulanacak.
- **Yalnız-yönetici-sil YOK:** tenant sahipsiz kalmasın diye silme tenant
  seviyesinde. Yönetici düzeltme = ad/telefon düzenle + parola sıfırla.
