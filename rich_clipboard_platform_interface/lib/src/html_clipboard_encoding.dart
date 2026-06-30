/// Helpers for writing HTML to the system clipboard with an explicit UTF-8
/// charset declaration.
///
/// Cocoa apps (including WhatsApp on iOS) load `public.html` pasteboard bytes
/// via WebKit/NSAttributedString and default to Latin-1 when no charset is
/// declared, turning "ä" into "Ã¤". WebKit addresses this by prepending
/// `<meta charset="UTF-8">` when copying non-ASCII HTML.

const _kMetaCharsetUtf8 = '<meta charset="UTF-8">';

/// Returns true when [html] already declares a character encoding.
bool htmlHasCharsetDeclaration(String html) {
  final lower = html.toLowerCase();
  return lower.contains('charset=');
}

/// Returns true when [html] contains non-ASCII Unicode scalar values.
bool htmlContainsNonAscii(String html) {
  return html.runes.any((rune) => rune > 0x7F);
}

/// Prepends a UTF-8 charset meta tag when needed so receiving apps decode HTML
/// clipboard bytes correctly.
///
/// No-op for empty HTML, ASCII-only HTML, or HTML that already declares charset.
String prepareHtmlForClipboard(String html) {
  if (html.isEmpty) {
    return html;
  }
  if (htmlHasCharsetDeclaration(html) || !htmlContainsNonAscii(html)) {
    return html;
  }
  return '$_kMetaCharsetUtf8$html';
}

/// Removes a leading UTF-8 charset meta tag added by [prepareHtmlForClipboard].
///
/// Used when reading clipboard HTML back into the app so consumers receive the
/// original fragment/document markup.
String normalizeHtmlFromClipboard(String html) {
  var result = html;
  if (result.startsWith(_kMetaCharsetUtf8)) {
    return result.substring(_kMetaCharsetUtf8.length);
  }

  final lower = result.toLowerCase();
  const patterns = [
    '<meta charset="utf-8">',
    "<meta charset='utf-8'>",
    '<meta charset="UTF-8">',
    "<meta charset='UTF-8'>",
  ];
  for (final pattern in patterns) {
    if (lower.startsWith(pattern)) {
      return result.substring(pattern.length);
    }
  }

  return result;
}
