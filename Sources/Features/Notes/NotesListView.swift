import CarpdmCore
import SwiftUI

public struct NotesListView: View {
    let notes: [VaultNote]

    public init(notes: [VaultNote]) {
        self.notes = notes
    }

    public var body: some View {
        List(notes) { note in
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                Text(note.relativePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

