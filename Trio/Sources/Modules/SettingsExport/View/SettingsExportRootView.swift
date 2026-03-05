import SwiftUI
import Swinject

extension SettingsExport {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @State private var showSettingsExport = false
        @State private var showExportError = false
        @State private var exportErrorMessage = ""
        @State private var exportedFileURL: URL?

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                exportCategoriesSection
                exportActionSection
            }
            .listSectionSpacing(sectionSpacing)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .onAppear(perform: configureView)
            .navigationTitle("Export Settings")
            .navigationBarTitleDisplayMode(.automatic)
            .sheet(isPresented: $showSettingsExport) { shareSheet }
            .alert("Export Error", isPresented: $showExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage)
            }
        }

        private var exportCategoriesSection: some View {
            Section(header: Text("Export Categories")) {
                selectAllRow
                categoriesList
            }
            .listRowBackground(Color.chart)
        }

        private var selectAllRow: some View {
            Button {
                state.toggleAllCategories(!state.allCategoriesSelected)
            } label: {
                HStack {
                    Image(systemName: state.allCategoriesSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(state.allCategoriesSelected ? .blue : .secondary)

                    Text(
                        state.allCategoriesSelected ? String(localized: "Deselect All")
                            : String(localized: "Select All")
                    )
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }

        private var categoriesList: some View {
            ForEach(SettingsExport.StateModel.ExportCategory.allCases) { category in
                categoryRow(category)
                    .padding(.vertical, 2)
            }
        }

        @ViewBuilder private func categoryRow(_ category: SettingsExport.StateModel.ExportCategory) -> some View {
            Button {
                toggle(category)
            } label: {
                HStack {
                    Image(systemName: state.selectedCategories.contains(category) ? "checkmark.square.fill" : "square")
                        .foregroundColor(state.selectedCategories.contains(category) ? .blue : .secondary)
                    Text(category.rawValue)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }

        private func toggle(_ category: SettingsExport.StateModel.ExportCategory) {
            if state.selectedCategories.contains(category) {
                state.selectedCategories.remove(category)
            } else {
                state.selectedCategories.insert(category)
            }
        }

        private var exportActionSection: some View {
            Section {
                Button {
                    Task { await runExportTapped() }
                } label: {
                    if state.isExporting {
                        HStack {
                            ProgressView().padding(.trailing, 10)
                            Text("Exporting...")
                        }
                    } else {
                        Text("Export Settings")
                    }
                }
                .disabled(state.selectedCategories.isEmpty)
                .frame(maxWidth: .infinity, alignment: .center)
                .tint(.white)
            }
            .listRowBackground(state.selectedCategories.isEmpty ? Color(.systemGray4) : Color(.systemBlue))
        }

        @ViewBuilder private var shareSheet: some View {
            if let fileURL = exportedFileURL {
                ShareSheet(activityItems: [fileURL])
            }
        }

        @MainActor private func runExportTapped() async {
            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
            impactHeavy.impactOccurred()

            state.isExporting = true
            defer { state.isExporting = false }

            switch await state.exportSelectedSettings() {
            case let .success(fileURL):
                await handleExportSuccess(fileURL)
            case let .failure(error):
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }

        @MainActor private func handleExportSuccess(_ fileURL: URL) async {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                exportErrorMessage = "Export file was created but could not be found at: \(fileURL.path)"
                showExportError = true
                return
            }

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int ?? 0
                guard fileSize > 0 else {
                    exportErrorMessage = "Export file is empty (0 bytes)"
                    showExportError = true
                    return
                }

                exportedFileURL = fileURL
                showSettingsExport = true
            } catch {
                exportErrorMessage = "Could not verify file attributes: \(error.localizedDescription)"
                showExportError = true
            }
        }
    }
}

//            // TODO: implement help sheet
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button(
//                        action: {
//                            state.isHelpSheetPresented.toggle()
//                        },
//                        label: {
//                            Image(systemName: "questionmark.circle")
//                        }
//                    )
//                }
//            }
//            .sheet(isPresented: $state.isHelpSheetPresented) {
//                NavigationStack {
//                    List {
//                        Text("Hello World!")
//                    }
//                }
//                .padding()
//                .presentationDetents(
//                    [.fraction(0.9), .large],
//                    selection: $state.helpSheetDetent
//                )
//            }
