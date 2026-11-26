import SwiftUI

enum NutritionStyle {
    static let calories = Color(red: 1, green: 59 / 255, blue: 48 / 255)
    static let protein = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
    static let carbs = Color(red: 0, green: 122 / 255, blue: 1)
    static let fats = Color(red: 1, green: 204 / 255, blue: 0)
}

private enum DietPage: String, CaseIterable { case food = "Food", cardio = "Cardio" }
private enum DietEditor: String, Identifiable {
    case quick = "Quick add", meal = "New meal", cardio = "Log cardio"
    var id: Self { self }
}

struct CaloriesView: View {
    @EnvironmentObject private var journal: Journal
    @EnvironmentObject private var tracker: StepTracker
    @State private var page = DietPage.food
    @State private var editor: DietEditor?
    @State private var failure: String?
    @Namespace private var selection
    private var day: Date { journal.selectedDay }
    private var daily: DailyNutrition { journal.nutrition(on: day) }
    private var activity: DailyActivity { journal.activity(on: day) }

    var body: some View {
        List {
            HStack(spacing: 0) {
                ForEach(DietPage.allCases, id: \.self) { item in
                    Button {
                        withAnimation(Style.motion) { page = item }; Haptics.tap()
                    } label: {
                        Text(item.rawValue).font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(page == item ? .black : .white)
                            .background {
                                if page == item { Capsule().fill(Style.mint).matchedGeometryEffect(id: "page", in: selection) }
                            }
                    }.buttonStyle(.plain).accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }.background(Style.card, in: Capsule()).panelRow()
            DayStrip { date in change { try journal.selectDay(date) } }.panelRow()
            if page == .food { food } else { cardio }
        }.listSurface().navigationTitle("Diet").navigationBarTitleDisplayMode(.inline)
            .monospacedDigit()
            .sheet(item: $editor) { mode in
                if mode == .cardio { CardioForm(day: day) }
                else { MealForm(day: day, library: mode == .meal) }
            }.reporting($failure)
    }

    @ViewBuilder private var food: some View {
        VStack(alignment: .leading, spacing: 12) {
            NetCalories(value: journal.netCalories(on: day))
            bar("🔥 Consumed", daily.consumed.calories, daily.goals.calories, "kcal", NutritionStyle.calories)
            bar("🥩 Protein", daily.consumed.protein, daily.goals.protein, "g", NutritionStyle.protein)
            bar("🍚 Carbs", daily.consumed.carbs, daily.goals.carbs, "g", NutritionStyle.carbs)
            bar("🥑 Fats", daily.consumed.fats, daily.goals.fats, "g", NutritionStyle.fats)
        }.panel().panelRow()
        header("Custom meals", "New meal", .meal)
        ForEach(journal.snapshot.meals) { meal in
            Button { change { try journal.logMeal(meal, on: day) } } label: {
                HStack {
                    Text(meal.name); Spacer(); kcal(meal.nutrients.calories)
                    Image(systemName: "plus.circle.fill")
                }.contentShape(Rectangle()).frame(minHeight: 44)
            }.buttonStyle(.plain).panelRow()
        }
        header("Food log", "Quick add", .quick)
        ForEach(daily.entries.sorted { $0.loggedAt > $1.loggedAt }) { entry in
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.meal.name)
                    Text(entry.loggedAt, style: .time).font(.caption).foregroundStyle(Style.muted)
                }
                Spacer(); kcal(entry.meal.nutrients.calories)
            }.panel().panelRow().swipeActions {
                Button("Delete", role: .destructive) { change { try journal.deleteFood(entry.id, on: day) } }
            }
        }
    }

    @ViewBuilder private var cardio: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("🔥 Burned", value: "\(activity.burned) kcal").font(.headline).foregroundStyle(NutritionStyle.calories)
            let steps = activity.steps
            HStack {
                Label("Steps", systemImage: "figure.walk")
                Spacer()
                Text("\(steps.map { String($0.count) } ?? "—") / \(journal.snapshot.profile.stepGoal)")
            }
            ProgressView(value: Double(min(steps?.count ?? 0, journal.snapshot.profile.stepGoal)),
                         total: Double(journal.snapshot.profile.stepGoal))
                .tint(Style.mint).animation(Style.motion, value: steps?.count)
            if let steps { kcal(steps.calories) }
            if let message = tracker.status { Text(message).font(.caption).foregroundStyle(Style.muted) }
        }.panel().panelRow()
        header("Sessions", "Log cardio", .cardio)
        ForEach(activity.sessions.reversed()) { session in
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                    Text("\(session.minutes) min · \(session.met.formatted()) MET").font(.caption).foregroundStyle(Style.muted)
                }
                Spacer(); kcal(session.calories)
            }.panel().panelRow().swipeActions {
                Button("Delete", role: .destructive) { change { try journal.deleteCardio(session.id, on: day) } }
            }
        }
    }

    private func header(_ title: String, _ action: String, _ mode: DietEditor) -> some View {
        HStack { SectionTitle(text: title); IconControl(title: action, icon: "plus") { editor = mode } }.panelRow()
    }

    private func kcal(_ value: Int) -> some View {
        Text("🔥 \(value) kcal").font(.subheadline).foregroundStyle(NutritionStyle.calories)
    }

    private func bar(_ name: String, _ value: Int, _ goal: Int, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            HStack { Text(name); Spacer(); Text("\(value) / \(goal) \(unit)") }.font(.caption.bold()).foregroundStyle(color)
            ProgressView(value: Double(min(value, goal)), total: Double(max(1, goal)))
                .tint(color).animation(Style.motion, value: value).animation(Style.motion, value: goal)
        }.accessibilityElement(children: .combine)
    }

    private func change(_ action: () throws -> Void) {
        do { try action(); Haptics.tap() } catch { failure = error.localizedDescription }
    }
}

