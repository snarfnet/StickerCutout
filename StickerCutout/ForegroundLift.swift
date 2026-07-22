import Vision
import CoreImage
import UIKit

/// iOS17 の被写体リフト（VNGenerateForegroundInstanceMaskRequest）で
/// 背景色を問わず前景の被写体だけを切り抜く。iOS 標準の「写真長押しで切り抜き」と同じ技術。
enum ForegroundLift {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// 被写体だけを抜いて背景透過した UIImage を返す。抜けなければ nil。
    static func cutout(_ image: UIImage) -> UIImage? {
        guard let cg = flattenedCG(image) else { return nil }

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            return nil
        }

        do {
            // 全インスタンス（複数被写体があっても全部）を残して背景を透過。
            let masked = try result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: false)
            let ci = CIImage(cvPixelBuffer: masked)
            guard let out = ciContext.createCGImage(ci, from: ci.extent) else { return nil }
            return UIImage(cgImage: out, scale: 1, orientation: .up)
        } catch {
            return nil
        }
    }

    /// 画像の向きを焼き込んで .up 前提の cgImage を得る（EXIF回転で切り抜きがずれるのを防ぐ）。
    private static func flattenedCG(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage { return cg }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = false
        fmt.scale = 1
        let r = UIGraphicsImageRenderer(size: image.size, format: fmt)
        let flat = r.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
        return flat.cgImage
    }
}
