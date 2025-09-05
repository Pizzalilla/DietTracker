//
//  Models.swift
//  DietTracker
//
//  Created by Kartikay Singh on 27/8/2025.
//


//  Rationale & design:
//  • Keep the **entire domain** in one file to align with the assignment’s minimal structure, while still showing clear architecture.
//  • Prefer **composition over inheritance**: a DailyLog contains Meals; a Meal contains FoodItems. This maps directly to the real domain and avoids fragile base classes.
//  • Use **protocol-oriented design** to express shared behaviour without forcing hierarchy:
//      - `Trackable` exposes calorie/macros so any future type (Snack, Recipe, ImportedBarcodeItem) can plug in.
//      - `GoalCheckable` cleanly separates goal evaluation from UI so views stay dumb.
//  Choose **value semantics** for safety and SwiftUI-friendliness: structs are cheap to copy, predictable in state updates, and easy to test.
//  Treat missing goal fields (`nil`) as **“unconstrained”**: users can start simple (only calories) and layer in macros later without changing code.
//  Normalize dates to **start-of-day** so a day’s log has a stable key regardless of time zones or creation time.


import Foundation

/// Shared capability for types that can report calories and macronutrients.
/// Conforming types decide *how* they aggregate (single item vs. sum of children).
protocol Trackable {
    func calorieCount() -> Int
    func macrosBreakdown() -> Nutrients
}

/// Capability for evaluating a value against a nutrition Goal.
/// Keeps decision logic out of the UI; views can render a simple status/issue list.
protocol GoalCheckable {
    func goalStatus(against goal: Goal) -> GoalStatus
}

/// Immutable bundle of nutrition values.
/// Value type for safe composition; Codable/Equatable for storage and tests.
struct Nutrients: Equatable, Codable {
    var calories: Int   // kcal
    var protein: Int    // grams
    var carbs: Int      // grams
    var fat: Int        // grams

    static let zero = Nutrients(calories: 0, protein: 0, carbs: 0, fat: 0)

    /// Field‑wise addition enables clean reductions across items/meals/logs.
    static func +(lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }
}

/// A user-entered food with a name and nutrients.
/// Identifiable for stable SwiftUI lists; Trackable so it can participate in totals.
struct FoodItem: Identifiable, Equatable, Codable, Trackable {
    let id: UUID
    var name: String
    var nutrients: Nutrients

    init(id: UUID = UUID(), name: String, nutrients: Nutrients) {
        self.id = id
        self.name = name
        self.nutrients = nutrients
    }

    func calorieCount() -> Int { nutrients.calories }
    func macrosBreakdown() -> Nutrients { nutrients }
}

/// A named grouping of food items (e.g., Breakfast, Lunch).
/// Designed as composition; aggregation happens via macrosBreakdown().
struct Meal: Identifiable, Equatable, Codable, Trackable {
    let id: UUID
    var name: String
    var emoji: String
    var items: [FoodItem]

    init(id: UUID = UUID(), name: String, emoji: String = "🍽", items: [FoodItem]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.items = items
    }

    /// Sum nutrients across all items; calories derive from the sum.
    func macrosBreakdown() -> Nutrients { items.reduce(.zero) { $0 + $1.nutrients } }
    func calorieCount() -> Int { macrosBreakdown().calories }
}

/// The nutrition record for a single calendar day.
/// Acts as an aggregator (Trackable) and also knows how to evaluate itself (GoalCheckable).
struct DailyLog: Identifiable, Equatable, Codable, Trackable, GoalCheckable {
    let id: UUID
    var date: Date      // normalized to start-of-day for stable keys
    var meals: [Meal]

    init(id: UUID = UUID(), date: Date, meals: [Meal] = []) {
        self.id = id
        self.date = date.stripTimeToStartOfDay()
        self.meals = meals
    }

    func macrosBreakdown() -> Nutrients { meals.reduce(.zero) { $0 + $1.macrosBreakdown() } }
    func calorieCount() -> Int { macrosBreakdown().calories }

    /// Goal evaluation semantics:
    /// • Missing goal fields are treated as unconstrained (no issue).
    /// • Calories/Carbs/Fat flag when **over**; Protein flags when **under**.
    /// This mirrors common tracking apps and matches the UI’s green/red cues.
    func goalStatus(against goal: Goal) -> GoalStatus {
        let m = macrosBreakdown()
        var issues: [GoalIssue] = []

        if let c = goal.dailyCalories, m.calories > c { issues.append(.overCalories(by: m.calories - c)) }
        if let p = goal.dailyProtein, m.protein < p { issues.append(.underProtein(by: p - m.protein)) }
        if let cc = goal.dailyCarbs,   m.carbs  > cc { issues.append(.overCarbs(by:   m.carbs  - cc)) }
        if let f  = goal.dailyFat,     m.fat    > f  { issues.append(.overFat(by:     m.fat    - f )) }

        return issues.isEmpty ? .onTrack : .needsAttention(issues)
    }
}

/// User targets for a day. nil means “not tracking that dimension right now”.
/// Optionality lets users start simple (only calories) and scale up.
struct Goal: Equatable, Codable {
    var dailyCalories: Int?
    var dailyProtein: Int?
    var dailyCarbs: Int?
    var dailyFat: Int?

    static let none = Goal(dailyCalories: nil, dailyProtein: nil, dailyCarbs: nil, dailyFat: nil)
}

/// Specific deviations found when comparing a log to a goal.
/// Cases carry magnitudes so the UI can explain “by how much”.
enum GoalIssue: Equatable, Codable, CustomStringConvertible, Identifiable {
    case overCalories(by: Int)
    case underProtein(by: Int)
    case overCarbs(by: Int)
    case overFat(by: Int)

    var id: String { description }

    var description: String {
        switch self {
        case .overCalories(let x): return "Over calories by \(x)"
        case .underProtein(let x): return "Under protein by \(x)g"
        case .overCarbs(let x):    return "Over carbs by \(x)g"
        case .overFat(let x):      return "Over fat by \(x)g"
        }
    }
}

/// Summary outcome for goal evaluation. Views can render this with simple switches.
enum GoalStatus: Equatable, Codable {
    case onTrack
    case needsAttention([GoalIssue])
}

/// Domain-level validation errors surfaced to the UI.
/// LocalizedError makes them user-friendly by default via localizedDescription.
enum DomainError: LocalizedError {
    case invalidName
    case invalidNumbers

    var errorDescription: String? {
        switch self {
        case .invalidName:   return "Please enter a name."
        case .invalidNumbers:return "Please enter valid non-negative numbers."
        }
    }
}

/// Utilities specific to our domain.
extension Date {
    /// Use the current calendar’s start-of-day to make Date keys stable for a “daily” log.
    func stripTimeToStartOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
