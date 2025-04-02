import SwiftUI
import VisionKit
import Vision
import CoreML

struct ReceiptScannerView: View {
    @Binding var recognizedText: String
    @Binding var extractedFinanceRecord: FinanceRecord?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                ReceiptScannerViewController(
                    recognizedText: $recognizedText,
                    extractedFinanceRecord: $extractedFinanceRecord
                )
                
                // Кнопка подтверждения распознанных данных
                if extractedFinanceRecord != nil {
                    Button("Использовать распознанные данные") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Сканирование чека")
        }
    }
}

struct ReceiptScannerViewController: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var extractedFinanceRecord: FinanceRecord?
    
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
                    self?.extractFinancialDetails(from: fullText)
                }
            }
            
            textRecognitionRequest.recognitionLevel = .accurate
            
            do {
                try requestHandler.perform([textRecognitionRequest])
            } catch {
                print("Ошибка распознавания текста: \(error)")
            }
        }
        
        private func extractFinancialDetails(from text: String) {
            // Регулярные выражения для извлечения данных
            let amountPattern = #"(\d+[.,]?\d{0,2})"#
            let datePattern = #"(\d{1,2}[./]\d{1,2}[./]\d{2,4})"#
            
            // Извлечение суммы
            let amountRegex = try? NSRegularExpression(pattern: amountPattern)
            let amountMatches = amountRegex?.matches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
            
            // Извлечение даты
            let dateRegex = try? NSRegularExpression(pattern: datePattern)
            let dateMatches = dateRegex?.matches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
            
            // Парсинг извлеченных данных
            var amount: Double?
            var date = Date()
            var category = "Другое"
            
            // Поиск суммы
            if let amountMatch = amountMatches?.first,
               let range = Range(amountMatch.range, in: text) {
                let amountString = String(text[range])
                amount = Double(amountString.replacingOccurrences(of: ",", with: "."))
            }
            
            // Поиск даты
            if let dateMatch = dateMatches?.first,
               let range = Range(dateMatch.range, in: text) {
                let dateString = String(text[range])
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd.MM.yy" // Явно указываем формат
                date = dateFormatter.date(from: dateString) ?? Date()
            }
            
            // Определение категории на основе ключевых слов
            let categories: [String: String] = [
                "продукты": "Питание",
                "еда": "Питание",
                "проезд": "Логистика",
                "транспорт": "Логистика",
                "бензин": "Логистика",
                "gear": "Оборудование",
                "оборудование": "Оборудование"
            ]
            
            for (keyword, categoryName) in categories {
                if text.lowercased().contains(keyword) {
                    category = categoryName
                    break
                }
            }
            
            // Создание финансовой записи
            if let amount = amount,
               let groupId = AppState.shared.user?.groupId {
                let record = FinanceRecord(
                    type: .expense,
                    amount: amount,
                    currency: "EUR", // По умолчанию
                    category: category,
                    details: "Сканированный чек",
                    date: date,
                    receiptUrl: nil,
                    groupId: groupId
                )
                
                parent.extractedFinanceRecord = record
            }
        }
    }
}