struct NetCalories: View {
    let value: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🔥 Net calories").font(.subheadline)
            Text("\(value) kcal").font(.title.bold()).monospacedDigit()
        }.foregroundStyle(NutritionStyle.calories).accessibilityElement(children: .combine)
    }
}

struct NumberField: View {
    let label: String
    @Binding var text: String
    var decimal = false
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label).foregroundStyle(color)
            Spacer()
            TextField("0", text: $text).accessibilityLabel(label).monospacedDigit()
                .keyboardType(decimal ? .decimalPad : .numberPad).multilineTextAlignment(.trailing)
        }
    }
}

struct NutrientFields: View {
    @Binding var calories: String
    @Binding var protein: String
    @Binding var carbs: String
    @Binding var fats: String

    var body: some View {
        NumberField(label: "🔥 kcal", text: $calories, color: NutritionStyle.calories)
        NumberField(label: "🥩 Protein (g)", text: $protein, color: NutritionStyle.protein)
        NumberField(label: "🍚 Carbs (g)", text: $carbs, color: NutritionStyle.carbs)
        NumberField(label: "🥑 Fats (g)", text: $fats, color: NutritionStyle.fats)
    }
}

private struct MealForm: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let day: Date
    let library: Bool
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fats = ""
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Meal name", text: $name)
                NutrientFields(calories: $calories, protein: $protein, carbs: $carbs, fats: $fats)
            }.navigationTitle(library ? "New meal" : "Quick add").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(library ? "Save" : "Log", action: save)
                            .disabled((library && name.trimmed.isEmpty) || [calories, protein, carbs, fats].allSatisfy(\.isEmpty))
                    }
                }.reporting($failure)
        }
    }

    private func save() {
        func number(_ text: String) -> Int? { text.isEmpty ? 0 : Int(text) }
        guard let kcal = number(calories), let p = number(protein), let c = number(carbs), let f = number(fats)
        else { failure = JournalError.nutrients.localizedDescription; return }
        let meal = Meal(name: name.trimmed.isEmpty ? "Quick add" : name.trimmed,
                        nutrients: Nutrients(calories: kcal, protein: p, carbs: c, fats: f))
        do {
            if library { try journal.saveMeal(meal) } else { try journal.logMeal(meal, on: day) }
            Haptics.success(); dismiss()
        } catch { failure = error.localizedDescription }
    }
}

private enum CardioType: String, CaseIterable {
    case run = "Running", walk = "Incline Walk", ride = "Cycling", spar = "Sparring", custom = "Custom"
    var met: String {
        switch self {
        case .run: return "8"
        case .walk: return "5"
        case .ride: return "7"
        case .spar: return "9"
        case .custom: return "4"
        }
    }
}

private struct CardioForm: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var type = CardioType.run
    @State private var name = ""
    @State private var minutes = "30"
    @State private var met = CardioType.run.met
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Activity", selection: $type) {
                    ForEach(CardioType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.onChange(of: type) { met = $0.met }
                if type == .custom { TextField("Activity name", text: $name) }
                NumberField(label: "Minutes", text: $minutes)
                NumberField(label: "Intensity (MET)", text: $met, decimal: true)
            }.navigationTitle("Log cardio").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Log") {
                            do {
                                guard let duration = Int(minutes), let intensity = Double(met.replacingOccurrences(of: ",", with: "."))
                                else { throw JournalError.invalid }
                                try journal.logCardio(type == .custom ? name : type.rawValue, minutes: duration, met: intensity, on: day)
                                Haptics.success(); dismiss()
                            } catch { failure = error.localizedDescription }
                        }
                    }
                }.reporting($failure)
        }
    }
}
