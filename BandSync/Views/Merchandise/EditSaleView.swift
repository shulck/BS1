import SwiftUI

struct EditSaleView: View {
    @Environment(\.dismiss) var dismiss
    let sale: MerchSale
    let item: MerchItem

    @State private var size: String
    @State private var quantity: Int
    @State private var channel: MerchSaleChannel
    @State private var isUpdating = false
    @State private var showDeleteConfirmation = false
    @State private var isGift: Bool

    init(sale: MerchSale, item: MerchItem) {
        self.sale = sale
        self.item = item
        _size = State(initialValue: sale.size)
        _quantity = State(initialValue: sale.quantity)
        _channel = State(initialValue: sale.channel)
        _isGift = State(initialValue: sale.channel == .gift)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о товаре")) {
                    HStack {
                        Text("Товар")
                        Spacer()
                        Text(item.name)
                            .foregroundColor(.secondary)
                    }

                    if let subcategory = item.subcategory {
                        HStack {
                            Text("Категория")
                            Spacer()
                            Text("\(item.category.rawValue) • \(subcategory.rawValue)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Категория")
                            Spacer()
                            Text(item.category.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Цена")
                        Spacer()
                        Text("\(Int(item.price)) EUR")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Дата продажи")
                        Spacer()
                        Text(formattedDate)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Детали продажи")) {
                    if item.category == .clothing {
                        Picker("Размер", selection: $size) {
                            ForEach(["S", "M", "L", "XL", "XXL"], id: \.self) { size in
                                Text(size)
                            }
                        }
                    }

                    Stepper("Количество: \(quantity)", value: $quantity, in: 1...999)

                    Toggle("Это подарок", isOn: $isGift)
                        .onChange(of: isGift) { newValue in
                            if newValue {
                                channel = .gift
                            } else if channel == .gift {
                                channel = .concert
                            }
                        }

                    if !isGift {
                        Picker("Канал продаж", selection: $channel) {
                            ForEach(MerchSaleChannel.allCases.filter { $0 != .gift }) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                    }

                    HStack {
                        Text("Итого")
                        Spacer()
                        if isGift {
                            Text("Подарок")
                                .bold()
                                .foregroundColor(.green)
                        } else {
                            Text("\(totalAmount, specifier: "%.2f") EUR")
                                .bold()
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Удалить продажу")
                            Spacer()
                        }
                    }
                }
            }
            .alert("Удалить продажу?", isPresented: $showDeleteConfirmation) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    deleteSale()
                }
            }
            .navigationTitle("Редактировать продажу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        updateSale()
                    }
                    .disabled(isUpdating || !isChanged)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .overlay(
                Group {
                    if isUpdating {
                        ProgressView("Обновление...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: sale.date)
    }

    private var totalAmount: Double {
        return Double(quantity) * item.price
    }

    private var isChanged: Bool {
        return size != sale.size ||
               quantity != sale.quantity ||
               channel != sale.channel
    }

    private func updateSale() {
        isUpdating = true

        // Сначала отменим старую продажу
        MerchService.shared.cancelSale(sale, item: item) { success in
            if success {
                // Затем создадим новую с обновленными данными
                // Если это подарок, принудительно устанавливаем канал gift
                let finalChannel = isGift ? MerchSaleChannel.gift : channel
                MerchService.shared.recordSale(item: item, size: size, quantity: quantity, channel: finalChannel)
                isUpdating = false
                dismiss()
            } else {
                isUpdating = false
                // Тут можно добавить оповещение об ошибке
            }
        }
    }

    private func deleteSale() {
        isUpdating = true
        MerchService.shared.cancelSale(sale, item: item) { success in
            isUpdating = false
            if success {
                dismiss()
            }
        }
    }
}
