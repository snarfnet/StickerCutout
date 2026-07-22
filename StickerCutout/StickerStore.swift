import SwiftUI
import UIKit

/// 切り出したスタンプ群の状態。LINE静止スタンプは 8/16/24/32/40 個で申請できる。
@MainActor
final class StickerStore: ObservableObject {
    struct Sticker: Identifiable {
        let id = UUID()
        var source: UIImage    // 元写真（背景トグルの再処理用）
        var image: UIImage     // 規格化した切り抜き画像
        var png: Data
        var bytes: Int
    }

    static let validCounts = [8, 16, 24, 32, 40]

    @Published var stickers: [Sticker] = []
    @Published var removeBG = true
    @Published var processing = false

    var count: Int { stickers.count }
    var isValidCount: Bool { Self.validCounts.contains(count) }

    /// 次に到達すべき有効枚数（案内表示用）。
    var nextValidCount: Int? { Self.validCounts.first { $0 >= count && $0 != count } }

    /// 選んだ写真を切り抜いて追加（バックグラウンド処理）。
    func addPhotos(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let remove = removeBG
        processing = true
        Task.detached(priority: .userInitiated) {
            var built: [Sticker] = []
            for img in images {
                if let out = StickerBuilder.build(from: img, removeBG: remove) {
                    built.append(Sticker(source: img, image: out.image, png: out.png, bytes: out.bytes))
                }
            }
            let done = built
            await MainActor.run {
                self.stickers.append(contentsOf: done)
                self.processing = false
            }
        }
    }

    func remove(id: UUID) {
        stickers.removeAll { $0.id == id }
    }

    func clearAll() {
        stickers.removeAll()
    }

    /// 背景トグルを切り替えて全スタンプを元写真から作り直す。
    func reprocessAll() {
        guard !stickers.isEmpty else { return }
        let sources = stickers.map { $0.source }
        let remove = removeBG
        processing = true
        Task.detached(priority: .userInitiated) {
            var rebuilt: [Sticker] = []
            for src in sources {
                if let out = StickerBuilder.build(from: src, removeBG: remove) {
                    rebuilt.append(Sticker(source: src, image: out.image, png: out.png, bytes: out.bytes))
                }
            }
            let done = rebuilt
            await MainActor.run {
                self.stickers = done
                self.processing = false
            }
        }
    }
}
