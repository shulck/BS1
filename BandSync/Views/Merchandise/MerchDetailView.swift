import SwiftUI
import UIKit

struct MerchDetailView: View {
    let item: MerchItem
    @State private var showSell = false
    @State private var merchImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSalesHistory = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Изображение товара
                imageSection

                // Основная информация
                detailsSection

                // Остатки по размерам
                stockSection

                // Добавляем кнопку истории продаж
                Button("История продаж") {
                    showSalesHistory = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(10)

                // Кнопка продажи
                sellButton
            }
            .padding()
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if AppState.shared.hasEditPermission(for: .merchandise) {
                        Menu {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showSell) {
            SellMerchView(item: item)
        }
        .sheet(isPresented: $showEditSheet) {
            EditMerchView(item: item)
        }
        .sheet(isPresented: $showSalesHistory) {
            SalesHistoryView(item: item)
        }
        .alert("Удалить товар?", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Вы уверены, что хотите удалить товар '\(item.name)'? Это действие нельзя отменить.")
        }
    }

    // Секция с изображением
    private var imageSection: some View {
        Group {
            if isLoadingImage {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else if let merchImage = merchImage {
                Image(uiImage: merchImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 250)
                    .cornerRadius(12)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 250)
            }
        }
    }

    // Секция с основными деталями
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.description)
                .font(.body)

            HStack {
                Text("Категория:")
                Spacer()
                Text(item.category.rawValue)
            }

            if let subcategory = item.subcategory {
                HStack {
                    Text("Подкатегория:")
                    Spacer()
                    Text(subcategory.rawValue)
                }
            }

            HStack {
                Text("Цена:")
                Spacer()
                Text("\(Int(item.price)) EUR")
                    .bold()
            }
        }
    }

    // Секция с остатками
    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.category == .clothing {
                Text("Остатки по размерам")
                    .font(.headline)

                HStack {
                    Text("S:")
                    Spacer()
                    Text("\(item.stock.S)")
                }
                HStack {
                    Text("M:")
                    Spacer()
                    Text("\(item.stock.M)")
                }
                HStack {
                    Text("L:")
                    Spacer()
                    Text("\(item.stock.L)")
                }
                HStack {
                    Text("XL:")
                    Spacer()
                    Text("\(item.stock.XL)")
                }
                HStack {
                    Text("XXL:")
                    Spacer()
                    Text("\(item.stock.XXL)")
                }
            } else {
                Text("Количество:")
                    .font(.headline)
                Text("\(item.totalStock)")
                    .font(.title3)
            }
        }
    }

    // Кнопка продажи
    private var sellButton: some View {
        Button("Продать товар") {
            showSell = true
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
    }

    // Загрузка изображения
    private func loadImage() {
        guard let imageURLString = item.imageURL else { return }

        isLoadingImage = true
        MerchImageManager.shared.downloadImage(from: imageURLString) { image in
            DispatchQueue.main.async {
                self.merchImage = image
                self.isLoadingImage = false
            }
        }
    }

    // Удаление товара
    private func deleteItem() {
        MerchService.shared.deleteItem(item) { success in
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
