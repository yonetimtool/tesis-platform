import 'package:flutter/material.dart';

import '../domain/task_models.dart';

/// Gorev tipinin liste/detayda ortak gorunumu (renk + ikon + etiket).
({Color color, IconData icon, String label}) taskTipStyle(TaskTip tip) =>
    switch (tip) {
      TaskTip.temizlik => (
          color: Colors.teal,
          icon: Icons.cleaning_services_outlined,
          label: 'Temizlik',
        ),
      TaskTip.kontrol => (
          color: Colors.indigo,
          icon: Icons.fact_check_outlined,
          label: 'Kontrol',
        ),
      TaskTip.ilaclama => (
          color: Colors.orange,
          icon: Icons.pest_control_outlined,
          label: 'İlaçlama',
        ),
      TaskTip.bakim => (
          color: Colors.brown,
          icon: Icons.build_outlined,
          label: 'Bakım',
        ),
      TaskTip.peyzaj => (
          color: Colors.green,
          icon: Icons.grass_outlined,
          label: 'Peyzaj',
        ),
      TaskTip.diger => (
          color: Colors.blueGrey,
          icon: Icons.task_alt_outlined,
          label: 'Diğer',
        ),
      TaskTip.bilinmiyor => (
          color: Colors.grey,
          icon: Icons.help_outline,
          label: 'Bilinmiyor',
        ),
    };
