# Site sakini: düzenle + akıllı sil + parola sıfırla

Tarih: 2026-07-15 · Kapsam: backend + contracts + mobil · Branch: main

## Sorun / İstek

Yönetici sakini yalnız pasife alabiliyordu ("Çıkar"); telefon üstünde kaldığı için
aynı numarayla yeniden kayıt "zaten kayıtlı" hatası veriyordu. İstenenler:
- Sakini **silebilme** (özellikle hatalı/yeni kayıt) → numara serbest kalsın.
- **Düzenleme** (ad / numara değişimi).
- **Parola sıfırlama** (kilitlenme / parola unutma).

## Karar (onaylandı)

- **(A) Akıllı sil:** geçmişi YOKSA tamamen sil (numara boşalır); geçmişi VARSA
  (FK RESTRICT) pasife al + **telefonu boşalt** (kayıt denetim için kalır, numara
  serbest). Tek "Sil"; her durumda numara serbest kalır.

## Backend — `/residents` router (yönetici + admin)

- **`PATCH /residents/{id}`** — `ResidentUpdate { ad?, telefon? }` (en az bir).
  telefon normalize + global benzersiz (çakışma 409). role=resident değilse 404.
  Numarayı boş bırakmak = değişmez. Dönüş 204.
- **`POST /residents/{id}/reset-password`** — yeni geçici kod üretir
  (`temp_code_hash=hash`, `password_set=false`, `password_hash=NULL`); yanıtta
  `{ temp_code }` bir kez döner. role=resident değilse 404.
- **`DELETE /residents/{id}`** (akıllı sil, mevcut davranışın yerine):
  - SAVEPOINT içinde `DELETE FROM app_user` dener. Başarılı → tamamen silindi
    (unit_resident/rsvp/device CASCADE ile gider), telefon serbest.
    `{ deleted: true }`.
  - `IntegrityError` (FK RESTRICT — şikayet/rezervasyon vb.) → savepoint geri
    alınır; aktif daire bağları `bitis=now`, `is_active=false`, **`telefon=NULL`**.
    `{ deleted: false }`.
  - role=resident değilse 404.

Şemalar: `ResidentUpdate`, `ResidentResetPasswordOut { temp_code }`,
`ResidentDeleteOut { deleted }`.

## Contracts
- `auth.md` §4 matris: `PATCH /residents/{id}`, `POST /residents/{id}/reset-password`
  (admin+yönetici). DELETE davranış notu güncellenir.
- `openapi.yaml`: iki yeni uç + şemalar; DELETE yanıtı `{deleted}`.

## Mobil — residents_screen
- Sakin satırında "Çıkar" butonu yerine **⋮ menü**: Düzenle · Parola sıfırla · Sil.
  - **Düzenle:** alt sayfa (Ad + "Yeni cep telefonu (boş=değişmez)") → PATCH → liste yenilenir.
  - **Parola sıfırla:** onay → POST → geçici kod dialog.
  - **Sil:** onay → DELETE → sonuç SnackBar ("silindi" / "pasife alındı, numara serbest").
- `residents_api`: `updateResident(id, ad?, telefon?)`, `resetPassword(id)->tempCode`,
  `removeResident(id)->deleted:bool`.

## Test
- `test_residents.py`:
  - PATCH ad+telefon; başka sakinin numarasına çakışma 409; non-resident 404.
  - reset-password → temp_code; o telefon+yeni kod ile login-phone setup akışı; RBAC.
  - Akıllı sil: geçmişsiz sakin → deleted:true, aynı numarayla yeniden POST 201
    (numara serbest). Geçmişli sakin (o sakin bir complaint açsın) → deleted:false
    (pasif), aynı numarayla yeniden POST 201 (numara serbest).
  - RBAC (security/tesis_gorevlisi/resident → 403).
- `flutter analyze` temiz.

## Kabul
Yönetici sakini düzenler, parolasını sıfırlar, siler (numara her durumda serbest);
hatalı kayıt tamamen silinir; geçmişli sakin pasifleşir ama numara serbest kalır.
