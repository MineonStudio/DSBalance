import AppKit

/// 统一加载 DeepSeek / Grok 官方 logo
enum LogoAssets {
    enum Brand {
        case deepseek
        case grok

        var resourceName: String {
            switch self {
            case .deepseek: return "deepseek"
            case .grok: return "grok"
            }
        }

        /// DeepSeek 彩色蓝鲸；Grok 用模板以便深浅色都清晰
        var useTemplate: Bool {
            switch self {
            case .deepseek: return false
            case .grok: return true
            }
        }

        var fallbackSymbol: String {
            switch self {
            case .deepseek: return "fish.fill"
            case .grok: return "sparkles"
            }
        }
    }

    static func image(_ brand: Brand, pointSize: CGFloat) -> NSImage {
        if let base = loadRaw(brand.resourceName), base.isValid, base.size.width > 8 {
            return scale(base, pointSize: pointSize, template: brand.useTemplate)
        }
        return symbol(brand.fallbackSymbol, pointSize: pointSize)
    }

    private static func symbol(_ name: String, pointSize: CGFloat) -> NSImage {
        let img = NSImage(systemSymbolName: name, accessibilityDescription: name) ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        let sized = img.withSymbolConfiguration(config) ?? img
        sized.isTemplate = true
        return sized
    }

    private static func looksEmpty(_ image: NSImage) -> Bool {
        // 极小或无效
        image.size.width < 4 || image.size.height < 4
    }

    private static func loadRaw(_ name: String) -> NSImage? {
        var urls: [URL] = []
        if let u = Bundle.module.url(forResource: name, withExtension: "png") { urls.append(u) }
        if let u = Bundle.main.url(forResource: name, withExtension: "png") { urls.append(u) }
        if let res = Bundle.main.resourceURL {
            urls.append(res.appendingPathComponent("\(name).png"))
        }
        if let exec = Bundle.main.executableURL?.deletingLastPathComponent() {
            urls.append(exec.appendingPathComponent("DSBalance_DSBalance.bundle/\(name).png"))
            urls.append(exec.appendingPathComponent("\(name).png"))
        }
        urls.append(
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/MacOS/DSBalance_DSBalance.bundle/\(name).png")
        )
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func scale(_ base: NSImage, pointSize: CGFloat, template: Bool) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let scaled = NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
        scaled.isTemplate = template
        scaled.size = size
        return scaled
    }
}
