import 'package:flutter_test/flutter_test.dart';
import 'package:rich_clipboard_platform_interface/src/html_clipboard_encoding.dart';

void main() {
  group('prepareHtmlForClipboard', () {
    test('wraps non-ASCII HTML fragments', () {
      const html = '<p>Schulgelände</p>';
      expect(
        prepareHtmlForClipboard(html),
        '<meta charset="UTF-8"><p>Schulgelände</p>',
      );
    });

    test('wraps HTML with emojis and smart punctuation', () {
      const html = '<p>17:00 – 21:00 · Café</p>';
      final prepared = prepareHtmlForClipboard(html);
      expect(prepared.startsWith('<meta charset="UTF-8">'), isTrue);
      expect(prepared.contains('17:00 – 21:00'), isTrue);
      expect(prepared.contains('Café'), isTrue);
    });

    test('does not wrap ASCII-only HTML', () {
      const html = '<p>hello world</p>';
      expect(prepareHtmlForClipboard(html), html);
    });

    test('does not wrap empty HTML', () {
      expect(prepareHtmlForClipboard(''), '');
    });

    test('does not double-wrap when charset already declared', () {
      const html = '<meta charset="UTF-8"><p>Schulgelände</p>';
      expect(prepareHtmlForClipboard(html), html);
    });

    test('does not wrap when charset uses single quotes', () {
      const html = "<meta charset='utf-8'><p>Schulgelände</p>";
      expect(prepareHtmlForClipboard(html), html);
    });
  });

  group('normalizeHtmlFromClipboard', () {
    test('strips charset meta added for clipboard export', () {
      const original = '<p>Schulgelände</p>';
      final prepared = prepareHtmlForClipboard(original);
      expect(normalizeHtmlFromClipboard(prepared), original);
    });

    test('leaves unwrapped HTML unchanged', () {
      const html = '<p>hello</p>';
      expect(normalizeHtmlFromClipboard(html), html);
    });

    test('strips variant charset declarations at start', () {
      expect(
        normalizeHtmlFromClipboard("<meta charset='utf-8'><p>ä</p>"),
        '<p>ä</p>',
      );
    });
  });

  group('htmlHasCharsetDeclaration', () {
    test('detects charset in meta tag', () {
      expect(htmlHasCharsetDeclaration('<meta charset="UTF-8"><p></p>'), isTrue);
    });

    test('returns false for fragments without charset', () {
      expect(htmlHasCharsetDeclaration('<p>ä</p>'), isFalse);
    });
  });
}
