import SwiftUI
import VisionKit
import Vision
import CoreML

struct ReceiptScannerView: View {
    @Binding var recognizedText: String
    @Binding var extractedFinanceRecord: FinanceRecord?
    @State private var isProcessing = false
    @State private var recognizedItems: [ReceiptItem] = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if isProcessing {
                    ProgressView("Распознавание чека...")
                        .padding()
                } else {
                    ScrollView {
                        // Распознанные позиции из чека
                        if !recognizedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Распознанные позиции")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(recognizedItems) { item in
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text("\(String(format: "%.2f", item.price)) \(item.currency)")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                }

                                Divider()

                                HStack {
                                    Text("Итого:")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(String(format: "%.2f", recognizedItems.reduce(0) { $0 + $1.price })) \(recognizedItems.first?.currency ?? "EUR")")
                                        .font(.headline)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .padding()
                        }

                        // Распознанный текст
                        if !recognizedText.isEmpty {
                            Text("Распознанный текст:")
                                .font(.headline)
                                .padding(.horizontal)

                            Text(recognizedText)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }

                    Spacer()

                    ReceiptScannerViewController(
                        recognizedText: $recognizedText,
                        extractedFinanceRecord: $extractedFinanceRecord,
                        isProcessing: $isProcessing,
                        recognizedItems: $recognizedItems
                    )
                    .frame(height: 100)

                    // Кнопка подтверждения распознанных данных
                    if extractedFinanceRecord != nil {
                        Button(action: { dismiss() }) {
                            Text("Использовать распознанные данные")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Сканирование чека")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Модель для хранения отдельных позиций чека
struct ReceiptItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let price: Double
    let currency: String

    // Добавляем соответствие протоколу Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(price)
        hasher.combine(currency)
    }

    static func == (lhs: ReceiptItem, rhs: ReceiptItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.price == rhs.price &&
               lhs.currency == rhs.currency
    }
}

struct ReceiptScannerViewController: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var extractedFinanceRecord: FinanceRecord?
    @Binding var isProcessing: Bool
    @Binding var recognizedItems: [ReceiptItem]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private var parent: ReceiptScannerViewController

        init(_ parent: ReceiptScannerViewController) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true)
                return
            }

            DispatchQueue.main.async {
                self.parent.isProcessing = true
            }

            let image = scan.imageOfPage(at: 0)
            processImage(image)
            controller.dismiss(animated: true)
        }

        private func processImage(_ image: UIImage) {
            guard let cgImage = image.cgImage else { return }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            let textRecognitionRequest = VNRecognizeTextRequest { [weak self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n")

                DispatchQueue.main.async {
                    self?.parent.recognizedText = fullText
                    self?.extractFinancialDetails(from: fullText, observations: observations)
                    self?.parent.isProcessing = false
                }
            }

            textRecognitionRequest.recognitionLevel = .accurate
            textRecognitionRequest.usesLanguageCorrection = true
            textRecognitionRequest.recognitionLanguages = ["ru_RU", "en_US"] // Поддержка русского и английского языков

            do {
                try requestHandler.perform([textRecognitionRequest])
            } catch {
                print("Ошибка распознавания текста: \(error)")
                DispatchQueue.main.async {
                    self.parent.isProcessing = false
                }
            }
        }

        private func extractFinancialDetails(from text: String, observations: [VNRecognizedTextObservation]) {
            // Исправленные регулярные выражения, заменяя кириллические символы на латинские
            let amountPatterns = [
                #"ИТОГО\s*[:;]?\s*(\d+[.,]?\д{0,2})"#,
                #"Итог\w*\с*[:;]?\с*(\д+[.,]?\д{0,2})"#,
                #"TOTAL\s*[:;]?\с*(\д+[.,]?\д{0,2})"#,
                #"СУММА\s*[:;]?\с*(\д+[.,]?\д{0,2})"#,
                #"К ОПЛАТЕ\s*[:;]?\с*(\д+[.,]?\д{0,2})"#,
                #"ВСЕГО\s*[:;]?\с*(\д+[.,]?\д{0,2})"#
            ]

            // Различные форматы дат: 01.01.2023, 01/01/2023, 01-01-2023
            let datePatterns = [
                #"(\д{1,2}[./]\д{1,2}[./]\д{2,4})"#,
                #"(\д{1,2}[-]\д{1,2}[-]\д{2,4})"#,
                #"Дата:?\с*(\д{1,2}[./]\д{1,2}[./]\д{2,4})"#,
                #"DATE:?\с*(\д{1,2}[./]\д{1,2}[./]\д{2,4})"#
            ]

            // Определение магазина/категории
            let storePatterns = [
                #"ООО\s+\"([^\"]+)\""#,
                #"ИП\s+([^\н]+)"#,
                #"МАГАЗИН\s+([^\н]+)"#,
                #"STORE\s+([^\н]+)"#
            ]

            // Попытка распознать отдельные позиции
            // Примеры форматов: "Хлеб 123.45" или "Молоко..........99.90"
            let itemPatterns = [
                #"([А-Яа-яA-Za-z\s]+)[\.\с]{2,}(\д+[.,]?\д{0,2})"#,
                #"([А-Яа-яA-Za-z\s]+)\с+(\д+[.,]?\д{0,2})\с+\в+"#
            ]

            // Определение валюты
            let currencyPatterns = [
                #"(EUR|USD|RUB|₽|€|\$)"#
            ]

            // Извлечение итоговой суммы
            var amount: Double?
            for pattern in amountPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[range]).replacingOccurrences(of: ",", with: ".")
                    amount = Double(amountString)
                    break
                }
            }

            // Извлечение даты
            var date = Date()
            for pattern in datePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: text) {
                    let dateString = String(text[range])
                    let formats = ["dd.MM.yyyy", "dd.MM.yy", "dd/MM/yyyy", "dd/MM/yy", "dd-MM-yyyy", "dd-MM-yy"]

                    for format in formats {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = format
                        if let parsedDate = dateFormatter.date(from: dateString) {
                            date = parsedDate
                            break
                        }
                    }
                    break
                }
            }

            // Определение категории на основе ключевых слов и магазина
            var category = "Другое"
            var storeName = ""

            for pattern in storePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: text) {
                    storeName = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }

            // Определение категории на основе названия магазина и содержимого
            let categoryKeywords: [String: String] = [
                "продукт": "Питание",
                "еда": "Питание",
                "супермаркет": "Питание",
                "магазин": "Питание",
                "аптек": "Здоровье",
                "лекарств": "Здоровье",
                "транспорт": "Логистика",
                "проезд": "Логистика",
                "такси": "Логистика",
                "бензин": "Логистика",
                "топливо": "Логистика",
                "заправк": "Логистика",
                "кафе": "Питание",
                "ресторан": "Питание",
                "музыка": "Оборудование",
                "инструмент": "Оборудование",
                "оборудование": "Оборудование",
                "gear": "Оборудование"
            ]

            let lowerText = text.lowercased()

            for (keyword, categoryName) in categoryKeywords {
                if lowerText.contains(keyword) || storeName.lowercased().contains(keyword) {
                    category = categoryName
                    break
                }
            }

            // Определение валюты
            var currency = "EUR"
            for pattern in currencyPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   match.numberOfRanges > 0,
                   let range = Range(match.range, in: text) {
                    let currencySymbol = String(text[range])
                    switch currencySymbol {
                    case "₽", "RUB": currency = "RUB"
                    case "$", "USD": currency = "USD"
                    case "€", "EUR": currency = "EUR"
                    default: currency = "EUR"
                    }
                    break
                }
            }

            // Распознавание отдельных позиций чека
            var items: [ReceiptItem] = []
            for pattern in itemPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    for match in matches {
                        if match.numberOfRanges > 2,
                           let nameRange = Range(match.range(at: 1), in: text),
                           let priceRange = Range(match.range(at: 2), in: text) {
                            let name = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            let priceString = String(text[priceRange]).replacingOccurrences(of: ",", with: ".")
                            if let price = Double(priceString), !name.isEmpty {
                                items.append(ReceiptItem(name: name, price: price, currency: currency))
                            }
                        }
                    }
                }
            }

            // Проверка позиций на дубликаты и фильтрация некорректных данных
            let filteredItems = Array(Set(items)).filter { $0.price > 0 && !$0.name.isEmpty }

            // Создание финансовой записи на основе распознанных данных
            if let amount = amount, amount > 0,
               let groupId = AppState.shared.user?.groupId {
                let record = FinanceRecord(
                    type: .expense,
                    amount: amount,
                    currency: currency,
                    category: category,
                    details: "Чек \(storeName.isEmpty ? "" : "от \(storeName)")",
                    date: date,
                    receiptUrl: nil,
                    groupId: groupId
                )

                DispatchQueue.main.async {
                    self.parent.extractedFinanceRecord = record
                    self.parent.recognizedItems = filteredItems
                }
            } else if !filteredItems.isEmpty, let groupId = AppState.shared.user?.groupId {
                // Если общая сумма не распознана, используем сумму всех позиций
                let totalAmount = filteredItems.reduce(0) { $0 + $1.price }

                let record = FinanceRecord(
                    type: .expense,
                    amount: totalAmount,
                    currency: currency,
                    category: category,
                    details: "Чек \(storeName.isEmpty ? "" : "от \(storeName)")",
                    date: date,
                    receiptUrl: nil,
                    groupId: groupId
                )

                DispatchQueue.main.async {
                    self.parent.extractedFinanceRecord = record
                    self.parent.recognizedItems = filteredItems
                }
            }
        }
    }
}
