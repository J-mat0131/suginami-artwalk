import SwiftUI
import PhotosUI

/// 正方形のサムネイル
struct PhotoThumb: View {
    let photo: SignPhoto
    @Environment(PhotoStore.self) private var store

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let ui = store.thumbnail(photo) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("\(photo.sign?.title ?? "")の写真 \(photo.date.formatted(date: .abbreviated, time: .shortened))")
    }
}

/// 作品詳細画面の「思い出の写真」セクション
struct SignPhotosSection: View {
    let sign: ArtSign
    var onTakePhoto: () -> Void

    @Environment(PhotoStore.self) private var store
    @State private var pickerItem: PhotosPickerItem?
    @State private var viewing: SignPhoto?

    private var photos: [SignPhoto] { store.photos(for: sign) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("思い出の写真").font(.title3.bold())

            if photos.isEmpty {
                Text("「見た！」を記録すると、そのまま写真を撮れます。撮った写真はここにたまります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(photos) { photo in
                        Button { viewing = photo } label: { PhotoThumb(photo: photo) }
                            .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                if CameraPicker.isAvailable {
                    Button(action: onTakePhoto) {
                        Label("写真を撮る", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("アルバムから追加", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { _ = store.add(image, for: sign) }
                }
                await MainActor.run { pickerItem = nil }
            }
        }
        .fullScreenCover(item: $viewing) { photo in
            PhotoViewer(photos: photos, initial: photo)
        }
    }
}

/// 全画面で写真を見る（左右スワイプ・共有・削除）
struct PhotoViewer: View {
    let photos: [SignPhoto]
    let initial: SignPhoto

    @Environment(PhotoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var current: UUID?
    @State private var confirmDelete = false

    private var currentPhoto: SignPhoto? {
        photos.first { $0.id == current } ?? photos.first
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $current) {
                ForEach(photos) { photo in
                    Group {
                        if let ui = store.image(photo) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .background(Color.black.ignoresSafeArea())
            .toolbarBackground(.visible, for: .navigationBar, .bottomBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let p = currentPhoto {
                        VStack(spacing: 0) {
                            Text(p.sign?.title ?? "").font(.subheadline.bold())
                            Text(p.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if let p = currentPhoto, let ui = store.image(p) {
                        let image = Image(uiImage: ui)
                        ShareLink(item: image,
                                  preview: SharePreview(p.sign?.title ?? "すぎなみアートウオーク", image: image)) {
                            Label("共有・保存", systemImage: "square.and.arrow.up")
                        }
                    }
                    Spacer()
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog("この写真を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    if let p = currentPhoto {
                        store.delete(p)
                        dismiss()
                    }
                }
            } message: {
                Text("アプリ内の写真が削除されます。")
            }
        }
        .onAppear { current = initial.id }
    }
}

/// すべての写真（作品ごと）
struct AlbumView: View {
    @Environment(PhotoStore.self) private var store
    @State private var viewing: (photos: [SignPhoto], photo: SignPhoto)?

    var body: some View {
        ScrollView {
            if store.photos.isEmpty {
                ContentUnavailableView("まだ写真がありません",
                                       systemImage: "camera",
                                       description: Text("作品の画面で「見た！」を記録すると、写真を撮ってここに残せます。"))
                    .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(ArtSign.all) { sign in
                        let photos = store.photos(for: sign)
                        if !photos.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    SignPin(sign: sign, visited: true).scaleEffect(0.7)
                                    VStack(alignment: .leading) {
                                        Text(sign.title).font(.headline)
                                        Text(sign.place).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                                    ForEach(photos) { photo in
                                        Button { viewing = (photos, photo) } label: { PhotoThumb(photo: photo) }
                                            .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("思い出アルバム")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: Binding(get: { viewing != nil }, set: { if !$0 { viewing = nil } })) {
            if let v = viewing {
                PhotoViewer(photos: v.photos, initial: v.photo)
            }
        }
    }
}

/// アート一覧の先頭に出す、最近の写真の横スクロール
struct RecentPhotosStrip: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("思い出アルバム").font(.headline)
                Spacer()
                NavigationLink("すべて見る") { AlbumView() }
                    .font(.subheadline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.all.prefix(12)) { photo in
                        NavigationLink { AlbumView() } label: {
                            PhotoThumb(photo: photo).frame(width: 84, height: 84)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
