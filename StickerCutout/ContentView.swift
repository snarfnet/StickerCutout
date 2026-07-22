import SwiftUI

struct ContentView: View {
    @StateObject private var store = StickerStore()
    @State private var showPicker = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var previewID: UUID?

    private let cols = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if store.stickers.isEmpty {
                    emptyState
                } else {
                    grid
                }

                if store.processing {
                    processingOverlay
                }
            }
            .navigationTitle("スタンプ切り出し")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showPicker) {
                PhotoPicker { images in store.addPhotos(images) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showShare) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
            .sheet(item: previewItem) { sticker in
                previewSheet(sticker)
            }
        }
    }

    // 選択中スタンプ（プレビュー用）
    private var previewItem: Binding<StickerStore.Sticker?> {
        Binding(
            get: { store.stickers.first { $0.id == previewID } },
            set: { previewID = $0?.id }
        )
    }

    // MARK: - パーツ

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scissors")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
            Text("写真を選ぶと被写体だけを\n自動で切り抜きます")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("LINEスタンプは 8 / 16 / 24 / 32 / 40 枚で申請できます")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(Array(store.stickers.enumerated()), id: \.element.id) { idx, sticker in
                    cell(index: idx, sticker: sticker)
                }
            }
            .padding()
        }
    }

    private func cell(index: Int, sticker: StickerStore.Sticker) -> some View {
        ZStack(alignment: .topTrailing) {
            CheckerBoard()
                .overlay {
                    Image(uiImage: sticker.image)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { previewID = sticker.id }

            Button {
                store.remove(id: sticker.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding(4)

            Text("\(index + 1)")
                .font(.caption2.bold())
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.black.opacity(0.5), in: Capsule())
                .foregroundStyle(.white)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("切り抜き中…").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Label(countLabel, systemImage: store.isValidCount ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(store.isValidCount ? .green : .secondary)
                Spacer()
                Toggle("背景を消す", isOn: $store.removeBG)
                    .labelsHidden()
                Text("背景を消す").font(.subheadline).foregroundStyle(.secondary)
            }
            .onChange(of: store.removeBG) { _, _ in store.reprocessAll() }

            HStack(spacing: 10) {
                Button {
                    showPicker = true
                } label: {
                    Label("写真を追加", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    if let url = Exporter.makeZip(stickers: store.stickers) {
                        shareURL = url
                        showShare = true
                    }
                } label: {
                    Label("ZIP書き出し", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(store.stickers.isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    private var countLabel: String {
        if store.isValidCount { return "\(store.count)枚（申請OK）" }
        if let n = store.nextValidCount { return "\(store.count)枚（あと\(n - store.count)枚で\(n)）" }
        return "\(store.count)枚"
    }

    private func previewSheet(_ sticker: StickerStore.Sticker) -> some View {
        VStack(spacing: 16) {
            CheckerBoard()
                .overlay {
                    Image(uiImage: sticker.image)
                        .resizable().scaledToFit().padding(20)
                }
                .frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("\(Int(sticker.image.size.width))×\(Int(sticker.image.size.height))px ・ \(sticker.bytes / 1024)KB")
                .font(.footnote).foregroundStyle(.secondary)
            Button(role: .destructive) {
                store.remove(id: sticker.id)
                previewID = nil
            } label: {
                Label("このスタンプを消す", systemImage: "trash")
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }
}

/// 透過を分かりやすくする市松模様の背景。
struct CheckerBoard: View {
    var body: some View {
        GeometryReader { geo in
            let s: CGFloat = 10
            let cols = Int(geo.size.width / s) + 1
            let rows = Int(geo.size.height / s) + 1
            Canvas { ctx, _ in
                for r in 0..<rows {
                    for c in 0..<cols {
                        if (r + c) % 2 == 0 {
                            ctx.fill(Path(CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s, height: s)),
                                     with: .color(.gray.opacity(0.18)))
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
}
