//
//  ViewModels.swift
//  DietTracker
//
//  Created by Kartikay Singh on 27/8/2025.
//

import Foundation

// Simple persistence model that holds the entire app state.
// We use Codable to easily save/load it as JSON.
private struct AppState: Codable {
    var userFirstName: String
    var goals: Goal
    var logs: [String: DailyLog]   // keyed by ISO8601 date string
}

// Store is a helper for reading/writing the single JSON file.
private enum Store {
    static var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("DietTrackerState.json")
    }

    static func save(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Store.save error:", error)
        }
    }

    static func load() -> AppState? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            return nil
        }
    }
}

/// App-wide view model. This is the single source of truth.
/// Holds user name, goals, all daily logs, and recent meals/items.
/// Persists changes automatically to disk.
@MainActor
final class AppViewModel: ObservableObject {
    @Published var userFirstName: String = "Alex"
    @Published var goals: Goal = Goal(dailyCalories: 2200, dailyProtein: 140, dailyCarbs: 250, dailyFat: 70)
    @Published private(set) var logsByDay: [Date: DailyLog] = [:]

    @Published private(set) var recentFoodItems: [FoodItem] = []
    @Published private(set) var recentMeals: [Meal] = []

    var today: Date { Date().stripTimeToStartOfDay() }

    init() {
        // Try loading saved state, or seed with example data.
        if let state = Store.load() {
            self.userFirstName = state.userFirstName
            self.goals = state.goals
            var rebuilt: [Date: DailyLog] = [:]
            let f = ISO8601DateFormatter()
            for (k, v) in state.logs {
                if let date = f.date(from: k) {
                    rebuilt[date.stripTimeToStartOfDay()] = v
                }
            }
            self.logsByDay = rebuilt
        } else {
            seed()
        }
        rebuildRecents()
    }

    /// Seeds the app with a simple breakfast so the UI isn’t empty on first run.
    private func seed() {
        let eggs = FoodItem(name: "Eggs (2)", nutrients: .init(calories: 150, protein: 12, carbs: 1, fat: 10))
        let oats  = FoodItem(name: "Oatmeal (50g)", nutrients: .init(calories: 190, protein: 7, carbs: 33, fat: 3))
        let breakfast = Meal(name: "Breakfast", emoji: "🍳", items: [eggs, oats])
        logsByDay[today] = DailyLog(date: today, meals: [breakfast])
        persist()
    }

    /// Returns the log for a given date, creating it if needed.
    func log(for date: Date) -> DailyLog {
        let key = date.stripTimeToStartOfDay()
        if let existing = logsByDay[key] { return existing }
        let new = DailyLog(date: key)
        logsByDay[key] = new
        persist()
        return new
    }

    /// Save a modified log and update recents.
    func save(_ log: DailyLog) {
        logsByDay[log.date.stripTimeToStartOfDay()] = log
        captureRecents(from: log)
        persist()
    }

    func updateGoals(_ goals: Goal) {
        self.goals = goals
        persist()
    }

    func updateName(_ name: String) {
        self.userFirstName = name
        persist()
    }

    /// Update the recent items/meals lists whenever a log changes.
    private func captureRecents(from log: DailyLog) {
        let mergedMeals = log.meals + recentMeals
        var seenMealNames = Set<String>()
        var dedupedMeals: [Meal] = []
        for m in mergedMeals {
            let key = m.name.lowercased()
            if !seenMealNames.contains(key) {
                dedupedMeals.append(m)
                seenMealNames.insert(key)
            }
        }
        recentMeals = Array(dedupedMeals.prefix(12))

        let newItems = log.meals.flatMap { $0.items }
        let mergedItems = newItems + recentFoodItems
        var seenItemNames = Set<String>()
        var dedupedItems: [FoodItem] = []
        for i in mergedItems {
            let key = i.name.lowercased()
            if !seenItemNames.contains(key) {
                dedupedItems.append(i)
                seenItemNames.insert(key)
            }
        }
        recentFoodItems = Array(dedupedItems.prefix(12))
    }

    private func rebuildRecents() {
        recentFoodItems = []
        recentMeals = []
        for (_, log) in logsByDay { captureRecents(from: log) }
    }

    /// Save everything to disk as JSON.
    private func persist() {
        var isoLogs: [String: DailyLog] = [:]
        let f = ISO8601DateFormatter()
        for (date, log) in logsByDay {
            isoLogs[f.string(from: date.stripTimeToStartOfDay())] = log
        }
        Store.save(.init(userFirstName: userFirstName, goals: goals, logs: isoLogs))
    }
}

/// View model for a single day’s log (usually today).
/// Exposes derived totals and goal status for UI.
@MainActor
final class DailyLogViewModel: ObservableObject {
    @Published private(set) var log: DailyLog
    private let appVM: AppViewModel

    init(appVM: AppViewModel, date: Date = Date()) {
        self.appVM = appVM
        self.log = appVM.log(for: date)
    }

    func addMeal(_ meal: Meal) {
        log.meals.append(meal)
        appVM.save(log)
        objectWillChange.send()
    }

    func removeMeal(_ meal: Meal) {
        if let idx = log.meals.firstIndex(where: { $0.id == meal.id }) {
            log.meals.remove(at: idx)
            appVM.save(log)
            objectWillChange.send()
        }
    }

    var totals: Nutrients { log.macrosBreakdown() }
    var status: GoalStatus { log.goalStatus(against: appVM.goals) }
}

/// View model for the add food form.
/// Handles validation and building of FoodItem objects.
@MainActor
final class AddFoodViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var calories: String = ""
    @Published var protein: String = ""
    @Published var carbs: String = ""
    @Published var fat: String = ""

    func buildItem() throws -> FoodItem {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw DomainError.invalidName }

        guard
            let cals = Int(calories),
            let p = Int(protein),
            let c = Int(carbs),
            let f = Int(fat),
            cals >= 0, p >= 0, c >= 0, f >= 0
        else { throw DomainError.invalidNumbers }

        let n = Nutrients(calories: cals, protein: p, carbs: c, fat: f)
        return FoodItem(name: name, nutrients: n)
    }

    func quickMeal(from items: [FoodItem], name: String? = nil) -> Meal {
        Meal(name: name ?? "Meal", items: items)
    }

    func clear() {
        name = ""; calories = ""; protein = ""; carbs = ""; fat = ""
    }
}

/// View model for editing daily goals.
/// Holds text fields and saves back to AppViewModel.
@MainActor
final class GoalsViewModel: ObservableObject {
    @Published var dailyCalories: String
    @Published var dailyProtein: String
    @Published var dailyCarbs: String
    @Published var dailyFat: String

    private let appVM: AppViewModel

    init(appVM: AppViewModel) {
        self.appVM = appVM
        self.dailyCalories = appVM.goals.dailyCalories.map(String.init) ?? ""
        self.dailyProtein  = appVM.goals.dailyProtein.map(String.init)  ?? ""
        self.dailyCarbs    = appVM.goals.dailyCarbs.map(String.init)    ?? ""
        self.dailyFat      = appVM.goals.dailyFat.map(String.init)      ?? ""
    }

    func save() {
        appVM.updateGoals(Goal(
            dailyCalories: Int(dailyCalories),
            dailyProtein:  Int(dailyProtein),
            dailyCarbs:    Int(dailyCarbs),
            dailyFat:      Int(dailyFat)
        ))
    }
}
