//
//  AddMerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import PhotosUI

struct AddMerchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var imageManager = MerchImageManager()
    
    // Основные данные товара
    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var selectedCategory: MerchCategory = .clothing
    @State private var selectedSubcategory: MerchSubcategory = .tshirt
    @State private var stock = MerchSizeStock(S: 0, M: 0, L: 0, XL: 0, XXL: 0)
    @State private var lowStockThreshold = "5"
    
    // Управление изображениями
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    // Состояние формы
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentTab = 0
    
    // Вкладки формы
    private let tabs = ["Основное", "Изображения", "Запасы", "Дополнительно"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Переключатель вкладок
                TabSelector(tabs: tabs, selection: $currentTab)
                    .padding(.top)
                
                // Содержимое в зависимости от вкладки
                TabView(selection: $currentTab) {
                    basicInfoTab.tag(0)
                    imagesTab.tag(1)
                    stockTab.tag(2)
                    additionalTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Кнопки навигации по вкладкам
                HStack {
                    if currentTab > 0 {
                        Button("Назад") {
                            withAnimation {
                                currentTab -= 1
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if currentTab < tabs.count - 1 {
                        Button("Далее") {
                            withAnimation {
                                currentTab += 1
                            }
                        }
                    } else {
                        Button("Сохранить") {
                            saveItem()
                        }
                        .disabled(name.isEmpty || price.isEmpty || isLoading)
                        .foregroundColor(name.isEmpty || price.isEmpty ? .gray : .blue)
                    }
                }
                .padding()
            }
            .navigationTitle("Новый товар")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
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
            .onChange(of: selectedCategory) { newCategory in
                // При смене категории выбираем первую подходящую подкатегорию
                selectedSubcategory = newCategory.getSubcategories().first ?? .other
            }
            .onChange(of: selectedItems) { newItems in
                // Обработка выбранных изображений
                loadImages(from: newItems)
            }
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Ошибка"),
                    message: Text(errorMessage ?? "Неизвестная ошибка"),
                    dismissButton: .default(Text("ОК"))
                )
            }
        }
    }
    
    // MARK: - Вкладка "Основное"
    
    private var basicInfoTab: some View {
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
        }
    }
    
    // MARK: - Вкладка "Изображения"
    
    private var imagesTab: some View {
        VStack {
            if selectedImages.isEmpty {
                Text("Добавьте изображения товара")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            VStack {
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                                
                                Button(action: {
                                    selectedImages.remove(at: index)
                                    selectedItems.remove(at: index)
                                }) {
                                    Text("Удалить")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 5)
                        }
                    }
                    .padding()
                }
            }
            
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Label("Выбрать изображения", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
            }
            
            Text("Максимум 5 изображений")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Вкладка "Запасы"
    
    private var stockTab: some View {
        Form {
            Section(header: Text("Запасы по размерам")) {
                stepper(label: "S", value: $stock.S)
                stepper(label: "M", value: $stock.M)
                stepper(label: "L", value: $stock.L)
                stepper(label: "XL", value: $stock.XL)
                stepper(label: "XXL", value: $stock.XXL)
            }
            
            Section(header: Text("Всего")) {
                Text("Общее количество: \(stock.S + stock.M + stock.L + stock.XL + stock.XXL)")
                    .font(.headline)
            }
        }
    }
    
    // MARK: - Вкладка "Дополнительно"
    
    private var additionalTab: some View {
        Form {
            Section(header: Text("Настройки предупреждений")) {
                TextField("Порог низкого запаса", text: $lowStockThreshold)
                    .keyboardType(.numberPad)
                
                Text("Уведомление будет показано, когда количество товара опустится ниже указанного порога")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("Предварительный просмотр")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(name.isEmpty ? "Название товара" : name)
                            .font(.headline)
                        
                        HStack {
                            Label(selectedCategory.rawValue, systemImage: selectedCategory.icon)
                                .font(.caption)
                            
                            Text("•")
                            
                            Label(selectedSubcategory.rawValue, systemImage: selectedSubcategory.icon)
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                        
                        if !price.isEmpty, let priceValue = Double(price) {
                            Text("\(Int(priceValue)) EUR")
                                .font(.title3)
                                .bold()
                        }
                    }
                    
                    Spacer()
                    
                    if !selectedImages.isEmpty {
                        Image(uiImage: selectedImages[0])
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(5)
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    // MARK: - Вспомогательные функции
    
    private func stepper(label: String, value: Binding<Int>) -> some View {
        Stepper("\(label): \(value.wrappedValue)", value: value, in: 0...999)
    }
    
    private func loadImages(from items: [PhotosPickerItem]) {
        selectedImages = []
        
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.selectedImages.append(image)
                        }
                    }
                case .failure(let error):
                    print("Ошибка загрузки изображения: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveItem() {
        guard let priceValue = Double(price) else {
            errorMessage = "Укажите корректную цену"
            return
        }
        
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "Не удалось определить группу"
            return
        }
        
        isLoading = true
        
        // Создаем новый товар
        let threshold = Int(lowStockThreshold) ?? 5
        
        let newItem = MerchItem(
            name: name,
            description: description,
            price: priceValue,
            category: selectedCategory,
            subcategory: selectedSubcategory,
            stock: stock,
            lowStockThreshold: threshold,
            groupId: groupId
        )
        
        // Если есть изображения, сначала загружаем их
        if !selectedImages.isEmpty {
            imageManager.uploadImages(selectedImages) { result in
                switch result {
                case .success(let urls):
                    var itemWithImages = newItem
                    itemWithImages.imageUrls = urls
                    
                    // Сохраняем товар с URLs изображений
                    saveItemToFirestore(itemWithImages)
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "Ошибка загрузки изображений: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // Если изображений нет, просто сохраняем товар
            saveItemToFirestore(newItem)
        }
    }
    
    private func saveItemToFirestore(_ item: MerchItem) {
        MerchService.shared.addItem(item) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = "Не удалось сохранить товар"
                }
            }
        }
    }
}

// MARK: - Вспомогательные компоненты

struct TabSelector: View {
    let tabs: [String]
    @Binding var selection: Int
    
    var body: some View {
        HStack {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation {
                        selection = index
                    }
                }) {
                    VStack {
                        Text(tabs[index])
                            .fontWeight(selection == index ? .bold : .regular)
                            .foregroundColor(selection == index ? .blue : .gray)
                        
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selection == index ? .blue : .clear)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Менеджер изображений для мерча

class MerchImageManager: ObservableObject {
    // В реальном приложении здесь будет код для загрузки изображений в Firebase Storage
    // Для примера просто имитируем загрузку с задержкой
    
    func uploadImages(_ images: [UIImage], completion: @escaping (Result<[String], Error>) -> Void) {
        // Имитация загрузки с задержкой
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            // Генерируем случайные URL для примера
            let urls = images.map { _ in "https://example.com/images/\(UUID().uuidString).jpg" }
            completion(.success(urls))
        }
    }
}
