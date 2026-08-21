# P176 — Takvim varsayılan görünümü (rapor)

> Kısa cevap: **evet, ay görünümü mobilde okunur** — çünkü P169'un
> gerekçesini P170 zaten ortadan kaldırmıştı. Varsayılan AY yapıldı,
> ajanda duruyor, seçim kalıcı.

---

## 1. Önce senin uyarın: P169'un gerekçesi hâlâ geçerli mi?

**Hayır, ve sebebi net.**

P169'da dar ekranda ajandaya geçiliyordu; gerekçe *"ay ızgarası
okunmuyor"*du ve **o gün doğruydu**: hücreler 80 px yüksekliğindeydi ve
içine olay **adı** yazılmaya çalışılıyordu — ad ~45 px'lik bir kutuda iki
harfe düşüyordu.

**P170 §4.2 bunu zaten düzeltmişti:** dar ekranda hücre 56 px'e iniyor ve
olay adı yerine **nokta** çiziliyor (`sm:hidden` nokta satırı /
`hidden sm:block` etiketli liste). Yani okunmazlığın sebebi bu turdan önce
kalkmıştı; geriye yalnız **varsayılan** kalmıştı.

## 2. 360 px ölçümü

```
360 − 32 (sayfa px-4) − 32 (kart p-kart) − 24 (altı gap-1) = 272
272 / 7 = ~38,9 px hücre  →  ~30,9 px iç genişlik (p-1 düşülünce)
```

İçeriği:
* gün numarası — `--yz-fs-xs` = 12 px, "31" ≈ 13 px genişlik,
* en çok **dört nokta**: 4×6 + 3×2 = **30 px** → 30,9 px'e sığar,
* sığmadığı durumda `flex-wrap` alt satıra sarıyor (hücre 56 px yüksek),
* fazlası `+N` ile yazılıyor,
* gün başlıkları 3 harflik kısaltma (`Pzt`) ≈ 20 px.

**Yatay kaydırma yapısal olarak imkânsız:** ızgara
`repeat(7, minmax(0, 1fr))` kullanıyor — sütunlar içeriğe göre
genişlemiyor. Sabit genişlik ya da `auto` olsaydı uzun bir olay adı
ızgarayı taşırırdı.

> Dürüst sınır: jsdom'da **piksel yerleşimi yoktur**. Testler yukarıdaki
> **yapısal** garantileri ölçüyor (nokta gösterimi, hücre yüksekliği,
> `minmax(0,1fr)`, `flex-wrap`); "göze nasıl görünüyor" ölçülmedi ve
> ölçüldüğü iddia edilmiyor. Aritmetik yukarıda açık; gerçek cihazda
> kontrol maddesi aşağıda.

## 3. Yapılanlar

* **Varsayılan her bantta AY.** Bant otomatiği (`dar && !secildiRef`)
  kaldırıldı; `useBant` bu bileşende artık kullanılmıyor.
* **Ajanda sekmesi duruyor** — araç çubuğunda, kaldırılmadı.
* **Seçim kalıcı** (`localStorage`, `yonetio.takvim.gorunum`).
  Bozuk/bilinmeyen kayıt varsayılana düşüyor, takvimi kırmıyor; depolama
  erişilemezse (özel kip) tercih yok sayılıyor.

**Neden `localStorage`, neden sunucu değil:** görünüm tercihi bir **cihaz
alışkanlığıdır**, hesap ayarı değil. Telefonda ajanda, masaüstünde ay
isteyen bir kullanıcının ikisi de doğru; sunucuya yazmak bu ikisini
birbirine ezdirirdi. Kabuk menüsünün açık/kapalı durumu da aynı gerekçeyle
`localStorage`ta.

**Kayıtlı tercih etkide uygulanıyor, başlangıç değerinde değil:** ilk kare
sunucuda çiziliyor ve orada `localStorage` yok; başlangıç değerinde okumak
hidrasyon uyuşmazlığı olurdu. Sunucu ve ilk istemci karesi aynı şeyi (ay)
çiziyor, kullanıcının kaydı hemen ardından geliyor.

## 4. Kilitler

`tests/takvim-gorunum.dom.test.ts` (10): dar ve geniş bantta varsayılan
ay; ajanda sekmesi duruyor; seçim kaydediliyor; kayıtlı tercih açılışta
uygulanıyor; bozuk kayıt kırmıyor; ve dört yapısal okunurluk garantisi.

**Kırılabildiği kanıtlandı:** eski P169 davranışı geri kondu → üç test
kırıldı.

**Yönü değiştirilen kilit:** `duyarli-widget-takvim.dom.test.ts` P170'te
`secildiRef` ve dar-ekran otomatiğini kilitliyordu. Kaldırılmadı, yön
değiştirdi: artık `secildiRef` **olmadığını**, ajandanın **durduğunu** ve
seçimin **kalıcı** olduğunu ölçüyor. Nokta gösterimi/hücre yüksekliği
iddiaları aynen duruyor — okunurluğu sağlayan şey onlar.

## 5. Test sunucusunda ne kontrol edeceksin

1. Telefondan Özet: takvim **Ay** ile açılmalı; hücrelerde gün numarası +
   renkli noktalar görünmeli, **yatay kaydırma olmamalı**.
2. **Ajanda**'ya geç, sayfayı yenile — **ajandada kalmalı**. Sonra Ay'a
   dön, yenile — ayda kalmalı.
3. 360 px'te (ör. iPhone SE / tarayıcı cihaz kipi) hücrelerin ezilmediğini
   ve gün numaralarının okunduğunu gör. Okunmuyorsa söyle — nokta sayısını
   üçe indirmek ya da hücreyi yükseltmek tek satırlık ayar.
