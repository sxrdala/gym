import SwiftUI

struct UnitSwitch: View {
    @Binding var selection: LoadUnit

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LoadUnit.allCases) { unit in
                Button { selection = unit } label: {
                    Text(unit.rawValue).font(.subheadline.weight(.semibold))
                        .frame(minWidth: 46, minHeight: 44)
                        .background(selection == unit ? Color(white: 0.23) : .clear,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(unit == .kg ? "Kilograms" : "Pounds")
                .accessibilityAddTraits(selection == unit ? .isSelected : [])
            }
        }.padding(2).background(Style.card, in: RoundedRectangle(cornerRadius: 11))
            .accessibilityElement(children: .contain)
    }
}

struct SetControls: View {
    let unit: LoadUnit
    let increment: Double
    @Binding var kilograms: Double
    @Binding var reps: Int

    var body: some View {
        VStack(spacing: 0) {
            adjustment("Weight", value: unit.display(kilograms).formatted(.number.precision(.fractionLength(0...2))),
                       suffix: unit.rawValue,
                       decrease: { adjust(-increment) }, increase: { adjust(increment) })
            Divider()
            adjustment("Reps", value: String(reps), suffix: "reps",
                       decrease: { reps = max(1, reps - 1) }, increase: { reps += 1 })
        }.padding(.horizontal, 12)
            .background(Style.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Style.line) }
    }

    private func adjust(_ amount: Double) {
        kilograms = unit.kilograms(max(0, unit.display(kilograms) + amount))
    }

    private func adjustment(_ name: String, value: String, suffix: String,
                            decrease: @escaping () -> Void, increase: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value).font(.title.bold()).monospacedDigit()
                Text(suffix).font(.subheadline).foregroundStyle(Style.muted)
            }.accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            IconControl(title: "Decrease \(name.lowercased())", icon: "minus", action: decrease)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 10))
            IconControl(title: "Increase \(name.lowercased())", icon: "plus", action: increase)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 10))
        }.padding(.vertical, 3)
    }
}

struct EditSetSheet: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let entry: LoggedSet
    let lift: ExerciseDraft
    let sessionID: UUID
    @State private var kilograms: Double
    @State private var reps: Int
    @State private var unit: LoadUnit
    @State private var failure: String?

    init(entry: LoggedSet, lift: ExerciseDraft, sessionID: UUID) {
        self.entry = entry
        self.lift = lift
        self.sessionID = sessionID
        _kilograms = State(initialValue: entry.kilograms)
        _reps = State(initialValue: entry.reps)
        _unit = State(initialValue: entry.unit)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(lift.name).font(.headline)
                        Spacer()
                        UnitSwitch(selection: $unit)
                    }
                    SetControls(unit: unit, increment: unit == lift.preferredUnit ? lift.defaultIncrement : unit.increment,
                                kilograms: $kilograms, reps: $reps)
                    PrimaryButton(title: "Save changes", icon: "checkmark") {
                        do {
                            try journal.edit(entry.id, in: sessionID, kilograms: kilograms, reps: reps, unit: unit)
                            dismiss()
                        } catch { failure = error.localizedDescription }
                    }
                }.padding(18)
            }
            .navigationTitle("Edit set \(entry.setNumber)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .reporting($failure)
        }.presentationDetents([.medium, .large])
            .onAppear { Haptics.prepare() }
            .onChange(of: reps) { _ in Haptics.tap() }
            .onChange(of: kilograms) { _ in Haptics.tap() }
    }
}
