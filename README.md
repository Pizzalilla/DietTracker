# DietTracker

An iOS application built with **SwiftUI**, demonstrating **Object-Oriented** and **Protocol-Oriented** design principles, along with MVVM architecture. The app allows users to log food, track daily calories and macros, set nutrition goals, and visualize progress.

---

## ✨ Features

- **Add Food Easily**
  - Quick presets (e.g., Apple, Salad, Chicken)  
  - Recently used meals and items for one-tap re-adding  
  - “Quick Add” form for custom foods  

- **Daily Tracking**
  - Personalized greeting with editable name  
  - Circular progress ring for calories vs. target  
  - Macro cards (Protein, Carbs, Fat, Water) with color feedback  
  - Red when over target, green when protein goal is met  

- **Goal Management**
  - Edit daily calorie and macro targets  
  - Live progress view that updates as you add meals  

- **Persistence**
  - All data (logs, goals, name) saved automatically in a JSON file in the app’s Documents directory  
  - State is restored when the app restarts  

- **Error Handling**
  - Alerts for invalid inputs (e.g., empty name or negative numbers)  
  - Confirmation messages when food or meals are successfully added  

---

## 🏗 Architecture & Design

- **Models.swift**  
  Encapsulates domain logic (FoodItem, Meal, DailyLog, Goal). Uses:
  - **Composition over inheritance** → Meals are made of FoodItems, Logs are made of Meals.  
  - **Protocols (`Trackable`, `GoalCheckable`)** → Shared behaviours without forced class hierarchies.  
  - **Value types (`struct`)** → Safer state management in SwiftUI.  
  - **Codable/Equatable** → Persistence and easy testing.  

- **ViewModels/**  
  - `AppViewModel`: The single source of truth (user name, goals, logs, recents). Handles persistence.  
  - `DailyLogViewModel`: Exposes today’s log totals and handles add/remove of meals.  
  - `AddFoodViewModel`: Validates user input and builds FoodItems.  
  - `GoalsViewModel`: Manages text bindings for editing goals.  

- **Views/**  
  - `DailyLogView`: Home dashboard with calorie ring, macros grid, and today’s meals.  
  - `AddFoodView`: Presets, recents, search, and Quick Add form.  
  - `GoalsView`: Shows today’s progress vs. goals and allows editing of targets.  

- **MVVM Pattern**  
  Views are kept declarative and simple, with business logic pushed into ViewModels. Models stay dumb, focusing only on domain data and rules.  

---

## 🚀 Getting Started

1. Open the project in **Xcode 15+**.  
2. Run the app on a simulator or device.  
3. Add food using presets, recents, or Quick Add.  
4. Adjust daily goals in the “Goals” tab.  
5. Relaunch the app — all data is persisted in JSON automatically.  
