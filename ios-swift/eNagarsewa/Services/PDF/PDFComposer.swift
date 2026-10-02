import UIKit

/// Minimal flow-layout PDF writer standing in for Dart's `pdf` package (`pw.Page`, `pw.Column`,
/// `pw.Container`, `pw.Table`). Blocks are laid out top-to-bottom on A4 pages with automatic
/// page breaks. CoreText handles Devanagari fallback, so Hindi labels render without a
/// bundled Noto face; Krutidev values use the bundled Kruti Dev font.
final class PDFComposer {

    struct Border {
        var top: (UIColor, CGFloat)? = nil
        var bottom: (UIColor, CGFloat)? = nil
        var all: (UIColor, CGFloat)? = nil
    }

    struct Cell {
        var text: String
        var font: UIFont = .systemFont(ofSize: 11)
        var color: UIColor = .black
        var background: UIColor? = nil
        var alignment: NSTextAlignment = .left
        var padding: CGFloat = 8
        /// Column span (for header rows that cross columns).
        var span: Int = 1

        init(_ text: String, font: UIFont = .systemFont(ofSize: 11), color: UIColor = .black,
             background: UIColor? = nil, alignment: NSTextAlignment = .left, padding: CGFloat = 8, span: Int = 1) {
            self.text = text
            self.font = font
            self.color = color
            self.background = background
            self.alignment = alignment
            self.padding = padding
            self.span = span
        }
    }

    /// A4 in points with the `pdf` package's default 2 cm page margin.
    let pageSize = CGSize(width: 595.28, height: 841.89)
    var margin: CGFloat = 56.69

    private var blocks: [(height: CGFloat, draw: (CGFloat) -> Void)] = []
    var contentWidth: CGFloat { pageSize.width - margin * 2 }

    init(margin: CGFloat = 56.69) { self.margin = margin }

    // MARK: - Blocks

    func spacer(_ height: CGFloat) {
        blocks.append((height, { _ in }))
    }

    func line(color: UIColor, thickness: CGFloat) {
        let x = margin, w = contentWidth
        blocks.append((thickness, { y in
            color.setFill()
            UIRectFill(CGRect(x: x, y: y, width: w, height: thickness))
        }))
    }

