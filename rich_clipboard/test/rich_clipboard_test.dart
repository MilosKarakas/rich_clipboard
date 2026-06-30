import 'package:flutter_test/flutter_test.dart';
import 'package:rich_clipboard/rich_clipboard.dart';
import 'package:rich_clipboard_platform_interface/rich_clipboard_platform_interface.dart';

class _RecordingRichClipboardPlatform extends RichClipboardPlatform {
  RichClipboardData? lastSetData;
  RichClipboardData readData = const RichClipboardData();

  @override
  Future<List<String>> getAvailableTypes() async => [];

  @override
  Future<RichClipboardData> getData() async => readData;

  @override
  Future<void> setData(RichClipboardData data) async {
    lastSetData = data;
  }
}

void main() {
  test('setData prepares HTML with charset before platform write', () async {
    final platform = _RecordingRichClipboardPlatform();
    RichClipboardPlatform.instance = platform;

    const html = '<p>Schulgelände</p>';
    await RichClipboard.setData(
      const RichClipboardData(text: 'Schulgelände', html: html),
    );

    expect(
      platform.lastSetData?.html,
      '<meta charset="UTF-8"><p>Schulgelände</p>',
    );
    expect(platform.lastSetData?.text, 'Schulgelände');
  });

  test('getData normalizes HTML read from platform', () async {
    final platform = _RecordingRichClipboardPlatform();
    platform.readData = const RichClipboardData(
      html: '<meta charset="UTF-8"><p>Schulgelände</p>',
      text: 'Schulgelände',
    );
    RichClipboardPlatform.instance = platform;

    final data = await RichClipboard.getData();
    expect(data.html, '<p>Schulgelände</p>');
    expect(data.text, 'Schulgelände');
  });
}
