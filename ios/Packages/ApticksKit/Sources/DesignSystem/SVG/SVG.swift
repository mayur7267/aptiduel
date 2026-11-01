import SwiftUI

// A small SVG renderer for the question figures (from supabase/seed.sql)
// and the few icons that have no SF Symbol. It covers what that data uses:
// svg, g, path, rect, circle, ellipse, line, polyline, polygon and text,
// with transforms, currentColor, opacity and dashes. Tiko is drawn from
// the same path strings as the website, through SVGPath.

// MARK: - Path data

public nonisolated enum SVGPath {
    nonisolated(unsafe) private static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    public static func path(_ d: String) -> Path {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[d] { return hit }
        let p = parse(d)
        cache[d] = p
        return p
    }

    static func parse(_ d: String) -> Path {
        var scanner = Scanner(Array(d.utf8))
        var path = Path()
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var lastCubic: CGPoint?
        var lastQuad: CGPoint?
        var cmd: UInt8 = 0

        while true {
            scanner.skipSeparators()
            guard let c = scanner.peek() else { break }
            if Scanner.isCommand(c) {
                cmd = c
                scanner.advance()
            } else if cmd == 0 || !Scanner.startsNumber(c) {
                break
            }
            let rel = cmd >= 97 // lowercase
            func pt() -> CGPoint? {
                guard let x = scanner.number(), let y = scanner.number() else { return nil }
                return rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
            }
            var cubicCtrl: CGPoint?
            var quadCtrl: CGPoint?
            switch cmd | 0x20 { // lowercase
            case UInt8(ascii: "m"):
                guard let p = pt() else { return path }
                path.move(to: p)
                cur = p
                start = p
                // Further pairs after a move are lines.
                cmd = rel ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                guard let p = pt() else { return path }
                path.addLine(to: p)
                cur = p
            case UInt8(ascii: "h"):
                guard let x = scanner.number() else { return path }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                path.addLine(to: cur)
            case UInt8(ascii: "v"):
                guard let y = scanner.number() else { return path }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                path.addLine(to: cur)
            case UInt8(ascii: "c"):
                guard let c1 = pt(), let c2 = pt(), let p = pt() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2)
                cubicCtrl = c2
                cur = p
            case UInt8(ascii: "s"):
                let c1 = lastCubic.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                guard let c2 = pt(), let p = pt() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2)
                cubicCtrl = c2
                cur = p
            case UInt8(ascii: "q"):
                guard let c1 = pt(), let p = pt() else { return path }
                path.addQuadCurve(to: p, control: c1)
                quadCtrl = c1
                cur = p
            case UInt8(ascii: "t"):
                let c1 = lastQuad.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                guard let p = pt() else { return path }
                path.addQuadCurve(to: p, control: c1)
                quadCtrl = c1
                cur = p
            case UInt8(ascii: "a"):
                guard let rx = scanner.number(), let ry = scanner.number(), let rot = scanner.number(),
                      let large = scanner.flag(), let sweep = scanner.flag(), let p = pt()
                else { return path }
                addArc(&path, from: cur, to: p, rx: rx, ry: ry, degrees: rot, large: large, sweep: sweep)
                cur = p
            case UInt8(ascii: "z"):
                path.closeSubpath()
                cur = start
            default:
                return path
            }
            lastCubic = cubicCtrl
            lastQuad = quadCtrl
        }
        return path
    }

    // SVG's endpoint arc, converted to a centre arc (SVG 1.1, appendix F.6).
    private static func addArc(_ path: inout Path, from p1: CGPoint, to p2: CGPoint, rx: CGFloat, ry: CGFloat,
                               degrees: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rx)
        var ry = abs(ry)
        if rx == 0 || ry == 0 || p1 == p2 {
            path.addLine(to: p2)
            return
        }
        let phi = degrees * .pi / 180
        let cosP = cos(phi)
        let sinP = sin(phi)
        let dx = (p1.x - p2.x) / 2
        let dy = (p1.y - p2.y) / 2
        let x1 = cosP * dx + sinP * dy
        let y1 = -sinP * dx + cosP * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= sqrt(lambda)
            ry *= sqrt(lambda)
        }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coef = (large == sweep ? -1 : 1) * sqrt(max(0, num / den))
        let cxp = coef * rx * y1 / ry
        let cyp = -coef * ry * x1 / rx
        let cx = cosP * cxp - sinP * cyp + (p1.x + p2.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p1.y + p2.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let ux = (x1 - cxp) / rx
        let uy = (y1 - cyp) / ry
        let vx = (-x1 - cxp) / rx
        let vy = (-y1 - cyp) / ry
        let theta = angle(1, 0, ux, uy)
        var delta = angle(ux, uy, vx, vy)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }
        let t = CGAffineTransform(translationX: cx, y: cy).rotated(by: phi).scaledBy(x: rx, y: ry)
        path.addRelativeArc(center: .zero, radius: 1, startAngle: .radians(theta), delta: .radians(delta), transform: t)
    }

    // Numbers in path data can run together ("M-22-26", ".5.5").
    nonisolated struct Scanner {
        let bytes: [UInt8]
        var i = 0
        init(_ bytes: [UInt8]) { self.bytes = bytes }

        func peek() -> UInt8? { i < bytes.count ? bytes[i] : nil }
        mutating func advance() { i += 1 }

        static func isCommand(_ c: UInt8) -> Bool {
            "MmLlHhVvCcSsQqTtAaZz".utf8.contains(c)
        }
        static func startsNumber(_ c: UInt8) -> Bool {
            (c >= 48 && c <= 57) || c == 45 || c == 43 || c == 46
        }

        mutating func skipSeparators() {
            while let c = peek(), c == 32 || c == 44 || c == 9 || c == 10 || c == 13 { i += 1 }
        }

        mutating func flag() -> Bool? {
            skipSeparators()
            guard let c = peek(), c == 48 || c == 49 else { return nil }
            i += 1
            return c == 49
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            let begin = i
            if let c = peek(), c == 45 || c == 43 { i += 1 }
            var digits = false
            while let c = peek(), c >= 48 && c <= 57 { i += 1; digits = true }
            if let c = peek(), c == 46 {
                i += 1
                while let c = peek(), c >= 48 && c <= 57 { i += 1; digits = true }
            }
            guard digits else { i = begin; return nil }
            if let c = peek(), c == 101 || c == 69 {
                let save = i
                i += 1
                if let s = peek(), s == 45 || s == 43 { i += 1 }
                var exp = false
                while let c = peek(), c >= 48 && c <= 57 { i += 1; exp = true }
                if !exp { i = save }
            }
            return Double(String(decoding: bytes[begin..<i], as: UTF8.self)).map { CGFloat($0) }
        }
    }
}

