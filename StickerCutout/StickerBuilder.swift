import UIKit

/// 1枚の写真から LINE 静止スタンプ規格の PNG を作る。
/// LINE静止スタンプ: 最大 W370×H320px、辺は偶数、透過PNG、各1MB以下。
enum StickerBuilder {
    static let fit = CGSize(width: 370, height: 320)
    static let sizeLimit = 1_000_000   // 1MB

    struct Output {
        let image: UIImage   // 規格サイズの切り抜き画像（プレビュー兼用）
        let png: Data
        let bytes: Int
    }

    /// - Parameters:
    ///   - image: 元写真
    ///   - removeBG: 背景を切り抜くなら true、残すなら false
    static func build(from image: UIImage, removeBG: Bool) -> Output? {
        // 処理を軽くするため長辺900へ。
        let work = resize(image, longSide: 900)

        // 被写体切り抜き（失敗時は元画像のまま）。
        let cut = removeBG ? (ForegroundLift.cutout(work) ?? work) : work

        // 被写体の外接矩形で余白を詰める。
        let cropped: UIImage
        if removeBG, let bb = alphaBBox(cut) {
            cropped = cropPixels(cut, rect: bb.insetBy(dx: -10, dy: -10))
        } else {
            cropped = cut
        }

        // LINE枠へ。必ず片辺が370か320に接するよう拡縮し、辺は偶数化。
        let cw = cropped.size.width, ch = cropped.size.height
        guard cw > 0, ch > 0 else { return nil }
        let scale = min(fit.width / cw, fit.height / ch)
        let target = even(CGSize(width: cw * scale, height: ch * scale),
                          maxW: fit.width, maxH: fit.height)

        // PNG化。まず等倍、超える場合だけ段階縮小（静止PNGは通常余裕）。
        var shrink: CGFloat = 1.0
        for _ in 0..<6 {
            let sz = even(CGSize(width: target.width * shrink, height: target.height * shrink),
                          maxW: fit.width, maxH: fit.height)
            let img = resizeExact(cropped, to: sz)
            if let png = img.pngData(), png.count <= sizeLimit || shrink <= 0.5 {
                return Output(image: img, png: png, bytes: png.count)
            }
            shrink -= 0.1
        }
        return nil
    }

    // MARK: - 画像ユーティリティ（scale=1で点=ピクセルを固定）

    private static func even(_ size: CGSize, maxW: CGFloat, maxH: CGFloat) -> CGSize {
        var w = Int(round(size.width)), h = Int(round(size.height))
        if w % 2 != 0 { w -= 1 }
        if h % 2 != 0 { h -= 1 }
        w = max(2, min(w, Int(maxW)))
        h = max(2, min(h, Int(maxH)))
        return CGSize(width: w, height: h)
    }

    private static func renderer(_ size: CGSize) -> UIGraphicsImageRenderer {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = false
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt)
    }

    static func resize(_ image: UIImage, longSide: CGFloat) -> UIImage {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        let long = max(w, h)
        guard long > longSide else { return normalized(image) }
        let s = longSide / long
        return resizeExact(image, to: CGSize(width: round(w * s), height: round(h * s)))
    }

    static func resizeExact(_ image: UIImage, to size: CGSize) -> UIImage {
        renderer(size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func normalized(_ image: UIImage) -> UIImage {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        return resizeExact(image, to: CGSize(width: w, height: h))
    }

    static func cropPixels(_ image: UIImage, rect: CGRect) -> UIImage {
        let bounds = CGRect(origin: .zero, size: image.size)
        let r = rect.intersection(bounds)
        let target = r.isNull || r.isEmpty ? bounds : r
        return renderer(target.size).image { _ in
            image.draw(in: CGRect(x: -target.minX, y: -target.minY,
                                  width: image.size.width, height: image.size.height))
        }
    }

    /// 非透明領域の外接矩形（ピクセル座標）。全面不透明なら全面を返す。
    static func alphaBBox(_ image: UIImage) -> CGRect? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * w * 4
            for x in 0..<w {
                if pixels[row + x * 4 + 3] > 12 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        if maxX < minX || maxY < minY { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
