import SwiftUI
import PhotosUI

struct AddMerchView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category: MerchCategory = .clothing
    @State private var subcategory: MerchSubcategory?
    @State private var stock = MerchSizeStock()
    @State private var selectedImage: PhotosPickerItem?
    @State private var merchImage: UIImage?
    @State private var isUploading = false


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

                TextField("Название", text: $name)
                TextField("Описание", text: $description)
                TextField("Цена", text: $price)
                    .keyboardType(.decimalPad)

                // Категория и подкатегория
                Picker("Категория", selection: $category) {
                    ForEach(MerchCategory.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .onChange(of: category) { _ in
                    // Сбрасываем подкатегорию при смене категории
                    subcategory = nil
                }

                // Динамический выбор подкатегории
                Picker("Подкатегория", selection: $subcategory) {
                    Text("Не выбрано").tag(Optional<MerchSubcategory>.none)
                    ForEach(MerchSubcategory.subcategories(for: category), id: \.self) {
                        Text($0.rawValue).tag(Optional<MerchSubcategory>.some($0))
                    }
                }

                Section(header: Text("Остатки по размерам")) {
                    Stepper("S: \(stock.S)", value: $stock.S, in: 0...999)
                    Stepper("M: \(stock.M)", value: $stock.M, in: 0...999)
                    Stepper("L: \(stock.L)", value: $stock.L, in: 0...999)
                    Stepper("XL: \(stock.XL)", value: $stock.XL, in: 0...999)
                    Stepper("XXL: \(stock.XXL)", value: $stock.XXL, in: 0...999)
                }
            }
            .navigationTitle("Добавить товар")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveItem()
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
                        ProgressView("Загрузка...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
    }

    // Проверка валидности формы
    private var isFormValid: Bool {
        !name.isEmpty &&
        !price.isEmpty &&
        Double(price) != nil &&
        (price as NSString).doubleValue > 0
    }

    // Сохранение товара
    private func saveItem() {
        guard let priceValue = Double(price),
              let groupId = AppState.shared.user?.groupId else { return }

        isUploading = true

        // Создаем базовый объект товара
        let baseItem = MerchItem(
            name: name,
            description: description,
            price: priceValue,
            category: category,
            subcategory: subcategory,
            stock: stock,
            groupId: groupId
        )

        // Если есть изображение, загружаем его
        if let merchImage = merchImage {
            MerchImageManager.shared.uploadImage(merchImage, for: baseItem) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        // Создаем товар с URL изображения
                        var item = baseItem
                        item.imageURL = url.absoluteString

                        MerchService.shared.addItem(item) { success in
                            self.isUploading = false
                            if success {
                                self.dismiss()
                            }
                        }
                    case .failure(let error):
                        print("Ошибка загрузки изображения: \(error)")
                        self.isUploading = false
                    }
                }
            }
        } else {
            // Создаем товар без изображения
            MerchService.shared.addItem(baseItem) { success in
                self.isUploading = false
                if success {
                    self.dismiss()
                }
            }
        }
    }
}
