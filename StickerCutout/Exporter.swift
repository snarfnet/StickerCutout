import UIKit

/// 書き出し: 01.png..NN.png + main.png(240×240) + tab.png(96×74) を
/// フォルダに置き、ZIP化して共有する。LINE Creators Market へアップロードする形式。
enum Exporter {
    static func makeZip(stickers: [StickerStore.Sticker]) -> URL? {
        guard !stickers.isEmpty else { return nil }

        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("line_stickers_\(Int(Date().timeIntervalSince1970))")
        try? fm.removeItem(at: dir)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        for (i, sticker) in stickers.enumerated() {
            let name = String(format: "%02d.png", i + 1)   // 01.png から連番
            try? sticker.png.write(to: dir.appendingPathComponent(name))
        }

        // main(240×240) / tab(96×74) を先頭スタンプから生成。
        if let first = stickers.first {
            if let main = staticPNG(first.image, size: CGSize(width: 240, height: 240)) {
                try? main.write(to: dir.appendingPathComponent("main.png"))
            }
            if let tab = staticPNG(first.image, size: CGSize(width: 96, height: 74)) {
                try? tab.write(to: dir.appendingPathComponent("tab.png"))
            }
        }

        return zipDirectory(dir)
    }

    /// 中央寄せで枠に収めた透過PNG。
    private static func staticPNG(_ image: UIImage, size: CGSize) -> Data? {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = false
        fmt.scale = 1
        let r = UIGraphicsImageRenderer(size: size, format: fmt)
        let img = r.image { _ in
            let s = min(size.width / image.size.width, size.height / image.size.height)
            let w = image.size.width * s, h = image.size.height * s
            image.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
        }
        return img.pngData()
    }

    /// NSFileCoordinator の forUploading でディレクトリを zip 化。
    private static func zipDirectory(_ dir: URL) -> URL? {
        var zipURL: URL?
        var coordError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: dir, options: [.forUploading], error: &coordError) { tmp in
            let dst = FileManager.default.temporaryDirectory
                .appendingPathComponent(dir.lastPathComponent + ".zip")
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: tmp, to: dst)
            zipURL = dst
        }
        return zipURL
    }
}

/// 共有シート。
import SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
