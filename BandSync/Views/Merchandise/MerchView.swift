//
//  MerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI

struct MerchView: View {
    @StateObject private var merchService = MerchService.shared
    @State private var showAdd = false
    @State private var showAnalytics = false
    @State private var selectedCategory: MerchCategory? = nil
    @State private var searchText = ""
    @State private var showLowStockAlert = false
    
    // Фильтрованные товары с учетом поиска и категорий
    private var filteredItems: [MerchItem] {
        var items = merchService.items
        
        // Фильтрация по категории
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        
        // Фильтрация по поисковому запросу
        if !searchText.isEmpty {
            items = items.filter { item in
                item.name.lowercased().contains(searchText.lowercased()) ||
                item.description.lowercased().contains(searchText.lowercased()) ||
                item.category.rawValue.lowercased().contains(searchText.lowercased()) ||
                item.subcategory.rawValue.lowercased().contains(searchText.lowercased())
            }
        }
        
        return items
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Категории товаров
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        categoryButton(title: "Все", icon: "tshirt.fill", category: nil)
                        
                        ForEach(MerchCategory.allCases) { category in
                            categoryButton(
                                title: category.rawValue,
                                icon: category.icon,
                                category: category
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.1))
                
                // Счетчик товаров и низкого запаса
                HStack {
                    VStack(alignment: .leading) {
                        Text("Товаров")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(filteredItems.count)")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    if !merchService.lowStockItems.isEmpty {
                        // Информация о товарах с низким запасом
                        Button {
                            showLowStockItems()
                        } label: {
                            HStack {
                                VStack(alignment: .trailing) {
                                    Text("Низкий запас")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("\(merchService.lowStockItems.count)")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                        }
                    } else {
                        // Информация о нормальном запасе
                        HStack {
                            VStack(alignment: .trailing) {
                                Text("Запас в норме")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("\(merchService.items.count)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if merchService.isLoading {
                    // Индикатор загрузки
                    ProgressView()
                        .padding()
                } else if filteredItems.isEmpty {
                    // Состояние пустого списка
                    VStack(spacing: 20) {
                        Image(systemName: "bag")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text(searchText.isEmpty
                            ? "Нет товаров в выбранной категории"
                            : "Нет товаров по запросу '\(searchText)'")
                        .foregroundColor(.gray)
                        
                        if AppState.shared.hasEditPermission(for: .merchandise) {
                            Button("Добавить товар") {
                                showAdd = true
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Список товаров
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: MerchDetailView(item: item)) {
                                MerchItemRow(item: item)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Мерч")
            .searchable(text: $searchText, prompt: "Поиск по товарам")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if AppState.shared.hasEditPermission(for: .merchandise) {
                            Button {
                                showAdd = true
                            } label: {
                                Label("Добавить товар", systemImage: "plus")
                            }
                        }
                        
                        Button {
                            showAnalytics = true
                        } label: {
                            Label("Аналитика продаж", systemImage: "chart.bar")
                        }
                        
                        if !merchService.lowStockItems.isEmpty {
                            Button {
                                showLowStockItems()
                            } label: {
                                Label("Показать товары с низким запасом", systemImage: "exclamationmark.triangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    merchService.fetchItems(for: groupId)
                    merchService.fetchSales(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddMerchView()
            }
            .sheet(isPresented: $showAnalytics) {
                MerchSalesAnalyticsView()
            }
            .alert("Товары с низким запасом", isPresented: $showLowStockAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("В приложении \(merchService.lowStockItems.count) товаров с запасом ниже порогового значения.")
            }
        }
    }
    
    // Кнопка категории
    private func categoryButton(title: String, icon: String, category: MerchCategory?) -> some View {
        Button {
            withAnimation {
                selectedCategory = category
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
    }
    
    // Показать список товаров с низким запасом
    private func showLowStockItems() {
        // Создаем временный список для сравнения
        let lowStockItemIds = Set(merchService.lowStockItems.compactMap { $0.id })
        
        // Определяем товары с низким запасом из текущего списка
        let lowStockItemsInCurrentView = filteredItems.filter { item in
            if let id = item.id {
                return lowStockItemIds.contains(id)
            }
            return false
        }
        
        // Если нет товаров с низким запасом в текущем представлении,
        // покажем отдельный алерт с информацией
        if lowStockItemsInCurrentView.isEmpty {
            showLowStockAlert = true
        } else {
            // Иначе сбрасываем фильтры и задаем новый поиск для отображения только товаров с низким запасом
            selectedCategory = nil
            searchText = "low_stock_filter"
            
            // Задержка для применения фильтров
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.searchText = ""  // Сбрасываем поисковый запрос
            }
        }
    }
}

// MARK: - Структура для строки товара

struct MerchItemRow: View {
    let item: MerchItem
    
    var body: some View {
        HStack {
            // Изображение товара или иконка категории
            if let firstImageUrl = item.imageUrls?.first,
               let url = URL(string: firstImageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if phase.error != nil {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                }
            } else {
                Image(systemName: item.category.icon)
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Информация о товаре
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                    
                    if item.hasLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                Text("\(item.category.rawValue) • \(item.subcategory.rawValue)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Индикатор запасов
                HStack(spacing: 5) {
                    Text("Запасы:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    sizeIndicator("S", quantity: item.stock.S, lowThreshold: item.lowStockThreshold)
                    sizeIndicator("M", quantity: item.stock.M, lowThreshold: item.lowStockThreshold)
                    sizeIndicator("L", quantity: item.stock.L, lowThreshold: item.lowStockThreshold)
                    sizeIndicator("XL", quantity: item.stock.XL, lowThreshold: item.lowStockThreshold)
                    sizeIndicator("XXL", quantity: item.stock.XXL, lowThreshold: item.lowStockThreshold)
                }
            }
            
            Spacer()
            
            // Цена
            VStack(alignment: .trailing) {
                Text("\(Int(item.price)) EUR")
                    .font(.headline)
                    .bold()
                
                Text("Всего: \(item.totalStock)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Индикатор наличия размера
    private func sizeIndicator(_ size: String, quantity: Int, lowThreshold: Int) -> some View {
        Text(size)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                quantity == 0 ? Color.gray.opacity(0.3) :
                    quantity <= lowThreshold ? Color.orange.opacity(0.3) :
                        Color.green.opacity(0.3)
            )
            .foregroundColor(
                quantity == 0 ? .gray :
                    quantity <= lowThreshold ? .orange :
                        .green
            )
            .cornerRadius(3)
    }
}
