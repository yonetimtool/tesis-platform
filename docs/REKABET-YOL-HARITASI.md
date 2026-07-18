# Rekabet Analizi ve Yol Haritası — Apsiyon (Blue/Black/Ek) tam paket karşılaştırması
Güncelleme: 2026-07-18 · Kaynak: apsiyon.com/urunler/apsis + resmi paket PDF'i

## Apsiyon paket mimarisi
- BLUE: finans+iletişim çekirdeği dahil. BLACK: Blue + Pro modüller. EK ÜCRETLİ: 15 modül her pakete ayrıca satılır.
- Lejant: ✓=dahil · ✗=yok · ₺=ek ücret · K=kurumsal paket

## Tam özellik tablosu (Apsiyon Blue/Black/₺ → bizde durum)
| Özellik | Apsiyon | Bizde | Not |
|---|---|---|---|
| Kişi/Daire CRM | Blue ✓ | KISMEN | Malik/kiracı ayrımı yok |
| Aidat Takibi | Blue ✓ | KISMEN | Dağıtım tipleri (eşit/m²/arsa/kişi) yok |
| İcra Takibi | Blue ✓ | YOK | |
| Oto. Gecikme Tazminatı | Blue ✓ | YOK | |
| İşletme Projesi | Blue ✓ | YOK | |
| Cari/Firma Takibi | Blue ✓ | YOK | |
| Finans ve Raporlama | Blue ✓ | KISMEN | İşletme defteri/mizan yok |
| Online Banka Entegrasyonu | Blue ✓ | YOK | Dış anlaşma gerekir |
| ATS Entegrasyonu | Blue ✓ | YOK | |
| Kart ile Online Tahsilat | Blue ✓ | YOK | iyzico/PayTR planlı |
| İş Takibi ve Talep Yönetimi | Blue ✓ | KISMEN→%70 | Şikayet+görev var; foto+iş emri eksik (DÜZELTME: Apsis'te de temelde varmış) |
| Yetkilendirme | Blue ✓ | VAR | 5 rol RBAC |
| E-Posta/SMS/Push/WhatsApp | Blue ✓ | KISMEN | Push var; e-posta/SMS/WA yok |
| Barkodlu Posta Dökümü | Blue ✓ | YOK | |
| Araç Tanımlama | Blue ✓ | KISMEN | Ziyaretçi plakası var; sakin araç kaydı yok |
| Web Sitesi (apartman sayfası) | Blue ✓ | YOK | |
| Sakin + Yönetici Mobil | Blue ✓ | VAR | Tek uygulama 5 rol |
| Canlı Destek | Blue ✓ | YOK | Hizmet kalemi |
| Kurumsal Ekranlar | K | YOK | |
| Çek/Senet | Black | YOK | |
| Sözleşmeler (cari/kira) | Black | YOK | |
| Demirbaş Takibi | Black | VAR | Assets+zimmet modülümüz (DÜZELTME: VAR'a geçti) |
| Stok Takibi | Black | YOK | |
| Araç Geçiş Takibi | Black | YOK | PTS donanım-bağımlı |
| Sayaç Takibi | Black | YOK | |
| Kargo Takibi | Black | VAR | Bizde temelde |
| Ziyaretçi Takibi | Black | VAR | Bizde temelde + KVKK tek-seferlik izin |
| Portföy Yöneticisi | Black | YOK | Hizmet kalemi |
| Muhasebe (Mizan/Bilanço) | ₺ | YOK | GİB/entegratör ağır |
| Bordro + SGK | ₺ | YOK | Uzak dur (uzmanlık alanı değil) |
| Satın Alma | ₺ | YOK | |
| Bakım Onarım/Arıza | ₺ | KISMEN %70 | Bizde TEMELDE olacak — satış kozu |
| Tur Kontrol | ₺ | VAR | NFC devriye ÇEKİRDEĞİMİZ — onlarda ek ücret |
| Rezervasyon + Pano | ₺(x2) | VAR | Bizde temelde — onlarda iki ayrı ücret |
| IVR Santral | ₺ | YOK | |
| Uzaktan Sayaç | ₺ | YOK | Donanım |
| PTS / KGS / HGS | ₺ | YOK | Donanım-bağımlı |
| QR Geçiş | ₺ | KISMEN | NFC bazlı sistemimiz muadil; QR eklenebilir |
| CCTV | ₺ | YOK | Donanım |

## KONUM / SATIŞ MESAJI
"Apsiyon'un EK ÜCRETLE sattığı operasyon modülleri (tur kontrol, rezervasyon, arıza takibi) ve
Black'e sakladıkları (ziyaretçi, kargo, demirbaş) bizde PAKETE DAHİL." Fark: onlar finanstan
büyüdü operasyonu ücretlendiriyor; biz operasyondan büyüyoruz finansı ekleyeceğiz.

## Farklılaştırıcılar (özet — detay önceki analiz)
AI asistan temel pakette (ÇOK YÜKSEK etki, KVKK anonimleştirme şart) · ML banka eşleştirme (banka
verisi önkoşul) · Genel kurul modülü (KMK hukuki kontrol) · Şeffaflık panosu (kolay, güven kozu) ·
Esnek fiyatlandırma (8-15 daire segmenti) · e-Fatura/muhasebe (ağır, sonra) · WhatsApp (BSP+ücret).

## Uygulama sırası (dalgalar)
- DALGA 1 (bağımsız): Ticketing tamamlama (foto+iş emri+durum) → Şeffaflık panosu →
  Malik/kiracı + aidat dağıtım tipleri + oto. gecikme tazminatı → toplu e-posta (SMTP)
- DALGA 2 (orta): Genel kurul → Sayaç takibi+sihirbaz → Cari/firma → İşletme defteri/projesi →
  SMS (Netgsm) → Sözleşmeler → Stok → sakin araç tanımlama
- DALGA 3 (dış bağımlı): Sanal POS (iyzico sandbox AL) → AI asistan → WhatsApp → banka eşleştirme
  → e-Fatura → apartman web sitesi → QR geçiş
- BİLİNÇLİ UZAK DURULANLAR (şimdilik): Bordro/SGK, IVR, PTS/KGS/HGS/CCTV (donanım), çek/senet.

## Diğer bekleyenler
Production (sunucu+domain+TLS+yedek+KVKK: audit log, saklama-imha) · iOS dağıtım · çoklu dil (EN SON)
· gürültü istatistik+grafik · bilgilendirme/oryantasyon · CAPS · 3B bina (ops.) · telefon gözle
testleri (SOS/iletişim/logo) · web Faz 1+2 görsel inceleme.
