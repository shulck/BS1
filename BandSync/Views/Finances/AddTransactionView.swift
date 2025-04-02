import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var type: FinanceType = .expense
    @State private var category: FinanceCategory = .logistics
    @State private var amount: String = ""
    @State private var currency: String = "EUR"
    @State private var details: String = ""
    @State private var date = Date()
    
    // Новые состояния для сканера чеков
    @State private var showReceiptScanner = false
    @State private var scannedText = ""
    @State private var extractedFinanceRecord: FinanceRecord?
    
    var body: some View {
        NavigationView {
            Form {
                // Переключатель типа операции
                Picker("Тип", selection: $type) {
                    Text("Доход").tag(FinanceType.income)
                    Text("Расход").tag(FinanceType.expense)
                }
                .pickerStyle(.segmented)
                .onChange(of: type) { newType in
                    // Сбрасываем категорию при смене типа
                    category = FinanceCategory.forType(newType).first ?? .logistics
                }
                
                // Picker категорий
                Picker("Категория", selection: $category) {
                    ForEach(FinanceCategory.forType(type)) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                
                // Поля для ввода
                TextField("Сумма", text: $amount)
                    .keyboardType(.decimalPad)
                
                TextField("Валюта", text: $currency)
                    .autocapitalization(.allCharacters)
                
                TextField("Описание", text: $details)
                
                DatePicker("Дата", selection: $date, displayedComponents: [.date])
                
                // Кнопка сканирования чека
                Section {
                    Button(action: {
                        showReceiptScanner = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Сканировать чек")
                        }
                    }
                }
                
                // Отображение распознанного текста
                if !scannedText.isEmpty {
                    Section(header: Text("Текст чека")) {
                        Text(scannedText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Если есть распознанная финансовая запись
                if let record = extractedFinanceRecord {
                    Section(header: Text("Распознанные данные")) {
                        HStack {
                            Text("Сумма:")
                            Spacer()
                            Text("\(Int(record.amount)) \(record.currency)")
                                .foregroundColor(record.type == .income ? .green : .red)
                        }
                        
                        HStack {
                            Text("Категория:")
                            Spacer()
                            Text(record.category)
                        }
                        
                        HStack {
                            Text("Дата:")
                            Spacer()
                            Text(formattedDate(record.date))
                        }
                    }
                }
            }
            .navigationTitle("Новая запись")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveRecord()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerView(
                    recognizedText: $scannedText,
                    extractedFinanceRecord: $extractedFinanceRecord
                )
            }
        }
    }
    
    private func saveRecord() {
        // Приоритет отдаетсяручному вводу, затем распознанным данным
        guard let groupId = AppState.shared.user?.groupId else { return }
        
        let recordToSave: FinanceRecord
        
        if let amountValue = Double(amount), !amount.isEmpty {
            // Приоритет ручному вводу
            recordToSave = FinanceRecord(
                type: type,
                amount: amountValue,
                currency: currency.uppercased(),
                category: category.rawValue,
                details: details,
                date: date,
                receiptUrl: nil,
                groupId: groupId
            )
        } else if let extractedRecord = extractedFinanceRecord {
            // Используем распознанную запись
            recordToSave = extractedRecord
        } else {
            // Недостаточно данных
            return
        }
        
        guard FinanceValidator.isValid(record: recordToSave) else { return }
        
        FinanceService.shared.add(recordToSave) { success in
            if success {
                dismiss()
            }
        }
    }
    
    // Вспомогательный метод форматирования даты
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
