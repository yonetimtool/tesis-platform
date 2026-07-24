import 'package:flutter/material.dart';

import '../../../../core/text/tr_upper.dart';
import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';

/// [VardiyaDurum] → cip etiketi + rengi (referans: AKTİF yesil, PLANLANDI
/// mavi, YÖNETİCİ mor).
extension VardiyaDurumStil on VardiyaDurum {
  String get etiket => switch (this) {
        VardiyaDurum.aktif => 'Aktif',
        VardiyaDurum.planlandi => 'Planlandı',
        VardiyaDurum.yonetici => 'Yönetici',
      };

  Color get renk => switch (this) {
        VardiyaDurum.aktif => HomeTokens.green,
        VardiyaDurum.planlandi => HomeTokens.primary,
        VardiyaDurum.yonetici => HomeTokens.purple,
      };
}

/// Referans "Vardiya Durumu" seridindeki tek kart: vardiya adi + saat araligi
/// (ya da yonetici adi), 56px yuvarlak avatar + yesil online noktasi, durum
/// cipi, altta kisi ikonu + "2 Görevli" (ya da yesil nokta + "Online").
class ShiftStatusCard extends StatelessWidget {
  const ShiftStatusCard({super.key, required this.kart});

  final VardiyaKart kart;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return HomeCard(
      width: HomeTokens.shiftCardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kart.baslik,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HomeText.cardTitle.copyWith(color: s.heading),
          ),
          const SizedBox(height: 3),
          Text(
            kart.altBaslik,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HomeText.rowSub.copyWith(color: s.muted),
          ),
          const SizedBox(height: 10),
          _Avatar(kart: kart),
          const SizedBox(height: 10),
          HomeChip(label: trUpper(kart.durum.etiket), accent: kart.durum.renk),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (kart.online)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: HomeDot(color: HomeTokens.online),
                )
              else ...[
                Icon(Icons.groups_outlined, size: 15, color: s.muted),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  kart.altBilgi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.rowSub.copyWith(color: s.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 56px avatar + sag altta yesil online noktasi (kart zeminiyle cerceveli).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.kart});

  final VardiyaKart kart;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final accent = kart.durum.renk;
    return SizedBox(
      width: 60,
      height: 56,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: HomeTokens.tint(accent),
            backgroundImage:
                kart.avatarUrl != null ? NetworkImage(kart.avatarUrl!) : null,
            child: kart.avatarUrl == null
                ? Icon(Icons.person, color: accent, size: 28)
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: HomeTokens.online,
                shape: BoxShape.circle,
                border: Border.all(color: s.card, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