// MARK: - Documents

nonisolated final class SVGNode: @unchecked Sendable {
    let name: String
    let attrs: [String: String]
    var children: [SVGNode] = []
    var text = ""
    init(name: String, attrs: [String: String]) {
        self.name = name
        self.attrs = attrs
    }
}

public nonisolated final class SVGDocument: @unchecked Sendable {
    let root: SVGNode
    public let viewBox: CGRect

    nonisolated(unsafe) private static var cache: [String: SVGDocument] = [:]
    private static let lock = NSLock()

    // Question figures are our own seed data, but anything that isn't plain
    // drawing markup is refused, as on the website.
    public static func load(_ svg: String) -> SVGDocument? {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[svg] { return hit }
        guard svg.trimmingCharacters(in: .whitespaces).hasPrefix("<svg"),
              svg.range(of: #"<script|<foreignObject|<iframe|<image|<use|\son\w+\s*=|javascript:|href\s*="#,
                        options: [.regularExpression, .caseInsensitive]) == nil,
              let doc = parse(svg)
        else { return nil }
        cache[svg] = doc
        return doc
    }

    private init(root: SVGNode, viewBox: CGRect) {
        self.root = root
        self.viewBox = viewBox
    }

    private static func parse(_ svg: String) -> SVGDocument? {
        let builder = Builder()
        let parser = XMLParser(data: Data(svg.utf8))
        parser.delegate = builder
        guard parser.parse(), let root = builder.root else { return nil }
        let nums = (root.attrs["viewBox"] ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        let box: CGRect
        if nums.count == 4 {
            box = CGRect(x: nums[0], y: nums[1], width: nums[2], height: nums[3])
        } else {
            box = CGRect(x: 0, y: 0, width: Double(root.attrs["width"] ?? "") ?? 100, height: Double(root.attrs["height"] ?? "") ?? 100)
        }
        return SVGDocument(root: root, viewBox: box)
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: SVGNode?
        var stack: [SVGNode] = []
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) {
            let node = SVGNode(name: name, attrs: attributes)
            if let parent = stack.last { parent.children.append(node) } else { root = node }
            stack.append(node)
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            stack.removeLast()
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }
    }
}

