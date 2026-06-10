import Flutter
import UniformTypeIdentifiers

let mimeTextPlain = "text/plain"
let mimeTextHtml = "text/html"
let mimeQuillDeltaJson = "application/vnd.quill.delta+json"
let utTypeTextPlain = "public.text"
let utTypeTextHtml = "public.html"
let utTypeTextRtf = "public.rtf"
let utTypeFlatRtfd = "com.apple.flat-rtfd"

public class RichClipboardPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.bringingfire.rich_clipboard", binaryMessenger: registrar.messenger())
        let instance = RichClipboardPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getData":
            result(getData())
        case "setData":
            setData(call.arguments)
            result(nil)
        case "getAvailableTypes":
            result(getAvailableTypes())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func getData() -> [String: String] {
        let board = UIPasteboard.general
        var result: [String: String] = [:]
        if let text = board.string {
            result[mimeTextPlain] = text
        }
        if let htmlData = board.data(forPasteboardType: utTypeTextHtml) {
            // Do not assume the pasteboard HTML is always UTF-8. Honor a BOM or a
            // declared <meta charset> and fall back across encodings, otherwise
            // non-UTF-8 (or UTF-8 misread) bytes turn "ä" into "Ã¤".
            result[mimeTextHtml] = decodeHTMLData(htmlData)
        } else if let rtfData = board.data(forPasteboardType: utTypeTextRtf)
            ?? board.data(forPasteboardType: utTypeFlatRtfd) {
            // Many native apps put rich text on the pasteboard as flat RTFD
            // (com.apple.flat-rtfd) with no public.html / public.rtf, so fall
            // back to it. NSAttributedString auto-detects RTF vs RTFD.
            do {
                let rtfAttrString = try NSAttributedString(
                    data: rtfData,
                    documentAttributes: nil)
                // Pin the export encoding to UTF-8 so the produced bytes match
                // the UTF-8 decode below. Without .characterEncoding the writer
                // relies on heuristics and can emit mismatched bytes (mojibake).
                let htmlData = try rtfAttrString.data(
                    from: NSRange(location: 0, length: rtfAttrString.length),
                    documentAttributes: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue,
                    ])
                result[mimeTextHtml] = String(data: htmlData, encoding: .utf8)
            } catch {
                #if DEBUG
                print("[RichClipboard] RTF->HTML conversion failed: \(error)")
                #endif
            }
        }
        if let quillDeltaData = board.data(forPasteboardType: mimeQuillDeltaJson),
           let quillDeltaJson = String(data: quillDeltaData, encoding: .utf8) {
            result[mimeQuillDeltaJson] = quillDeltaJson
        } else if let quillDeltaJson =
            board.value(forPasteboardType: mimeQuillDeltaJson) as? String {
            result[mimeQuillDeltaJson] = quillDeltaJson
        }
        return result
    }

    /// Decodes clipboard HTML bytes into a String without blindly assuming
    /// UTF-8. Checks for a Unicode BOM, then valid UTF-8 (the common, lossless
    /// case), then a charset declared in a `<meta>` tag, and finally a set of
    /// legacy fallbacks. This prevents the classic "ä" -> "Ã¤" corruption that
    /// happens when UTF-8 bytes are misread as Latin-1 / Windows-1252.
    private func decodeHTMLData(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data, encoding: .utf8)
        }
        // .utf16 honors a leading BOM (either endianness) and strips it.
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            if let utf16 = String(data: data, encoding: .utf16) {
                return utf16
            }
        }
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        // The <meta charset> declaration is ASCII, so it survives an isoLatin1
        // pass even when the body bytes are in a legacy 8-bit encoding.
        if let latin1 = String(data: data, encoding: .isoLatin1),
           let charsetName = RichClipboardPlugin.charsetName(in: latin1) {
            let cfEnc = CFStringConvertIANACharSetNameToEncoding(charsetName as CFString)
            if cfEnc != kCFStringEncodingInvalidId {
                let enc = String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(cfEnc))
                if let decoded = String(data: data, encoding: enc) {
                    return decoded
                }
            }
        }
        // No BOM, not valid UTF-8, and no declared charset: assume a legacy
        // 8-bit Western encoding. Do NOT try bare UTF-16 here, as it succeeds on
        // arbitrary byte sequences and yields garbage.
        return String(data: data, encoding: .windowsCP1252)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func charsetName(in html: String) -> String? {
        let lower = html.lowercased()
        guard let range = lower.range(of: "charset=") else { return nil }
        var rest = lower[range.upperBound...]
        if rest.first == "\"" || rest.first == "'" {
            rest = rest.dropFirst()
        }
        let name = rest.prefix {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
        return name.isEmpty ? nil : String(name)
    }

    #if DEBUG
    private func hexPrefix(_ data: Data, _ count: Int = 32) -> String {
        return data.prefix(count)
            .map { String(format: "%02x", $0) }
            .joined(separator: " ")
    }
    #endif

    func setData(_ arguments: Any?) {
        let board = UIPasteboard.general
        guard let data = (arguments as? [String: String?])?.compactMapValues({ $0 }) else {
            return
        }

        var item: [String: Any] = [:]
        if let text = data[mimeTextPlain] {
            item[utTypeTextPlain] = text
        }
        if let html = data[mimeTextHtml] {
            item[utTypeTextHtml] = Data(html.utf8)
        }
        if let quillDeltaJson = data[mimeQuillDeltaJson] {
            item[mimeQuillDeltaJson] = Data(quillDeltaJson.utf8)
        }

        board.items = [item]
    }

    func getAvailableTypes() -> [String] {
        return UIPasteboard.general.types
    }
}
