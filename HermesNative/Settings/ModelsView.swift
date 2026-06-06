import SwiftUI
import HermesAPI
import HermesGlass

/// Pick the default model from the server's catalog.
struct ModelsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        List {
            if store.models.isEmpty {
                ContentUnavailableView("No models", systemImage: "cpu",
                                       description: Text("The server returned no model options."))
            } else {
                ForEach(store.models) { model in
                    Button {
                        Task { await store.setModel(model.id) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName).foregroundStyle(.primary)
                                HStack(spacing: Tokens.Space.sm) {
                                    if let p = model.provider {
                                        Text(p).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                    }
                                    if let c = model.contextWindow {
                                        Text("\(c / 1000)K ctx").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            if model.id == store.currentModel {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Model")
    }
}