    /// `pw.Container(padding, color, border, child: pw.Text(...))` spanning the full width.
    func box(_ text: NSAttributedString, padding: UIEdgeInsets, background: UIColor? = nil, border: Border = Border(),
             width: CGFloat? = nil) {
        let w = width ?? contentWidth
        let textHeight = Self.height(of: text, width: w - padding.left - padding.right)
        let h = textHeight + padding.top + padding.bottom
        let x = margin
        blocks.append((h, { y in
            let rect = CGRect(x: x, y: y, width: w, height: h)
            if let background { background.setFill(); UIRectFill(rect) }
            Self.drawBorder(border, rect: rect)
            text.draw(with: CGRect(x: x + padding.left, y: y + padding.top, width: w - padding.left - padding.right,
                                   height: textHeight + 2),
                      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }))
    }

    func box(_ text: String, font: UIFont, color: UIColor = .black, alignment: NSTextAlignment = .center,
             padding: CGFloat = 10, background: UIColor? = nil, border: Border = Border()) {
        box(Self.attributed(text, font: font, color: color, alignment: alignment),
            padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
            background: background, border: border)
    }

    /// Stack of centred lines inside one container (e.g. receipt footers).
    func boxLines(_ lines: [NSAttributedString], spacing: CGFloat, padding: CGFloat, background: UIColor?,
                  border: Border = Border()) {
        let joined = NSMutableAttributedString()
        for (i, l) in lines.enumerated() {
            joined.append(l)
            if i < lines.count - 1 {
                joined.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: spacing)]))
            }
        }
        box(joined, padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
            background: background, border: border)
    }

    /// `pw.Table` with flex column widths and a uniform grid border. Rows never split across pages.
    func table(_ rows: [[Cell]], flex: [CGFloat], borderColor: UIColor, borderWidth: CGFloat = 0.5) {
        let total = flex.reduce(0, +)
        let widths = flex.map { contentWidth * $0 / total }
        for row in rows {
            var spans: [(cell: Cell, x: CGFloat, w: CGFloat)] = []
            var col = 0
            var x = margin
            for cell in row where col < widths.count {
                let span = min(cell.span, widths.count - col)
                let w = widths[col..<(col + span)].reduce(0, +)
                spans.append((cell, x, w))
                x += w
                col += span
            }
            let h = spans.map { c -> CGFloat in
                Self.height(of: Self.attributed(c.cell.text, font: c.cell.font, color: c.cell.color, alignment: c.cell.alignment),
                            width: c.w - c.cell.padding * 2) + c.cell.padding * 2
            }.max() ?? 0
            blocks.append((h, { y in
                for c in spans {
                    let rect = CGRect(x: c.x, y: y, width: c.w, height: h)
                    if let bg = c.cell.background { bg.setFill(); UIRectFill(rect) }
                    borderColor.setStroke()
                    let path = UIBezierPath(rect: rect)
                    path.lineWidth = borderWidth
                    path.stroke()
                    Self.attributed(c.cell.text, font: c.cell.font, color: c.cell.color, alignment: c.cell.alignment)
                        .draw(with: rect.insetBy(dx: c.cell.padding, dy: c.cell.padding),
                              options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                }
            }))
        }
    }

    // MARK: - Render

    func render() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = margin
            for block in blocks {
                if y + block.height > pageSize.height - margin, y > margin {
                    ctx.beginPage()
                    y = margin
                }
                block.draw(y)
                y += block.height
            }
        }
    }

    // MARK: - Helpers

    static func attributed(_ text: String, font: UIFont, color: UIColor = .black,
                           alignment: NSTextAlignment = .left) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }

    static func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(text.boundingRect(with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
                               options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
    }

    private static func drawBorder(_ border: Border, rect: CGRect) {
        if case let (c, w)? = border.all {
            c.setStroke()
            let p = UIBezierPath(rect: rect)
            p.lineWidth = w
            p.stroke()
        }
        if case let (c, w)? = border.top {
            c.setFill()
            UIRectFill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: w))
        }
        if case let (c, w)? = border.bottom {
            c.setFill()
            UIRectFill(CGRect(x: rect.minX, y: rect.maxY - w, width: rect.width, height: w))
        }
    }
}

/// `pdf` package palette entries used by the receipts.
enum PdfColors {
    static let grey100 = UIColor(argb: 0xFFF5F5F5)
    static let grey200 = UIColor(argb: 0xFFEEEEEE)
    static let grey300 = UIColor(argb: 0xFFE0E0E0)
    static let grey400 = UIColor(argb: 0xFFBDBDBD)
    static let grey700 = UIColor(argb: 0xFF616161)
    static let green   = UIColor(argb: 0xFF4CAF50)
    static let red     = UIColor(argb: 0xFFF44336)
    static let black   = UIColor.black
}

/// Share sheet / print dialog for generated documents (`Share.shareXFiles`, `Printing.layoutPdf`).
enum DocumentActions {

    /// Writes `data` to a temp file and shows the share sheet; the file is removed afterwards.
    static func share(_ data: Data, fileName: String, text: String? = nil, from vc: UIViewController,
                      sourceView: UIView? = nil) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do { try data.write(to: url, options: .atomic) } catch {
            vc.snack("Unable to share right now. Please try again.", .error)
            return
        }
        var items: [Any] = [url]
        if let text { items.insert(text, at: 0) }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = sourceView ?? vc.view
        activity.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url) }
        vc.topPresented.present(activity, animated: true)
    }

    /// System print dialog (which also offers "Save to Files" as PDF).
    static func print(_ data: Data, jobName: String) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = jobName
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true)
    }
}
