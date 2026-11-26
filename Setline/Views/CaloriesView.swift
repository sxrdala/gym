import SwiftUI

private enum NutritionEditor: String, Identifiable {
    case quick = "Quick add"
    case meal = "Create custom meal"
    case goals = "Daily goals"
    var id: Self { self }
}

struct CaloriesView: View {
    @EnvironmentObject private var journal: Journal
    @State private var editor: NutritionEditor?
    @State private var failure: String?
    private var day: Date { journal.selectedDay }
    private var daily: DailyNutrition { journal.nutrition(on: day) }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.headline.monospacedDigit())
                    Spacer()
                    IconControl(title: "Edit daily goals", icon: "slider.horizontal.3") { editor = .goals }
                }
                NutritionSummary(consumed: daily.consumed, goals: daily.goals)
            }.panel().panelRow()
            HStack {
                SectionTitle(text: "Food log")
                Button { editor = .quick } label: { Label("Quick add", systemImage: "plus").frame(minHeight: 44) }
            }.panelRow()
            if daily.entries.isEmpty {
                Text("No food logged for this day.").font(.subheadline).foregroundStyle(Style.muted).panelRow()
            }
            ForEach(FoodPeriod.allCases, id: \.self) { period in
                let entries = daily.entries.filter { FoodPeriod.at($0.loggedAt) == period }
                    .sorted { $0.loggedAt < $1.loggedAt }
                if !entries.isEmpty {
                    Text(period.rawValue).font(.caption.bold()).foregroundStyle(Style.muted).panelRow()
                    ForEach(entries) { entry in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.meal.name).font(.headline)
                                Text(entry.loggedAt, style: .time).font(.caption).foregroundStyle(Style.muted)
                            }
                            Spacer()
                            Text("\(entry.meal.nutrients.calories) kcal").font(.subheadline.monospacedDigit())
                        }.panel().panelRow().swipeActions {
                            Button("Delete", role: .destructive) {
                                do { try journal.deleteFood(entry.id, on: day) }
                                catch { failure = error.localizedDescription }
                            }
                        }
                    }
                }
            }
            HStack {
                SectionTitle(text: "Custom meals")
                IconControl(title: "Create custom meal", icon: "plus") { editor = .meal }
            }.panelRow()
            if journal.snapshot.meals.isEmpty {
                Button("Create your first meal") { editor = .meal }.frame(minHeight: 44).panelRow()
            }
            ForEach(journal.snapshot.meals) { meal in
                Button {
                    do { try journal.logMeal(meal, on: day); Haptics.success() }
                    catch { failure = error.localizedDescription }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.name).font(.headline)
                            Text("\(meal.nutrients.calories) kcal").font(.caption.monospacedDigit()).foregroundStyle(Style.muted)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill").foregroundStyle(Style.mint)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Log \(meal.name)").panel().panelRow()
            }
        }
        .listSurface().navigationTitle("Calories").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { mode in
            NutritionForm(mode: mode, goals: daily.goals) { name, nutrients in
                let meal = Meal(name: name, nutrients: nutrients)
                switch mode {
                case .quick: try journal.logMeal(meal, on: day)
                case .meal: try journal.saveMeal(meal)
                case .goals: try journal.saveGoals(nutrients, on: day)
                }
            }
        }
        .reporting($failure)
    }
}

private enum FoodPeriod: String, CaseIterable {
    case morning = "Morning", afternoon = "Afternoon", evening = "Evening"
    static func at(_ time: Date) -> Self {
        switch TrainingDay.calendar.component(.hour, from: time) {
        case 0..<12: return .morning
        case 12..<18: return .afternoon
        default: return .evening
        }
    }
}

private struct NutritionSummary: View {
    let consumed: Nutrients
    let goals: Nutrients

    var body: some View {
        let remaining = goals.calories - consumed.calories
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(consumed.calories) / \(goals.calories) kcal").font(.title2.bold())
                Text("\(abs(remaining)) kcal \(remaining < 0 ? "over target" : "remaining")")
                    .font(.subheadline).foregroundStyle(Style.muted)
            }
            bar(consumed.calories, goals.calories, Style.mint).accessibilityLabel("Calorie progress")
            macro("Protein", consumed.protein, goals.protein, Style.mint)
            macro("Carbs", consumed.carbs, goals.carbs, Style.blue)
            macro("Fats", consumed.fats, goals.fats, .orange)
        }.monospacedDigit()
    }

    private func macro(_ label: String, _ value: Int, _ goal: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            HStack { Text(label); Spacer(); Text("\(value) / \(goal) g") }.font(.caption.weight(.medium))
            bar(value, goal, color)
        }.accessibilityElement(children: .combine)
    }

    private func bar(_ value: Int, _ goal: Int, _ color: Color) -> some View {
        ProgressView(value: Double(min(value, goal)), total: Double(max(1, goal)))
            .progressViewStyle(.linear).tint(color)
    }
}

private struct NutritionForm: View {
    let mode: NutritionEditor
    let save: (String, Nutrients) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fats: String
    @State private var failure: String?

    init(mode: NutritionEditor, goals: Nutrients, save: @escaping (String, Nutrients) throws -> Void) {
        self.mode = mode
        self.save = save
        _calories = State(initialValue: mode == .goals ? String(goals.calories) : "")
        _protein = State(initialValue: mode == .goals ? String(goals.protein) : "")
        _carbs = State(initialValue: mode == .goals ? String(goals.carbs) : "")
        _fats = State(initialValue: mode == .goals ? String(goals.fats) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if mode != .goals { TextField(mode == .quick ? "Food name (optional)" : "Meal name", text: $name) }
                field("Calories", "kcal", $calories)
                field("Protein", "g", $protein)
                field("Carbs", "g", $carbs)
                field("Fats", "g", $fats)
            }.navigationTitle(mode.rawValue).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(mode == .quick ? "Log" : "Save", action: commit)
                            .disabled(mode == .meal && name.trimmed.isEmpty)
                    }
                }.reporting($failure)
        }
    }

    private func field(_ label: String, _ unit: String, _ value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .accessibilityLabel("\(label) in \(unit)")
            Text(unit).foregroundStyle(Style.muted)
        }
    }

    private func commit() {
        let strings = [calories, protein, carbs, fats]
        let values = strings.map { value in value.isEmpty && mode != .goals ? 0 : Int(value) }
        guard let kcal = values[0], let p = values[1], let c = values[2], let f = values[3],
              !strings.allSatisfy(\.isEmpty) else { failure = JournalError.nutrients.localizedDescription; return }
        do {
            try save(name.trimmed.isEmpty ? "Quick add" : name.trimmed, Nutrients(calories: kcal, protein: p, carbs: c, fats: f))
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}
