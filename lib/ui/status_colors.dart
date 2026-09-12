import 'package:flutter/material.dart';

import '../models/component_status.dart';
import 'mh_theme.dart';

/// Consistent colour coding for the manufacturing lifecycle.
Color statusColor(ComponentStatus status) => switch (status) {
      ComponentStatus.pendingPour => const Color(0xFF8E8E8E),
      ComponentStatus.manufactured => const Color(0xFF6A4FB6),
      ComponentStatus.inYard => Mh.accent,
      ComponentStatus.shipped => const Color(0xFFB26A00),
      ComponentStatus.delivered => Mh.ok,
    };
