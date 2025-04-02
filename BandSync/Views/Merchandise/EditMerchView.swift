import SwiftUI
import PhotosUI

struct EditMerchView: View {
    @Environment(\.dismiss) var dismiss
    let item: MerchItem

    @State private var name: String
    @State private var description: String
    @State private var price: String
    @State private var category: MerchCategory
    @State private var subcategory: MerchSubcategory?
    @State private var stock: MerchSizeStock
    @State private var selectedImage: PhotosPickerItem?
    @State private var merchImage: UIImage?
    @State private var isUploading = false
    @State private var lowStockThreshold: String

    init(item: MerchItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _price = State(initialValue: String(item.price))
        _category = State(initialValue: item.category)
        _subcategory = State(initialValue: item.subcategory)
        _stock = State(initialValue: item.stock)
        _lowStockThreshold = State(initialValue: String(item.lowStockThreshold))
    }

    var body: some View {
        NavigationView {
            Form {
                // Изображение товара
                Section(header: Text("Изображение")) {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        HStack {
                            if let merchImage = merchImage {
                                Image(uiImage: merchImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            } else if let imageURL = item.imageURL {
                                AsyncImage(url: URL(string: imageURL)) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 200)
                                            .cornerRadius(8)
                                    } else if phase.error != nil {
                                        Label("Ошибка загрузки изображения", systemImage: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                    } else {
                                        ProgressView()
                                    }
                                }
                            } else {
                                Label("Выбрать изображение", systemImage: "photo.on.rectangle")
                            }
                        }
                    }
                    .onChange(of: selectedImage) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                if let uiImage = UIImage(data: data) {
                                    merchImage = uiImage
                                }
                            }
                        }
                    }
                }

                // Основная информация
                Section(header: Text("Информация о товаре")) {
                    TextField("Название", text: $name)
                    TextField("Описание", text: $description)
                    TextField("Цена", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Порог низкого запаса", text: $lowStockThreshold)
                        .keyboardType(.numberPad)
                }

                // Категория и подкатегория
                Section(header: Text("Категория")) {
                    Picker("Категория", selection: $category) {
                        ForEach(MerchCategory.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .onChange(of: category) { newCategory in
                        // Если новая категория отличается от старой и подкатегория не принадлежит новой категории
                        if newCategory != item.category,
                           let currentSubcategory = subcategory,
                           !MerchSubcategory.subcategories(for: newCategory).contains(currentSubcategory) {
                            subcategory = nil
                        }
                    }

                    Picker("Подкатегория", selection: $subcategory) {
                        Text("Не выбрано").tag(Optional<MerchSubcategory>.none)
                        ForEach(MerchSubcategory.subcategories(for: category), id: \.self) {
                            Text($0.rawValue).tag(Optional<MerchSubcategory>.some($0))
                        }
                    }
                }

                // Остатки по размерам
                Section(header: Text("Остатки по размерам")) {
                    Stepper("S: \(stock.S)", value: $stock.S, in: 0...999)
                    Stepper("M: \(stock.M)", value: $stock.M, in: 0...999)
                    Stepper("L: \(stock.L)", value: $stock.L, in: 0...999)
                    Stepper("XL: \(stock.XL)", value: $stock.XL, in: 0...999)
                    Stepper("XXL: \(stock.XXL)", value: $stock.XXL, in: 0...999)
                }
            }
            .navigationTitle("Редактировать товар")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveChanges()
                    }
                    .disabled(isUploading || !isFormValid)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .overlay(
                Group {
                    if isUploading {
                        ProgressView("Сохранение...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
        .onAppear {
            loadImage()
        }
    }

    // Проверка валидности формы
    private var isFormValid: Bool {
        !name.isEmpty &&
        !price.isEmpty &&
        Double(price) != nil &&
        (price as NSString).doubleValue > 0 &&
        Int(lowStockThreshold) != nil &&
        (lowStockThreshold as NSString).integerValue >= 0
    }

    // Загрузка текущего изображения
    private func loadImage() {
        guard let imageURL = item.imageURL, let url = URL(string: imageURL) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.merchImage = image
                }
            }
        }.resume()
    }

    // Сохранение изменений
    private func saveChanges() {
        guard let priceValue = Double(price),
              let thresholdValue = Int(lowStockThreshold) else { return }

        isUploading = true

        // Создаем обновленный товар
        var updatedItem = item
        updatedItem.name = name
        updatedItem.description = description
        updatedItem.price = priceValue
        updatedItem.category = category
        updatedItem.subcategory = subcategory
        updatedItem.stock = stock
        updatedItem.lowStockThreshold = thresholdValue

        // Если выбрано новое изображение, загружаем его
        if let newImage = merchImage, selectedImage != nil {
            MerchImageManager.shared.uploadImage(newImage, for: updatedItem) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        updatedItem.imageURL = url.absoluteString
                        saveItemToDatabase(updatedItem)

                    case .failure(let error):
                        print("Ошибка загрузки изображения: \(error)")
                        isUploading = false
                    }
                }
            }
        } else {
            // Иначе сохраняем только данные
            saveItemToDatabase(updatedItem)
        }
    }

    private func saveItemToDatabase(_ item: MerchItem) {
        MerchService.shared.updateItem(item) { success in
            isUploading = false
            if success {
                dismiss()
            }
        }
    }
}
