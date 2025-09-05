//
//  DaillyLogView.swift
//  DietTracker
//
//  Created by Kartikay Singh on 27/8/2025.
//

import SwiftUI

/// Circular progress ring that shows calories vs goal.
/// If progress is > 1 (over goal), it changes color to red.
struct RingProgressView: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var baseColor: Color = .green
    var overColor: Color = .red

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1)))
                .stroke(progress > 1 ? overColor : baseColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // starts from top (12 o'clock)
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

/// Dashboard screen: shows greeting, calorie ring, macro cards, and today’s meals.
struct DailyLogView: View {
    @ObservedObject private var vm: DailyLogViewModel
    @EnvironmentObject private var appVM: AppViewModel

    // Editing name sheet state
    @State private var showEditName = false
    @State private var tempName = ""

    init(appVM: AppViewModel) {
        self.vm = DailyLogViewModel(appVM: appVM)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                headerCard
                macrosGrid
                todayList
            }
            .background(LinearGradient(colors: [Color.purple.opacity(0.12), Color.clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showEditName) { editNameSheet }
        .onAppear { tempName = appVM.userFirstName }
    }

    // Sheet to edit the user’s name
    private var editNameSheet: some View {
        NavigationStack {
            Form { TextField("First name", text: $tempName) }
                .navigationTitle("Edit Name")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEditName = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            appVM.updateName(tempName.trimmingCharacters(in: .whitespacesAndNewlines))
                            showEditName = false
                        }
                    }
                }
        }
    }

    // Greeting + calories ring
    private var headerCard: some View {
        let goalCals = Double(appVM.goals.dailyCalories ?? max(vm.totals.calories, 1))
        let progress = goalCals == 0 ? 0 : Double(vm.totals.calories) / goalCals

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Good morning, \(appVM.userFirstName)! 👋").font(.title2).bold()
                Spacer()
                Button { tempName = appVM.userFirstName; showEditName = true } label: {
                    Image(systemName: "pencil").imageScale(.large)
                }
            }

            HStack(spacing: 16) {
                ZStack {
                    RingProgressView(progress: progress).frame(width: 110, height: 110)
                    VStack {
                        Text("\(vm.totals.calories)").font(.headline)
                        Text("calories").font(.caption).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading) {
                    if let g = appVM.goals.dailyCalories {
                        Text("\(vm.totals.calories) / \(g) kcal")
                            .foregroundStyle(progress > 1 ? .red : .primary)
                        Text(progress > 1 ? "Over by \(vm.totals.calories - g)" :
                                "\(g - vm.totals.calories) remaining")
                            .font(.caption)
                            .foregroundStyle(progress > 1 ? .red : .secondary)
                    } else {
                        Text("No calorie target").foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        .padding([.horizontal, .top])
    }

    // Macro cards grid
    private var macrosGrid: some View {
        let t = vm.totals
        let g = appVM.goals

        func tintForProtein() -> Color { (g.dailyProtein != nil && t.protein >= g.dailyProtein!) ? .green : .primary }
        func tintForCarbs()   -> Color { (g.dailyCarbs   != nil && t.carbs   >  g.dailyCarbs!)   ? .red   : .primary }
        func tintForFat()     -> Color { (g.dailyFat     != nil && t.fat     >  g.dailyFat!)     ? .red   : .primary }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            macroCard(title: "Protein", value: "\(t.protein)g", system: "bolt.fill", tint: tintForProtein())
            macroCard(title: "Carbs",   value: "\(t.carbs)g",   system: "leaf.fill", tint: tintForCarbs())
            macroCard(title: "Fat",     value: "\(t.fat)g",     system: "drop.fill", tint: tintForFat())
            macroCard(title: "Water",   value: "2.1L",          system: "drop.triangle.fill", tint: .primary)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func macroCard(title: String, value: String, system: String, tint: Color) -> some View {
        HStack {
            Image(systemName: system).foregroundStyle(tint)
            VStack(alignment: .leading) {
                Text(value).font(.headline).foregroundStyle(tint)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
    }

    // Today’s meals
    private var todayList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Food").font(.headline)
                Spacer()
                NavigationLink { AddFoodView(appVM: appVM) } label: {
                    Text("+ Add Food").fontWeight(.semibold)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
                        .foregroundStyle(.white)
                }
                .frame(width: 140)
            }
            .padding(.horizontal)

            ForEach(vm.log.meals) { meal in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(meal.emoji) \(meal.name)").bold()
                        Spacer()
                        Text("\(meal.calorieCount()) cal").foregroundStyle(.secondary)
                    }
                    Divider()
                    ForEach(meal.items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.nutrients.calories) cal").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .systemBackground)))
                .contextMenu {
                    Button(role: .destructive) { vm.removeMeal(meal) } label: {
                        Label("Delete Meal", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.bottom)
    }
}
