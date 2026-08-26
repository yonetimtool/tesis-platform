# P181 — Kararlar, gerekçeler, bulunan eksikler

Kesintisiz mod. Her ana bölüm ayrı commit + push. Geliştirme ortamında çalışıldı
(192.168.20.101, docker-compose.yml). Sert sınırlar korundu: SMS yok (tek kanal
e-posta, mail.yonetiyor.com/noreply@yonetiyor.com); mevcut giriş yolları + api.
yonetio.site bozulmadı (yeni akışlar EK yol); P180 email_verified kuralı korundu;
yeni env → .env.prod.example + docker-compose.prod.yml birlikte güncellenir.

Bu belge bölüm bölüm doldurulur; her bölüm bitince ilgili commit'e referans verir.

---

## Bölüm 0 — P180 artığı: "Hesabınız yok mu?" bağlantısı

**Durum:** Giriş ekranında (`GirisFormu`) zaten `/kayit`'a bir kayıt bağlantısı
VAR (app.yonetiyor.com'un kendi kayıt akışı). Eksik olan **bağlama ekranı**:
sosyal giriş yapıp hesabı olmayan kullanıcı `/giris/oauth` "tesis" (tesis kodu +
telefon) adımına düşüyor ve oradan kayda dönüş yok.

**Karar:** Bağlama ("tesis") ekranına "Hesabınız yok mu? → Yönetici olarak
kaydolun" bağlantısı eklendi; hedef **kanonik** `https://yonetiyor.com/yonetici/
kayit`.

**Neden env değil, sabit kanonik URL:** Bu, adres politikasındaki SABİT tanıtım
kayıt adresidir (P179). Yeni bir build-time değişken eklemek (ve compose/örnek
dosyaya geçirmek) statik bir pazarlama URL'si için gereksiz yüzey olurdu. Test
sunucusu (rollback) ayrıca ele alınır. Backend giriş niyetinde **sessizce hesap
açmaz** (P180 kuralı); bu yalnız yönlendirme afordansıdır — güvenlik değişmez.

- i18n: `sosyalHesabinYok`, `sosyalKayitOl` 7 dile eklendi (parity testi yeşil).