// MARK: - Drawing

private struct SVGStyle {
    var fill: String = "black"
    var stroke: String = "none"
    var strokeWidth: CGFloat = 1
    var lineCap: CGLineCap = .butt
    var lineJoin: CGLineJoin = .miter
    var dash: [CGFloat] = []
    var fontSize: CGFloat = 16
    var fontWeight: Font.Weight = .regular
    var anchor: String = "start"
    var baseline: String = "auto"

    func inherit(_ a: [String: String]) -> SVGStyle {
        var s = self
        if let v = a["fill"] { s.fill = v }
        if let v = a["stroke"] { s.stroke = v }
        if let v = a["stroke-width"].flatMap(Double.init) { s.strokeWidth = v }
        switch a["stroke-linecap"] {
        case "round": s.lineCap = .round
        case "square": s.lineCap = .square
        case "butt": s.lineCap = .butt
        default: break
        }
        switch a["stroke-linejoin"] {
        case "round": s.lineJoin = .round
        case "bevel": s.lineJoin = .bevel
        case "miter": s.lineJoin = .miter
        default: break
        }
        if let v = a["stroke-dasharray"] {
            s.dash = v == "none" ? [] : v.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }.map { CGFloat($0) }
        }
        if let v = a["font-size"].flatMap(Double.init) { s.fontSize = v }
        if let v = a["font-weight"] {
            let n = Int(v) ?? (v == "bold" ? 700 : 400)
            s.fontWeight = n >= 800 ? .heavy : n >= 700 ? .bold : n >= 600 ? .semibold : n >= 500 ? .medium : .regular
        }
        if let v = a["text-anchor"] { s.anchor = v }
        if let v = a["dominant-baseline"] { s.baseline = v }
        return s
    }
}

func svgColor(_ value: String, current: Color) -> Color? {
    switch value {
    case "none", "transparent": return nil
    case "currentColor": return current
    case "white": return .white
    case "black": return .black
    default:
        guard value.hasPrefix("#") else { return current }
        return Color(hex: String(value.dropFirst()))
    }
}

enum SVGRenderer {
    static func draw(_ doc: SVGDocument, in ctx: GraphicsContext, size: CGSize, color: Color) {
        let box = doc.viewBox
        guard box.width > 0, box.height > 0 else { return }
        // preserveAspectRatio="xMidYMid meet"
        let scale = min(size.width / box.width, size.height / box.height)
        var c = ctx
        c.translateBy(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)
        c.scaleBy(x: scale, y: scale)
        c.translateBy(x: -box.minX, y: -box.minY)
        node(doc.root, c, SVGStyle().inherit(doc.root.attrs), color)
    }

