import Foundation

struct Nutrients: Codable, Equatable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int

    static let zero = Nutrients(calories: 0, protein: 0, carbs: 0, fats: 0)
    static let defaultGoals = Nutrients(calories: 2000, protein: 100, carbs: 250, fats: 65)

    var values: [Int] { [calories, protein, carbs, fats] }

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein,
             carbs: lhs.carbs + rhs.carbs, fats: lhs.fats + rhs.fats)
    }
}

struct Meal: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var name: String
    var nutrients: Nutrients
}

struct FoodEntry: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var meal: Meal
    var loggedAt = Date.now
}

struct DailyNutrition: Codable, Equatable {
    var goals = Nutrients.defaultGoals
    var entries: [FoodEntry] = []
    var consumed: Nutrients { entries.reduce(.zero) { $0 + $1.meal.nutrients } }
}
