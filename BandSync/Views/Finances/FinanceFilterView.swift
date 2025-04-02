//
//  FinanceFilterView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import SwiftUI

struct FinanceFilterView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var service = FinanceService.shared
    
    // Фильтры
    @State private var selectedTypes: Set<FinanceType> = [.income, .expense]
    @State private var selectedCategories: Set<String> = []
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var minAmount: String = ""
    @State private var maxAmount: String = ""
    
    // Все доступные категории
    private var allCategories: [String] {
        service.getUniqueCategories()
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Тип транзакции
                Section(header: Text("Тип транзакции")) {
                    ForEach(FinanceType.allCases, id: \.self) { type in
                        Button {
                            toggleType(type)
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Категории
                Section(header: Text("Категории")) {
                    if allCategories.isEmpty {
                        Text("Нет доступных категорий")
                            .foregroundColor(.gray)
                    } else {
                        Button {
                            if selectedCategories.count == allCategories.count {
                                selectedCategories.removeAll()
                            } else {
                                selectedCategories = Set(allCategories)
                            }
                        } label: {
                            HStack {
                                Text("Выбрать все")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedCategories.count == allCategories.count && !allCategories.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        ForEach(allCategories, id: \.self) { category in
                            Button {
                                toggleCategory(category)
                            } label: {
                                HStack {
                                    Text(category)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCategories.contains(category) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Период
                Section(header: Text("Период")) {
                    DatePicker("С", selection: $startDate, displayedComponents: .date)
                    DatePicker("По", selection: $endDate, displayedComponents: .date)
                    
                    // Кнопки быстрого выбора периода
                    HStack {
                        Button("Неделя") { selectPeriod(.week) }
                            .buttonStyle(.bordered)
                        
                        Button("Месяц") { selectPeriod(.month) }
                            .buttonStyle(.bordered)
                        
                        Button("Квартал") { selectPeriod(.quarter) }
                            .buttonStyle(.bordered)
                        
                        Button("Год") { selectPeriod(.year) }
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 5)
                }
                
                // Сумма
                Section(header: Text("Сумма")) {
                    HStack {
                        Text("От")
                        TextField("Мин", text: $minAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("До")
                        TextField("Макс", text: $maxAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Кнопки действий
                Section {
                    Button("Применить фильтры") {
                        applyFilters()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                    
                    Button("Сбросить фильтры") {
                        resetFilters()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Фильтры")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                initializeFilters()
            }
        }
    }
    
    // MARK: - Вспомогательные методы
    
    // Инициализация фильтров текущими значениями
    private func initializeFilters() {
        selectedTypes = service.activeFilter?.types ?? [.income, .expense]
        selectedCategories = service.activeFilter?.categories ?? Set(allCategories)
        startDate = service.activeFilter?.startDate ?? Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        endDate = service.activeFilter?.endDate ?? Date()
        
        if let minAmount = service.activeFilter?.minAmount {
            self.minAmount = String(minAmount)
        }
        
        if let maxAmount = service.activeFilter?.maxAmount {
            self.maxAmount = String(maxAmount)
        }
    }
    
    // Применение фильтров
    private func applyFilters() {
        let filter = FinanceService.FinanceFilter(
            types: selectedTypes.isEmpty ? [.income, .expense] : selectedTypes,
            categories: selectedCategories.isEmpty ? Set(allCategories) : selectedCategories,
            startDate: startDate,
            endDate: endDate,
            minAmount: Double(minAmount),
            maxAmount: Double(maxAmount)
        )
        
        service.applyFilter(filter)
    }
    
    // Сброс фильтров
    private func resetFilters() {
        selectedTypes = [.income, .expense]
        selectedCategories = Set(allCategories)
        startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        endDate = Date()
        minAmount = ""
        maxAmount = ""
        
        service.clearFilters()
    }
    
    // Переключение типа в фильтре
    private func toggleType(_ type: FinanceType) {
        if selectedTypes.contains(type) {
            // Не позволяем отключить оба типа одновременно
            if selectedTypes.count > 1 {
                selectedTypes.remove(type)
            }
        } else {
            selectedTypes.insert(type)
        }
    }
    
    // Переключение категории в фильтре
    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    // Выбор предустановленного периода
    private func selectPeriod(_ period: ChartPeriod) {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        endDate = now
    }
}

// Перечисление для предопределенных периодов
enum ChartPeriod {
    case week
    case month
    case quarter
    case year
}