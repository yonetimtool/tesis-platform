# P211 — Yönetici girişi, panel yönlendirme, tahsilat, mesai ücreti, iOS bildirim, ikon

> **Numara notu.** Bu turu sen "P210" diye adlandırdın, ama `docs/P210-kararlar.md`
> zaten **ses dosyaları turunun** kararlarını tutuyor (üçüncü kanal + `_v2` geçişi).
> Var olan belgeyi ezmemek için bu tur **P211** numarasıyla yazıldı; koddaki
> yorum etiketleri de `(P211 §n)` biçiminde. Aynı işin iki adı olmasın diye
> not düşüyorum.

---

## §1 — Yönetici girişi: SSO düğmeleri ve "Tesis ID" sorusu

### ÖLÇÜM 1 — SSO düğmeleri mobilde neden görünmüyor?

**Kod kusuru değil, yapılandırma.** Ölçüm:

```
$ curl -s api:8000/auth/oauth/saglayicilar
{"saglayicilar":[]}
```

`app/oauth.py::Saglayici.hazir` bir sağlayıcıyı ancak `istemci_id` **ve**
`izinli_aud` doluysa "hazır" sayar; uç yalnızca hazır olanları listeler.
Bu geliştirme makinesinde `infra/.env` içinde **hiçbir** OAuth değişkeni
yok (`.env.example`'da hepsi yorum satırı). Mobil `SosyalGirisDugmeleri`
liste boşsa **hiç çizilmez** — tasarım gereği: yapılandırılmamış bir
düğmeye basmak kullanıcıyı sağlayıcının hata sayfasına atardı.

**Sonuç:** düğmelerin görünmesi için sunucuda şu değişkenler dolu olmalı
(prod `.env`'ini ben göremiyorum, ölçemediğim kısım bu):

| Değişken | Ne | Zorunlu mu |
|---|---|---|
| `OAUTH_GOOGLE_CLIENT_ID` | Google **Web** client id | Google için evet |
| `OAUTH_GOOGLE_CLIENT_SECRET` | aynı client'ın sırrı | evet |
| `OAUTH_GOOGLE_AUD` | virgüllü ek `aud` listesi (mobil client id'leri) | Google mobilde de kullanılacaksa |
| `OAUTH_APPLE_CLIENT_ID` | Services ID (`com.app.yonetiyor.web`) | Apple için evet |
| `OAUTH_APPLE_TEAM_ID` / `OAUTH_APPLE_KEY_ID` / `OAUTH_APPLE_PRIVATE_KEY` | client_secret JWT'si için | evet |
| `OAUTH_APPLE_AUD` | web Services ID + iOS bundle id | iOS'ta Apple ile giriş için |
| `OAUTH_MICROSOFT_CLIENT_ID` / `_SECRET` | Microsoft | isteğe bağlı |
| `OAUTH_CALLBACK_TABAN` | `https://api.yonetiyor.com` | evet |

Testle kilitlenen kısım: sağlayıcı listesi **doluyken** düğmelerin
gerçekten çizildiği (`p211_sso_tesis_secimi_test.dart`, 1. test) — yani
"liste dolduğunda arayüz tarafında bir kusur kalmadı" ölçülmüş oldu.

### ÖLÇÜM 2 — "Tesis ID" neden soruluyordu?

Kırılma noktası **backend**'de, `oauth.py::_eslesme`: doğrulanmış e-posta
ile eşleşen yönetici satırı **birden fazlaysa** akış "tekil değil" sayılıp
`baglama_gerekli` dönüyordu; hem web hem mobil bu duruma **Tesis ID formu**
çiziyordu. Yani kodu hiç ezberlemeyen, en çok tesisi olan kişiden
ezberlemesini istiyorduk. Tek tesisli yöneticide akış zaten doğruydu
(`mevcut_hesap`/`giris`).

### KARAR K1 — Çok tesiste `tesis_secimi`, Tesis ID **sorulmaz**

`/auth/oauth/sonuc` artık `durum="tesis_secimi"` + `secim_jetonu` +
tesis **adları** döner. Yeni uç: `POST /auth/oauth/tesis-sec`.

**Gerekçe ve güvenlik sınırı:** `secim_jetonu` yetki **vermez**, yalnız
"şu doğrulanmış adres şu tesislerde yöneticidir" bilgisini taşır ve
`getdel` ile **tek kullanımlıktır**. İstekteki `tenant_id` jetondaki aday
listesinde olmak **zorundadır**; olmazsa 403 `tesis_uyeligi_yok` — aksi
hâlde uç "istediğim tesisin jetonunu al" ucuna dönüşürdü. Ret mesajı
"böyle tesis yok" ile "üye değilsin" arasını **ayırt ettirmez** (P203 §2
`tesis-degistir` ile aynı kural).

Seçimden sonra kimlik o tesise **bağlanır** (`_kimligi_bagla`), böylece
bir sonraki girişte seçim sorulmaz.

### Kapsam
- Backend: `oauth.py` (+7 test), şema, openapi, rol-matrisi.
- Mobil: seçim ekranı — `sso-tesis-secimi` (+4 test).
- Web: `/giris/oauth` `tesis_secimi` dalı + BFF `/api/auth/oauth/tesis-sec`
  (+4 test). Jetonlar gövdede geçmez, httpOnly çereze yazılır.

### Ölçemediğim
Gerçek Google/Apple ile uçtan uca giriş: dev'de sağlayıcı yapılandırması
yok (yukarıdaki tablo). Taklit HTTP katmanına konuldu (P200 dersi);
sağlayıcıdan dönen `sonuc_id` sonrası **tüm** akış gerçek kodla sürüldü.
