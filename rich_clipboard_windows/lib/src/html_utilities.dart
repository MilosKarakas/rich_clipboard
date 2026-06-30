import 'dart:convert' show utf8;

import 'package:rich_clipboard_platform_interface/rich_clipboard_platform_interface.dart';

const _kStartFragmentComment = '<!--StartFragment-->';
const _kEndFragmentComment = '<!--EndFragment-->';

const _kHtmlDescriptionTemplate = '''
Version:0.9
StartHTML:0000000000
EndHTML:0000000000
StartFragment:0000000000
EndFragment:0000000000
''';

/// Wraps bare HTML fragments in a minimal document with `<body>` tags.
///
/// Windows "HTML Format" handling expects a document body when inserting
/// StartFragment/EndFragment markers. Klapp (and other apps) often copy
/// fragments like `<p>…</p>` without `<html>` or `<body>`.
String ensureHtmlDocumentBody(String html) {
  final lower = html.toLowerCase();
  if (lower.contains('<body')) {
    return html;
  }

  final prepared = prepareHtmlForClipboard(html);
  return '<html><head></head><body>$prepared</body></html>';
}

/// Remove the leading description from Windows clipboard HTML.
///
/// See [HTML Clipboard Format](https://docs.microsoft.com/en-us/windows/win32/dataxchg/html-clipboard-format)
/// for details.
String stripWin32HtmlDescription(String html) {
  // The description has a StartHTML field we could use to calculate this
  // instead, but it's in terms of byte offset so is annoying to work with
  // once we already converted back to a Dart string, and since it's generated
  // in application code it could just contain garbage anyway.
  final startHtml = html.indexOf('<html');
  final htmlStr = html.substring(startHtml < 0 ? 0 : startHtml);

  return htmlStr;
}

/// Turn an HTML document into a list of UTF-8 code units suitable for storing
/// in the Windows clipboard as the "HTML Format" type.
List<int> constructWin32HtmlClipboardData(String html) {
  html = ensureHtmlDocumentBody(html);

  // Windows wants these marker comments in the HTML, and future parts of our
  // code relies on them being present. It's probably technically incorrect
  // to just wrap the entire body since that could include things like meta
  // tags, but it works for Google Docs so it's good enough for us.
  if (!html.contains(_kStartFragmentComment)) {
    final bodyStart = html.toLowerCase().indexOf('<body>');
    if (bodyStart >= 0) {
      final startBodyIndex = bodyStart + '<body>'.length;
      html = html.substring(0, startBodyIndex) +
          _kStartFragmentComment +
          html.substring(startBodyIndex);
    }
  }
  if (!html.contains(_kEndFragmentComment)) {
    final bodyEnd = html.toLowerCase().lastIndexOf('</body>');
    if (bodyEnd >= 0) {
      html = html.substring(0, bodyEnd) +
          _kEndFragmentComment +
          html.substring(bodyEnd);
    }
  }

  final descUtf8Len = utf8.encode(_kHtmlDescriptionTemplate).length;
  final htmlUtf8 = utf8.encode(html);
  final htmlStart = descUtf8Len;
  final htmlEnd = descUtf8Len + htmlUtf8.length;
  final fragmentStart = descUtf8Len +
      utf8
          .encode(html.substring(0, html.indexOf(_kStartFragmentComment)))
          .length +
      utf8.encode(_kStartFragmentComment).length;
  final fragmentEnd = descUtf8Len +
      utf8
          .encode(html.substring(0, html.lastIndexOf(_kEndFragmentComment)))
          .length;
  final desc = _kHtmlDescriptionTemplate
      .replaceAll(
        'StartHTML:0000000000',
        'StartHTML:${htmlStart.toString().padLeft(10, '0')}',
      )
      .replaceAll(
        'EndHTML:0000000000',
        'EndHTML:${htmlEnd.toString().padLeft(10, '0')}',
      )
      .replaceAll(
        'StartFragment:0000000000',
        'StartFragment:${fragmentStart.toString().padLeft(10, '0')}',
      )
      .replaceAll(
        'EndFragment:0000000000',
        'EndFragment:${fragmentEnd.toString().padLeft(10, '0')}',
      );
  final descUtf8 = utf8.encode(desc);
  final utf8Result = [...descUtf8, ...htmlUtf8];
  return utf8Result;
}
