import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcons {
  static const Map<String, String> _paths = {
    'grid': '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
    'box': '<path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="m4 7 8 4 8-4v10l-8 4-8-4V7Z"/><path d="M12 11v10"/>',
    'cart': '<path d="M3 4h2l2.3 10.2a2 2 0 0 0 2 1.6h7.9a2 2 0 0 0 2-1.7L20.5 7H6"/><circle cx="9" cy="20" r="1"/><circle cx="18" cy="20" r="1"/>',
    'sale': '<path d="M4 6h16v14H4z"/><path d="M8 6V4h8v2M8 11h8M8 15h5"/>',
    'stock': '<path d="M4 5h16v5H4zM5 10h14v10H5zM9 14h6"/>',
    'factory': '<path d="M3 21V9l6 3V8l6 4V5h6v16H3Z"/><path d="M7 17h2m4 0h2m4 0h2"/>',
    'truck': '<path d="M3 6h11v11H3zM14 10h4l3 4v3h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/>',
    'users': '<circle cx="9" cy="8" r="4"/><path d="M2 21a7 7 0 0 1 14 0M16 4a4 4 0 0 1 0 8m2 3a6 6 0 0 1 4 6"/>',
    'calendar': '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01"/>',
    'wallet': '<path d="M4 5h14a2 2 0 0 1 2 2v13H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z"/><path d="M16 11h6v5h-6a2.5 2.5 0 0 1 0-5Z"/>',
    'report': '<path d="M5 3h14v18H5z"/><path d="M9 17v-4m3 4V9m3 8v-6"/>',
    'settings': '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z"/>',
    'search': '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
    'bell': '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
    'plus': '<path d="M12 5v14M5 12h14"/>',
    'arrow': '<path d="m9 18 6-6-6-6"/>',
    'print': '<path d="M6 9V3h12v6M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 14h12v7H6z"/>',
    'download': '<path d="M12 3v12m-5-5 5 5 5-5M4 21h16"/>',
    'filter': '<path d="M3 5h18l-7 8v6l-4 2v-8L3 5Z"/>',
    'more': '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
    'check': '<path d="m5 12 4 4L19 6"/>',
    'warning': '<path d="M12 3 2 21h20L12 3Z"/><path d="M12 9v5m0 3h.01"/>',
    'cash': '<rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="12" cy="12" r="3"/><path d="M6 9H5v1m13-1h1v1M6 15H5v-1m13 1h1v-1"/>',
    'trend': '<path d="m3 17 6-6 4 4 8-9m-5 0h5v5"/>',
    'close': '<path d="m6 6 12 12M18 6 6 18"/>',
    'menu': '<path d="M4 7h16M4 12h16M4 17h16"/>',
    'eye': '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  };

  static String _colorToHex(Color color) {
    return '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  static Widget icon(
    String name, {
    double size = 18,
    Color? color,
    double strokeWidth = 1.8,
  }) {
    final path = _paths[name] ?? '';
    final strokeColor = _colorToHex(color ?? const Color(0xFF667085));

    final svgString = '''
<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$strokeColor" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">
  $path
</svg>
''';

    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
      key: ValueKey('icon_${name}_${size}_$strokeColor'),
    );
  }
}