    private static func node(_ n: SVGNode, _ ctx: GraphicsContext, _ inherited: SVGStyle, _ color: Color) {
        var c = ctx
        applyTransform(n.attrs["transform"], &c)
        if let o = n.attrs["opacity"].flatMap(Double.init) { c.opacity *= o }
        let style = n.name == "svg" ? inherited : inherited.inherit(n.attrs)
        let a = n.attrs
        func num(_ k: String, _ d: CGFloat = 0) -> CGFloat { a[k].flatMap(Double.init).map { CGFloat($0) } ?? d }

        switch n.name {
        case "svg", "g":
            for child in n.children { node(child, c, style, color) }
        case "path":
            paint(SVGPath.path(a["d"] ?? ""), c, style, color)
        case "rect":
            let rect = CGRect(x: num("x"), y: num("y"), width: num("width"), height: num("height"))
            let rx = a["rx"] != nil ? num("rx") : num("ry")
            let ry = a["ry"] != nil ? num("ry") : rx
            paint(Path(roundedRect: rect, cornerSize: CGSize(width: rx, height: ry)), c, style, color)
        case "circle":
            let r = num("r")
            paint(Path(ellipseIn: CGRect(x: num("cx") - r, y: num("cy") - r, width: 2 * r, height: 2 * r)), c, style, color)
        case "ellipse":
            let rx = num("rx")
            let ry = num("ry")
            paint(Path(ellipseIn: CGRect(x: num("cx") - rx, y: num("cy") - ry, width: 2 * rx, height: 2 * ry)), c, style, color)
        case "line":
            var p = Path()
            p.move(to: CGPoint(x: num("x1"), y: num("y1")))
            p.addLine(to: CGPoint(x: num("x2"), y: num("y2")))
            paint(p, c, style, color)
        case "polyline", "polygon":
            let v = (a["points"] ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            var p = Path()
            for i in stride(from: 0, to: v.count - 1, by: 2) {
                let point = CGPoint(x: v[i], y: v[i + 1])
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            if n.name == "polygon" { p.closeSubpath() }
            paint(p, c, style, color)
        case "text":
            let content = n.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty, let fill = svgColor(style.fill, current: color) else { return }
            let x = style.anchor == "middle" ? 0.5 : style.anchor == "end" ? 1.0 : 0
            let y = style.baseline == "central" || style.baseline == "middle" ? 0.5 : 0.8
            let text = Text(content).font(.system(size: style.fontSize, weight: style.fontWeight)).foregroundColor(fill)
            c.draw(text, at: CGPoint(x: num("x"), y: num("y")), anchor: UnitPoint(x: x, y: y))
        default:
            break
        }
    }

    private static func paint(_ path: Path, _ c: GraphicsContext, _ s: SVGStyle, _ color: Color) {
        if let fill = svgColor(s.fill, current: color) { c.fill(path, with: .color(fill)) }
        if let stroke = svgColor(s.stroke, current: color), s.strokeWidth > 0 {
            c.stroke(path, with: .color(stroke),
                     style: StrokeStyle(lineWidth: s.strokeWidth, lineCap: s.lineCap, lineJoin: s.lineJoin, dash: s.dash))
        }
    }

    // translate(x y) rotate(a [cx cy]) scale(x [y]) matrix(a b c d e f)
    private static func applyTransform(_ value: String?, _ c: inout GraphicsContext) {
        guard let value else { return }
        for m in value.matches(of: /(\w+)\s*\(([^)]*)\)/) {
            let v = m.2.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }.map { CGFloat($0) }
            switch m.1 {
            case "translate":
                c.translateBy(x: v.first ?? 0, y: v.count > 1 ? v[1] : 0)
            case "rotate":
                let angle = Angle.degrees(v.first ?? 0)
                if v.count == 3 {
                    c.translateBy(x: v[1], y: v[2])
                    c.rotate(by: angle)
                    c.translateBy(x: -v[1], y: -v[2])
                } else {
                    c.rotate(by: angle)
                }
            case "scale":
                let sx = v.first ?? 1
                c.scaleBy(x: sx, y: v.count > 1 ? v[1] : sx)
            case "matrix" where v.count == 6:
                c.concatenate(CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5]))
            default:
                break
            }
        }
    }
}

// A question or option figure, drawn in the current text colour.
public struct SVGFigure: View {
    let svg: String
    var color: Color

    public init(svg: String, color: Color = Theme.text) {
        self.svg = svg
        self.color = color
    }

    public var body: some View {
        if let doc = SVGDocument.load(svg) {
            Canvas { ctx, size in SVGRenderer.draw(doc, in: ctx, size: size, color: color) }
                .aspectRatio(doc.viewBox.width / max(doc.viewBox.height, 1), contentMode: .fit)
        }
    }
}
