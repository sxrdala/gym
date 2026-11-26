import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var journal: Journal
    @State private var adding = false
    @State private var editing: ExercisePreset?
    @State private var failure: String?
    private var defaults: WorkoutDefaults { journal.snapshot.defaults }

    var body: some View {
        Form {
            Section("Workout defaults") {
                Stepper("Sets · \(defaults.sets)", value: binding(\.sets), in: 1...20)
                Picker("Unit", selection: binding(\.unit)) {
                    ForEach(LoadUnit.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                Stepper("Increment · \(defaults.increment.formatted()) \(defaults.unit.rawValue)",
                        value: binding(defaults.unit == .kg ? \.kgIncrement : \.lbIncrement), in: 0.25...100, step: 0.25)
            }
            Section("Spotify") { SpotifyConfig() }
            Section("Exercise presets") {
                Button { adding = true } label: { Label("Add preset", systemImage: "plus") }
                ForEach(journal.snapshot.presets) { preset in
                    Button { editing = preset } label: {
                        HStack { Text(preset.name); Spacer(); Image(systemName: "pencil").foregroundStyle(Style.muted) }
                    }.foregroundStyle(.primary).swipeActions {
                        Button("Delete", role: .destructive) {
                            do { try journal.deletePreset(preset.id) } catch { failure = error.localizedDescription }
                        }
                    }
                }
            }
        }.monospacedDigit().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $adding) {
                NameSheet("New preset", prompt: "Exercise name") { try journal.savePreset($0) }
            }
            .sheet(item: $editing) { preset in
                NameSheet("Edit preset", prompt: "Exercise name", initial: preset.name) {
                    try journal.savePreset($0, id: preset.id)
                }
            }.reporting($failure)
    }

    private func binding<T>(_ key: WritableKeyPath<WorkoutDefaults, T>) -> Binding<T> {
        Binding(get: { defaults[keyPath: key] }, set: { value in
            var updated = defaults
            updated[keyPath: key] = value
            do { try journal.saveDefaults(updated); Haptics.tap() } catch { failure = error.localizedDescription }
        })
    }
}
