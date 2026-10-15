import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CheckInSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var habitID: UUID

    @State private var note = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var pickedFresh = false
    @State private var removedPhoto = false
    @State private var showCamera = false
    @State private var error: String?
    @State private var loaded = false

    private var habit: Habit? { store.snapshot.habit(habitID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let habit {
                        HStack(spacing: 12) {
                            SymbolBadge(symbol: habit.symbolName, hex: habit.colorHex)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(habit.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(store.statusLine(for: habit))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !store.members(for: habit).isEmpty {
                            MemberAvatars(members: store.members(for: habit))
                        }
                    }
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))

                    photoBlock

                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.ember)
                    }

                    Button("Check in", action: submit)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(habit == nil)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear(perform: loadExisting)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let picked = try? await item.loadTransferable(type: PickedPhoto.self) {
                        photoData = picked.data
                        pickedFresh = true
                        removedPhoto = false
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { data in
                    photoData = data
                    pickedFresh = true
                    removedPhoto = false
                }
            }
        }
    }

    @ViewBuilder
    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo proof")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text("Optional. It stays on this iPhone unless CloudKit sync is on.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button("Remove photo", role: .destructive) {
                    self.photoData = nil
                    pickerItem = nil
                    pickedFresh = false
                    removedPhoto = true
                }
                .font(.subheadline)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Library", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                }
            }
        }
    }

    private func loadExisting() {
        guard !loaded else { return }
        loaded = true
        guard let palID = store.snapshot.activePalID,
              let existing = store.snapshot.checkIn(
                habitID: habitID,
                palID: palID,
                dayKey: DayKey.string(from: .now)
              ) else { return }
        note = existing.note
        if let filename = existing.photoFilename {
            photoData = store.photoData(filename: filename)
        }
    }

    private func submit() {
        let jpeg = photoData.flatMap { ImageEncoding.jpeg(from: $0) ?? $0 }
        do {
            try store.checkIn(
                habitID: habitID,
                note: note,
                photoJPEG: pickedFresh ? jpeg : nil,
                clearPhoto: removedPhoto && !pickedFresh
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct PickedPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PickedPhoto(data: data)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onImage: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onImage(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
