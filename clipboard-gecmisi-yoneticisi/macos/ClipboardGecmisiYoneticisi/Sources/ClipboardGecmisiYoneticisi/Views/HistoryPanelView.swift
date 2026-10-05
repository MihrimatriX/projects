import SwiftUI

struct HistoryPanelView: View {
    @EnvironmentObject private var viewModel: HistoryViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
            historyList
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: viewModel.searchText) { _ in viewModel.reload() }
    }

    private var header: some View {
        HStack {
            Text("Pano Geçmişi")
                .font(.headline)
            Spacer()
            Text("\(viewModel.history.count) öğe")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ara...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if viewModel.history.isEmpty {
                    Text("Henüz kayıt yok")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    ForEach(viewModel.history) { entry in
                        HistoryRowView(entry: entry) {
                            viewModel.copyEntry(entry)
                        } onPin: {
                            viewModel.togglePin(entry)
                        } onDelete: {
                            viewModel.deleteEntry(entry)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var footer: some View {
        HStack {
            Text("⌘⇧V: aç · Enter: kopyala")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Temizle") { viewModel.clearAll() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(10)
    }
}

struct HistoryRowView: View {
    let entry: ClipboardEntry
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.categoryLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Text(entry.displayName)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 4) {
                Button(action: onPin) {
                    Image(systemName: entry.isPinned ? "pin.slash" : "pin")
                }
                .buttonStyle(.borderless)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onCopy)
    }
}
