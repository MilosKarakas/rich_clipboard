import Flutter
import UniformTypeIdentifiers

let mimeTextPlain = "text/plain"
let mimeTextHtml = "text/html"
let mimeQuillDeltaJson = "application/vnd.quill.delta+json"
let utTypeTextPlain = "public.text"
let utTypeTextHtml = "public.html"
let utTypeTextRtf = "public.rtf"

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
            let html = String(data: htmlData, encoding: .utf8)
            result[mimeTextHtml] = html
        } else if let rtfData = board.data(forPasteboardType: utTypeTextRtf) {
            do {
                let rtfAttrString = try NSAttributedString(
                    data: rtfData,
                    documentAttributes: nil)
                let htmlData = try rtfAttrString.data(from: NSRange(location: 0, length: rtfAttrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
                result[mimeTextHtml] = String(data: htmlData, encoding: .utf8)
            } catch {}
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
