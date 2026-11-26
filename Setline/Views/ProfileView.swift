import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var journal: Journal
    @State private var editing = false
    private var profile: AthleteProfile { journal.snapshot.profile }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 10) {
                Text(journal.selectedDay.formatted(.dateTime.month(.abbreviated).day())).font(.caption.bold())
                NetCalories(value: journal.netCalories(on: journal.selectedDay))
                HStack {
                    Text("Food \(journal.nutrition(on: journal.selectedDay).consumed.calories)")
                    Spacer()
                    Text("Burned \(journal.activity(on: journal.selectedDay).burned)")
                }.font(.caption).foregroundStyle(NutritionStyle.calories)
            }.panel().panelRow()
            VStack(spacing: 12) {
                LabeledContent("Weight", value: "\(profile.weightKg.formatted()) kg")
                LabeledContent("Height", value: "\(profile.heightCm.formatted()) cm")
            }.panel().panelRow()
            VStack(spacing: 12) {
                LabeledContent("🔥 Calories", value: "\(profile.goals.calories) kcal").foregroundStyle(NutritionStyle.calories)
                LabeledContent("🥩 Protein", value: "\(profile.goals.protein) g").foregroundStyle(NutritionStyle.protein)
                LabeledContent("🍚 Carbs", value: "\(profile.goals.carbs) g").foregroundStyle(NutritionStyle.carbs)
                LabeledContent("🥑 Fats", value: "\(profile.goals.fats) g").foregroundStyle(NutritionStyle.fats)
                LabeledContent("Step goal", value: "\(profile.stepGoal)")
            }.panel().panelRow()
        }.listSurface().monospacedDigit().navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Edit") { editing = true } } }
            .sheet(isPresented: $editing) { ProfileForm(profile: profile) }
    }
}

private struct ProfileForm: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    @State private var weight: String
    @State private var height: String
    @State private var steps: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fats: String
    @State private var failure: String?

    init(profile: AthleteProfile) {
        _weight = State(initialValue: String(profile.weightKg))
        _height = State(initialValue: String(profile.heightCm))
        _steps = State(initialValue: String(profile.stepGoal))
        _calories = State(initialValue: String(profile.goals.calories))
        _protein = State(initialValue: String(profile.goals.protein))
        _carbs = State(initialValue: String(profile.goals.carbs))
        _fats = State(initialValue: String(profile.goals.fats))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberField(label: "Weight (kg)", text: $weight, decimal: true)
                    NumberField(label: "Height (cm)", text: $height, decimal: true)
                }
                Section("Daily goals") {
                    NutrientFields(calories: $calories, protein: $protein, carbs: $carbs, fats: $fats)
                    NumberField(label: "Steps", text: $steps)
                }
            }.navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                }.reporting($failure)
        }
    }

    private func save() {
        do {
            guard let kg = Double(weight.replacingOccurrences(of: ",", with: ".")),
                  let cm = Double(height.replacingOccurrences(of: ",", with: ".")), let goal = Int(steps),
                  let kcal = Int(calories), let p = Int(protein), let c = Int(carbs), let f = Int(fats)
            else { throw JournalError.invalid }
            try journal.saveProfile(AthleteProfile(weightKg: kg, heightCm: cm,
                                                   goals: Nutrients(calories: kcal, protein: p, carbs: c, fats: f),
                                                   stepGoal: goal))
            Haptics.success()
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}
