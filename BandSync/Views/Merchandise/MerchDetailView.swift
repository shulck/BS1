//
//  MerchDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI

struct MerchDetailView: View {
    @StateObject private var merchService = MerchService.shared
    @State private var item: MerchItem
    @State private var showSell = false
    @State private var showEdit = false
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var currentImageIndex = 0
    @Environment(\.dismiss) var dismiss
    
    init(item: MerchItem) {
        self._item = State(initialValue: item)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Изображения товара
                imageGallerySection
                
                // Заголовок и основная информация
                infoSection
                
                Divider()
                
                // Индикатор запасов
                stockSection
                
                Divider()
                
                // Подробное описание
                if !item.description.isEmpty {
                    descriptionSection
                    
                    Divider()
                }
                
                // Кнопки действий
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle(item.name)
        .toolbar {
            toolbarItems
        }
        .sheet(isPresented: $showSell) {
            SellMerchView(item: item)
        }
        .sheet(isPresented: $showEdit) {
            EditMerchView(item: item) { updatedItem in
                item = updatedItem
            }
        }
        .overlay(Group {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        })
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Информация"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Разделы интерфейса
    
    private var imageGallerySection: some View {
        VStack(alignment: .center) {
            if let imageUrls = item.imageUrls, !imageUrls.isEmpty {
                // Карусель с изображениями
                TabView(selection: $currentImageIndex) {
                    ForEach(0..<imageUrls.count, id: \.self) { index in
                        if let url = URL(string: imageUrls[index]) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 250)
                
                // Индикатор текущего изображения
                if imageUrls.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<imageUrls.count, id: \.self) { index in
                            Circle()
                                .fill(currentImageIndex == index ? Color.blue : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                // Заглушка если нет изображений
                Image(systemName: item.category.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.title2)
                .bold()
            
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Label(item.category.rawValue, systemImage: item.category.icon)
                            .font(.subheadline)
                        
                        Text("•")
                        
                        Label(item.subcategory.rawValue, systemImage: item.subcategory.icon)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(item.price)) EUR")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Наличие")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Прогресс-бар для каждого размера
            ForEach(["S", "M", "L", "XL", "XXL"], id: \.self) { size in
                stockProgressBar(for: size)
            }
            
            // Предупреждение о низком запасе
            if item.hasLowStock {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Низкий запас! Порог: \(item.lowStockThreshold)")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text(item.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                showSell = true
            } label: {
                Label("Продать товар", systemImage: "cart")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button {
                checkAnalytics()
            } label: {
                Label("Посмотреть аналитику", systemImage: "chart.bar")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Элементы интерфейса
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if AppState.shared.hasEditPermission(for: .merchandise) {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Редактировать", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        deleteItem()
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
                
                Button {
                    shareItem()
                } label: {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                }
                
                if item.hasLowStock {
                    Divider()
                    
                    Button {
                        reorderItem()
                    } label: {
                        Label("Заказать ещё", systemImage: "plus.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    private func stockProgressBar(for size: String) -> some View {
        let value: Int
        let total = getTotalStockAndSales(for: size)
        
        switch size {
        case "S": value = item.stock.S
        case "M": value = item.stock.M
        case "L": value = item.stock.L
        case "XL": value = item.stock.XL
        case "XXL": value = item.stock.XXL
        default: value = 0
        }
        
        let percentage = total > 0 ? Double(value) / Double(total) : 0
        let color: Color
        
        if value <= item.lowStockThreshold {
            color = .orange
        } else if value > 0 {
            color = .green
        } else {
            color = .gray
        }
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(size)
                    .font(.subheadline)
                    .frame(width: 30)
                
                Text("\(value) шт.")
                    .font(.subheadline)
                    .frame(minWidth: 60, alignment: .leading)
                
                if total > 0 {
                    Text("из \(total)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if value <= item.lowStockThreshold && value > 0 {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                } else if value == 0 {
                    Text("Нет в наличии")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .background(Color.gray.opacity(0.2))
                .cornerRadius(2)
        }
    }
    
    // MARK: - Вспомогательные методы
    
    private func getTotalStockAndSales(for size: String) -> Int {
        // Получаем текущий запас
        let currentStock: Int
        switch size {
        case "S": currentStock = item.stock.S
        case "M": currentStock = item.stock.M
        case "L": currentStock = item.stock.L
        case "XL": currentStock = item.stock.XL
        case "XXL": currentStock = item.stock.XXL
        default: currentStock = 0
        }
        
        // Получаем количество проданных единиц
        let soldQuantity = merchService.sales
            .filter { $0.itemId == item.id && $0.size == size }
            .reduce(0) { $0 + $1.quantity }
        
        return currentStock + soldQuantity
    }
    
    private func deleteItem() {
        isLoading = true
        
        merchService.deleteItem(item) { success in
            isLoading = false
            
            if success {
                dismiss()
            } else {
                alertMessage = "Не удалось удалить товар"
                showingAlert = true
            }
        }
    }
    
    private func shareItem() {
        // Создаем текст для шаринга
        var shareText = "\(item.name) - \(Int(item.price)) EUR\n"
        shareText += "Категория: \(item.category.rawValue) / \(item.subcategory.rawValue)\n\n"
        
        if !item.description.isEmpty {
            shareText += "\(item.description)\n\n"
        }
        
        // Формируем текст о наличии
        shareText += "Наличие: "
        var sizes: [String] = []
        
        if item.stock.S > 0 { sizes.append("S: \(item.stock.S)") }
        if item.stock.M > 0 { sizes.append("M: \(item.stock.M)") }
        if item.stock.L > 0 { sizes.append("L: \(item.stock.L)") }
        if item.stock.XL > 0 { sizes.append("XL: \(item.stock.XL)") }
        if item.stock.XXL > 0 { sizes.append("XXL: \(item.stock.XXL)") }
        
        if sizes.isEmpty {
            shareText += "Нет в наличии"
        } else {
            shareText += sizes.joined(separator: ", ")
        }
        
        // Вызываем системный шаринг
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Находим последний представленный контроллер
            var currentVC = rootVC
            while let presentedVC = currentVC.presentedViewController {
                currentVC = presentedVC
            }
            
            currentVC.present(activityVC, animated: true)
        }
    }
    
    private func reorderItem() {
        // Здесь была бы реальная логика оформления заказа на пополнение товара
        
        alertMessage = "Функция заказа товара будет доступна в следующем обновлении"
        showingAlert = true
    }
    
    private func checkAnalytics() {
        // В реальном приложении здесь был бы переход к детальной аналитике товара
        
        let totalSold = merchService.sales
            .filter { $0.itemId == item.id }
            .reduce(0) { $0 + $1.quantity }
        
        let revenue = totalSold * Int(item.price)
        
        alertMessage = "Продано: \(totalSold) шт.\nВыручка: \(revenue) EUR\n\nДетальная аналитика будет доступна в следующем обновлении"
        showingAlert = true
    }
}

// MARK: - Представление для редактирования товара

struct EditMerchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var imageManager = MerchImageManager()
    
    let item: MerchItem
    let onUpdate: (MerchItem) -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var price: String
    @State private var selectedCategory: MerchCategory
    @State private var selectedSubcategory: MerchSubcategory
    @State private var stock: MerchSizeStock
    @State private var lowStockThreshold: String
    @State private var imageUrls: [String]
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(item: MerchItem, onUpdate: @escaping (MerchItem) -> Void) {
        self.item = item
        self.onUpdate = onUpdate
        
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _price = State(initialValue: String(Int(item.price)))
        _selectedCategory = State(initialValue: item.category)
        _selectedSubcategory = State(initialValue: item.subcategory)
        _stock = State(initialValue: item.stock)
        _lowStockThreshold = State(initialValue: String(item.lowStockThreshold))
        _imageUrls = State(initialValue: item.imageUrls ?? [])
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о товаре")) {
                    TextField("Название", text: $name)
                    
                    TextField("Цена", text: $price)
                        .keyboardType(.decimalPad)
                    
                    Picker("Категория", selection: $selectedCategory) {
                        ForEach(MerchCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    Picker("Подкатегория", selection: $selectedSubcategory) {
                        ForEach(selectedCategory.getSubcategories()) { subcategory in
                            Label(subcategory.rawValue, systemImage: subcategory.icon)
                                .tag(subcategory)
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Описание товара...")
                                .foregroundColor(Color.gray.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    }
                }
                
                Section(header: Text("Запасы по размерам")) {
                    Stepper("S: \(stock.S)", value: $stock.S, in: 0...999)
                    Stepper("M: \(stock.M)", value: $stock.M, in: 0...999)
                    Stepper("L: \(stock.L)", value: $stock.L, in: 0...999)
                    Stepper("XL: \(stock.XL)", value: $stock.XL, in: 0...999)
                    Stepper("XXL: \(stock.XXL)", value: $stock.XXL, in: 0...999)
                }
                
                Section(header: Text("Настройки предупреждений")) {
                    TextField("Порог низкого запаса", text: $lowStockThreshold)
                        .keyboardType(.numberPad)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Редактирование товара")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty || price.isEmpty || isLoading)
                }
            }
            .onChange(of: selectedCategory) { newCategory in
                // Если меняем категорию, обновляем подкатегорию
                if !newCategory.getSubcategories().contains(selectedSubcategory) {
                    selectedSubcategory = newCategory.getSubcategories().first ?? .other
                }
            }
            .overlay(Group {
                if isLoading {
                    ProgressView("Сохранение...")
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            })
        }
    }
    
    private func saveChanges() {
        guard let priceValue = Double(price) else {
            errorMessage = "Введите корректную цену"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Создаем обновленный товар
        var updatedItem = item
        updatedItem.name = name
        updatedItem.description = description
        updatedItem.price = priceValue
        updatedItem.category = selectedCategory
        updatedItem.subcategory = selectedSubcategory
        updatedItem.stock = stock
        updatedItem.lowStockThreshold = Int(lowStockThreshold) ?? 5
        
        MerchService.shared.updateItem(updatedItem) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    onUpdate(updatedItem)
                    dismiss()
                } else {
                    errorMessage = "Не удалось обновить товар"
                }
            }
        }
    }
}
