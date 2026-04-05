import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _kTextPlain = 'text/plain';
const _kTextHtml = 'text/html';
const kQuillDeltaJsonClipboardMime = 'application/vnd.quill.delta+json';

/// Data from the system clipboard.
@immutable
class RichClipboardData implements ClipboardData {
  const RichClipboardData({this.text, this.html, this.quillDeltaJson});
  RichClipboardData.fromMap(Map<String, String?> map)
      : this(
          text: map[_kTextPlain],
          html: map[_kTextHtml],
          quillDeltaJson: map[kQuillDeltaJsonClipboardMime],
        );

  @override
  final String? text;

  /// HTML variant of this clipboard data.
  final String? html;

  /// Quill Delta JSON variant of this clipboard data.
  final String? quillDeltaJson;

  /// Convert this object to a map of MIME types to strings.
  ///
  /// This is primarily a convenience method for passing [RichClipboardData]
  /// instances across a Flutter [MethodChannel].
  Map<String, String?> toMap() => {
        _kTextPlain: text,
        _kTextHtml: html,
        kQuillDeltaJsonClipboardMime: quillDeltaJson,
      };

  @override
  String toString() =>
      'RichClipboardData{ text: $text, html: $html, quillDeltaJson: $quillDeltaJson }';

  @override
  operator ==(Object other) =>
      identical(this, other) ||
      other is RichClipboardData &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          html == other.html &&
          quillDeltaJson == other.quillDeltaJson;

  @override
  int get hashCode => text.hashCode ^ html.hashCode ^ quillDeltaJson.hashCode;
}
