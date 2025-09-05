//
//  GoalsViw.swift
//  DietTracker
//
//  Created by Kartikay Singh on 27/8/2025.
//

import SwiftUI

/// Shows today’s progress vs goals and allows editing targets.
/// Uses green for good/hit and red when over a target (except protein).
struct GoalsView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var vm: GoalsViewModel

    init(appVM: AppViewModel) {
        _vm = StateObject(wrappedValue: GoalsViewModel(appVM: appVM))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Today's Progress") {
                    progressRow(title: "🔥 Calories",
                                current: appVM.log(for: Date()).macrosBreakdown().calories,
                                target: appVM.goals.dailyCalories,
                                overIsBad: true)

                    progressRow(title: "🥩 Protein (g)",
                                current: appVM.log(for: Date()).macrosBreakdown().protein,
                                target: appVM.goals.dailyProtein,
                                overIsBad: false) // more protein is OK

                    progressRow(title: "🍞 Carbs (g)",
                                current: appVM.log(for: Date()).macrosBreakdown().carbs,
                                target: appVM.goals.dailyCarbs,
                                overIsBad: true)

                    progressRow(title: "🧈 Fat (g)",
                                current: appVM.log(for: Date()).macrosBreakdown().fat,
                                target: appVM.goals.dailyFat,
                                overIsBad: true)
                }

                Section("Daily Targets") {
                    field(label: "Calories", binding: $vm.dailyCalories, placeholder: "e.g. 2200")
                    field(label: "Protein (g)", binding: $vm.dailyProtein, placeholder: "e.g. 140")
                    field(label: "Carbs (g)", binding: $vm.dailyCarbs, placeholder: "e.g. 250")
                    field(label: "Fat (g)", binding: $vm.dailyFat, placeholder: "e.g. 70")
                    Button { vm.save() } label: { Label("Save Goals", systemImage: "checkmark.circle.fill") }
                }
            }
            .navigationTitle("Your Goals")
        }
    }

    private func field(label: String, binding: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: binding).keyboardType(.numberPad).multilineTextAlignment(.trailing)
        }
    }

    private func progressRow(title: String, current: Int, target: Int?, overIsBad: Bool) -> some View {
        let t = Double(target ?? 0)
        let c = Double(current)
        let progress = t > 0 ? min(c / t, 1.0) : 0
        let over = (t > 0) && (c > t)

        return VStack(alignment: .leading) {
            HStack {
                Text(title).fontWeight(.semibold)
                Spacer()
                if let tgt = target {
                    Text("\(current) / \(tgt)").foregroundStyle(over && overIsBad ? .red : .primary)
                } else {
                    Text("\(current)").foregroundStyle(.secondary)
                }
            }
            ProgressView(value: progress).tint(over && overIsBad ? .red : .green)
            if let tgt = target {
                Text(over && overIsBad ? "Over by \(Int(c - t))" : "\(Int(t - c)) remaining")
                    .font(.caption).foregroundStyle(over && overIsBad ? .red : .secondary)
            }
        }
    }
}
