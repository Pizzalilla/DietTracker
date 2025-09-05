//
//  AddFoodView.swift
//  DietTracker
//
//  Created by Kartikay Singh on 27/8/2025.
//

import SwiftUI

/// Add food screen: supports presets, search, recents, and manual quick add.
/// Provides confirmation alerts after adding so the user knows it worked.
struct AddFoodView: View {
    @ObservedObject private var logVM: DailyLogViewModel
    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var addVM = AddFoodViewModel()

    @State private var query = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAdded = false
    @State private var addedText = "Added!"

    init(appVM: AppViewModel) {
        self.logVM = DailyLogViewModel(appVM: appVM)
    }

    // Some static preset foods
    private var presets: [FoodItem] {
        [
            FoodItem(name: "Apple",           nutrients: .init(calories: 95,  protein: 0,  carbs: 25, fat: 0)),
            FoodItem(name: "Caesar Salad",    nutrients: .init(calories: 320, protein: 18, carbs: 12, fat: 22)),
            FoodItem(name: "Grilled Chicken", nutrients: .init(calories: 231, protein: 43, carbs: 0,  fat: 5))
        ]
    }

    // Combine presets with recently used items, filtered by search
    private var searchableItems: [FoodItem] {
        let base = presets + appVM.recentFoodItems
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search for food…", text: $query)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
                .padding(.horizontal)

                List {
                    if !appVM.recentMeals.isEmpty {
                        Section("Recently Added Meals") {
                            ForEach(appVM.recentMeals) { meal in
                                HStack {
                                    Text("\(meal.emoji) \(meal.name)")
                                    Spacer()
                                    Text("\(meal.calorieCount()) cal").foregroundStyle(.secondary)
                                    Button("Add") { add(meal: meal) }.buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }

                    Section("Suggestions & Search") {
                        ForEach(searchableItems) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.nutrients.calories) cal").foregroundStyle(.secondary)
                                Button("Add") { add(item: item) }.buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    Section("Quick Add") { quickAdd }
                }
            }
            .navigationTitle("Add Food")
            .alert("Error", isPresented: $showError) { Button("OK", role: .cancel) {} } message: { Text(errorMessage) }
            .alert(addedText, isPresented: $showAdded) { Button("OK", role: .cancel) {} }
        }
    }

    // Quick Add form for custom foods
    private var quickAdd: some View {
        VStack {
            TextField("Name", text: $addVM.name).textFieldStyle(.roundedBorder)
            HStack { Text("Calories"); Spacer(); TextField("0", text: $addVM.calories).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
            HStack { Text("Protein (g)"); Spacer(); TextField("0", text: $addVM.protein).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
            HStack { Text("Carbs (g)"); Spacer(); TextField("0", text: $addVM.carbs).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
            HStack { Text("Fat (g)"); Spacer(); TextField("0", text: $addVM.fat).keyboardType(.numberPad).multilineTextAlignment(.trailing) }

            Button {
                do {
                    let item = try addVM.buildItem()
                    let meal = addVM.quickMeal(from: [item], name: item.name)
                    logVM.addMeal(meal)
                    addedText = "Added \(item.name)"
                    showAdded = true
                    addVM.clear()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            } label: {
                Label("Add as Meal", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // Helper methods for adding
    private func add(item: FoodItem) {
        let meal = addVM.quickMeal(from: [item], name: item.name)
        add(meal: meal)
    }

    private func add(meal: Meal) {
        logVM.addMeal(meal)
        addedText = "Added \(meal.name)"
        showAdded = true
    }
}
