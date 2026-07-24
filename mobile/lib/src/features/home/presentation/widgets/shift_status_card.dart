import 'package:flutter/material.dart';

import '../../../../core/text/tr_upper.dart';

/// Vardiya kartinin durumu → cip etiketi + rengi.
enum ShiftStatus {
  aktif('Aktif', Color(0xFF16A34A)), // yesil
  planlandi('Planlandı', Color(0xFF2563EB)), // mavi
  yonetici('Yönetici', Color(0xFF7C3AED)); // mor

  const ShiftStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Referans "Vardiya Durumu" bolumundeki tek kisi karti: avatar (opsiyonel
/// online noktasi) + vardiya adi + saat araligi / kisi + durum cipi + alt
/// satirda gorevli sayisi ("👥 2 Görevli") ya da "● Online". Yatay listede
/// kullanilir (sabit genislik).
class ShiftStatusCard extends StatelessWidget {
  const ShiftStatusCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.footer,
    this.online = false,
    this.avatarUrl,
  });

  final String title;
  final String subtitle;
  final ShiftStatus status;
  final String footer;
  final bool online;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 10),
              _Avatar(color: status.color, online: online, avatarUrl: avatarUrl),
              const SizedBox(height: 10),
              _StatusChip(status: status),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (online)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: _Dot(color: Color(0xFF16A34A)),
                    )
                  else
                    Icon(Icons.groups_outlined, size: 14, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      footer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.online, this.avatarUrl});

  final Color color;
  final bool online;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.12),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null ? Icon(Icons.person, color: color) : null,
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).cardColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ShiftStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        trUpper(status.label),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: status.color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
