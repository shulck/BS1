//
//  ReceiptScannerView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import VisionKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct ReceiptScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ReceiptScannerViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.scanningStage == .initial {
                    initialView
                } else if viewModel.scanningStage == .scanning {
                    documentScannerView
                } else if viewModel.scanningStage == .processing {
                    processingView
                } else if viewModel.scanningStage == .review {
                    reviewView
                }
            }
            .navigationTitle("Сканирование чека")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                if viewModel.scanningStage == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") {
                            viewModel.saveTransactionFromReceipt {
                                dismiss()
                            }
                        }
                        .disabled(!viewModel.canSaveTransaction)
                    }
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Представления для различных стадий
    
    private var initialView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 72))
                .foregroundColor(.blue)
            
            Text("Сканирование чека")
                .font(.title2)
                .bold()
            
            Text("Держите чек ровно в кадре камеры. Убедитесь, что освещение хорошее и чек не смят.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            Spacer()
            
            Button {
                viewModel.startScanning()
            } label: {
                Text("Начать сканирование")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button {
                viewModel.selectImageFromGallery()
            } label: {
                Text("Выбрать из галереи")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(image: $viewModel.selectedImage)
        }
    }
    
    private var documentScannerView: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()
            
            if viewModel.isDocumentScannerAvailable {
                DocumentScannerViewController(
                    recognizedText: $viewModel.recognizedText,
                    scannedImage: $viewModel.scannedImage,
                    onDismiss: {
                        if viewModel.recognizedText.isEmpty {
                            viewModel.scanningStage = .initial
                        } else {
                            viewModel.processScanResults()
                        }
                    }
                )
            } else {
                Text("Сканирование документов недоступно на этом устройстве")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Обработка изображения...")
                .font(.headline)
            
            Text("Распознавание текста и поиск сумм")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var reviewView: some View {
        VStack(spacing: 0) {
            // Изображение чека и распознанный текст
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Изображение чека
                    if let scannedImage = viewModel.scannedImage {
                        Image(uiImage: scannedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                    }
                    
                    // Распознанные поля
                    fieldsSection
                    
                    // Распознанный текст
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Распознанный текст")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.vertical) {
                            Text(viewModel.recognizedText)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(height: 150)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Компоненты интерфейса
    
    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Распознанные данные")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Тип транзакции (по умолчанию расход для чеков)
                HStack {
                    Text("Тип:")
                        .foregroundColor(.gray)
                    
                    Picker("", selection: $viewModel.transactionType) {
                        Text("Расход").tag(FinanceType.expense)
                        Text("Доход").tag(FinanceType.income)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Сумма
                HStack {
                    Text("Сумма:")
                        .foregroundColor(.gray)
                    
                    TextField("Сумма", text: $viewModel.amountString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(viewModel.isAmountValid ? .primary : .red)
                }
                
                // Валюта
                HStack {
                    Text("Валюта:")
                        .foregroundColor(.gray)
                    
                    TextField("Валюта", text: $viewModel.currency)
                        .multilineTextAlignment(.trailing)
                }
                
                // Дата
                HStack {
                    Text("Дата:")
                        .foregroundColor(.gray)
                    
                    DatePicker("", selection: $viewModel.transactionDate, displayedComponents: [.date])
                        .labelsHidden()
                }
                
                // Категория
                HStack {
                    Text("Категория:")
                        .foregroundColor(.gray)
                    
                    Picker("", selection: $viewModel.category) {
                        ForEach(FinanceCategory.forType(viewModel.transactionType), id: \.self) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                    }
                    .labelsHidden()
                }
                
                // Детали
                VStack(alignment: .leading, spacing: 4) {
                    Text("Детали:")
                        .foregroundColor(.gray)
                    
                    TextField("Описание транзакции", text: $viewModel.transactionDetails)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
}

// MARK: - Компоненты

struct DocumentScannerViewController: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var scannedImage: UIImage?
    var onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = context.coordinator
        return documentCameraViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerViewController
        
        init(_ parent: DocumentScannerViewController) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Берем только первую страницу скана
            let image = scan.imageOfPage(at: 0)
            parent.scannedImage = image
            
            // Запускаем распознавание текста
            recognizeText(from: image)
            
            controller.dismiss(animated: true) {
                self.parent.onDismiss()
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.parent.onDismiss()
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Ошибка сканирования документа: \(error.localizedDescription)")
            controller.dismiss(animated: true) {
                self.parent.onDismiss()
            }
        }
        
        private func recognizeText(from image: UIImage) {
            guard let cgImage = image.cgImage else { return }
            
            // Используем улучшенное распознавание текста
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] request, error in
                if let error = error {
                    print("Ошибка распознавания текста: \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                DispatchQueue.main.async {
                    self?.parent.recognizedText = recognizedText
                }
            }
            
            // Настраиваем опции распознавания для чеков
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                print("Ошибка выполнения запроса на распознавание: \(error.localizedDescription)")
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - ViewModel

class ReceiptScannerViewModel: ObservableObject {
    // Стадии сканирования
    enum ScanningStage {
        case initial, scanning, processing, review
    }
    
    // Состояние сканирования
    @Published var scanningStage: ScanningStage = .initial
    @Published var recognizedText: String = ""
    @Published var scannedImage: UIImage?
    @Published var selectedImage: UIImage?
    @Published var showImagePicker = false
    
    // Данные для транзакции
    @Published var transactionType: FinanceType = .expense
    @Published var amountString: String = ""
    @Published var currency: String = "EUR"
    @Published var category: String = "Питание"
    @Published var transactionDetails: String = ""
    @Published var transactionDate: Date = Date()
    
    // Состояние UI
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // Проверка доступности сканера документов
    var isDocumentScannerAvailable: Bool {
        return VNDocumentCameraViewController.isSupported
    }
    
    // Проверка валидности суммы
    var isAmountValid: Bool {
        if let _ = Double(amountString.replacingOccurrences(of: ",", with: ".")) {
            return true
        }
        return false
    }
    
    // Проверка возможности сохранения транзакции
    var canSaveTransaction: Bool {
        return isAmountValid && !amountString.isEmpty && !currency.isEmpty && !category.isEmpty
    }
    
    // MARK: - Методы
    
    // Запуск сканирования
    func startScanning() {
        if isDocumentScannerAvailable {
            scanningStage = .scanning
        } else {
            alertTitle = "Ошибка"
            alertMessage = "Сканирование документов недоступно на этом устройстве"
            showAlert = true
        }
    }
    
    // Выбор изображения из галереи
    func selectImageFromGallery() {
        showImagePicker = true
    }
    
    // Обработка результатов сканирования
    func processScanResults() {
        scanningStage = .processing
        
        // Если изображение выбрано из галереи, используем его
        if let image = selectedImage {
            scannedImage = image
            recognizeTextFromImage(image)
            return
        }
        
        // Если есть текст и изображение, извлекаем данные
        if !recognizedText.isEmpty && scannedImage != nil {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.extractDataFromText()
                
                DispatchQueue.main.async {
                    self?.scanningStage = .review
                }
            }
        } else {
            scanningStage = .initial
            alertTitle = "Ошибка"
            alertMessage = "Не удалось распознать текст на чеке. Попробуйте снова при лучшем освещении."
            showAlert = true
        }
    }
    
    // Распознавание текста из изображения
    private func recognizeTextFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            scanningStage = .initial
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.alertTitle = "Ошибка"
                    self.alertMessage = "Не удалось распознать текст: \(error.localizedDescription)"
                    self.showAlert = true
                    self.scanningStage = .initial
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    self.scanningStage = .initial
                }
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                self.recognizedText = recognizedText
                self.extractDataFromText()
                self.scanningStage = .review
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            scanningStage = .initial
            alertTitle = "Ошибка"
            alertMessage = "Ошибка распознавания: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // Извлечение данных из распознанного текста
    private func extractDataFromText() {
        let text = recognizedText.lowercased()
        
        // Поиск суммы
        extractAmount(from: text)
        
        // Поиск валюты
        extractCurrency(from: text)
        
        // Попытка найти дату
        extractDate(from: text)
        
        // Попытка определить категорию
        extractCategory(from: text)
        
        // Установка деталей транзакции
        if transactionDetails.isEmpty {
            let lines = recognizedText.components(separatedBy: .newlines)
            if let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.contains("итого") && !$0.contains("сумма") }) {
                transactionDetails = first.trimmingCharacters(in: .whitespaces)
            }
        }
    }
    
    // Поиск суммы в тексте
    private func extractAmount(from text: String) {
        // Паттерны для поиска суммы
        let patterns = [
            "итого\\s*[:=]?\\s*(\\d+[.,]\\d+)",
            "сумма\\s*[:=]?\\s*(\\d+[.,]\\d+)",
            "total\\s*[:=]?\\s*(\\d+[.,]\\d+)",
            "(\\d+[.,]\\d+)\\s*руб",
            "(\\d+[.,]\\d+)\\s*eur",
            "(\\d+[.,]\\d+)\\s*usd",
            "(\\d+[.,]\\d+)\\s*₽",
            "(\\d+[.,]\\d+)\\s*€",
            "(\\d+[.,]\\d+)\\s*\\$",
            "\\*{2,}(\\d+[.,]\\d+)\\*{2,}"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if let amountRange = Range(match.range(at: 1), in: text) {
                        let amount = String(text[amountRange])
                            .replacingOccurrences(of: ",", with: ".")
                            .trimmingCharacters(in: .whitespaces)
                        amountString = amount
                        return
                    }
                }
            }
        }
        
        // Поиск любых чисел с десятичной точкой/запятой (запасной вариант)
        if let regex = try? NSRegularExpression(pattern: "(\\d+[.,]\\d+)", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            // Берем самую большую сумму (вероятно итоговую)
            var maxAmount = 0.0
            for match in matches {
                if let amountRange = Range(match.range(at: 1), in: text) {
                    let amountStr = String(text[amountRange])
                        .replacingOccurrences(of: ",", with: ".")
                    if let amount = Double(amountStr), amount > maxAmount {
                        maxAmount = amount
                        amountString = amountStr
                    }
                }
            }
        }
    }
    
    // Поиск валюты в тексте
    private func extractCurrency(from text: String) {
        let currencyPatterns: [(String, String)] = [
            ("([р₽]|руб)", "RUB"),
            ("([€]|eur)", "EUR"),
            ("([\\$]|usd)", "USD")
        ]
        
        for (pattern, currencyCode) in currencyPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                currency = currencyCode
                return
            }
        }
    }
    
    // Поиск даты в тексте
    private func extractDate(from text: String) {
        let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        
        if let dateDetector = dateDetector {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = dateDetector.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let date = match.date {
                    // Проверяем, что дата не в будущем и не слишком старая
                    let calendar = Calendar.current
                    if calendar.isDateInToday(date) ||
                       calendar.isDateInYesterday(date) ||
                       (date < Date() && date > calendar.date(byAdding: .year, value: -1, to: Date())!) {
                        transactionDate = date
                        return
                    }
                }
            }
        }
    }
    
    // Определение категории расходов
    private func extractCategory(from text: String) {
        // Ключевые слова для категорий
        let keywordsMap: [String: FinanceCategory] = [
            "кафе": .food,
            "ресторан": .food,
            "еда": .food,
            "кофе": .food,
            "продукты": .food,
            "супермаркет": .food,
            "такси": .logistics,
            "проезд": .logistics,
            "автобус": .logistics,
            "поезд": .logistics,
            "отель": .accommodation,
            "гостиница": .accommodation,
            "жилье": .accommodation,
            "музыка": .gear,
            "оборудование": .gear,
            "инструмент": .gear,
            "реклама": .promo,
            "печать": .promo,
            "билеты": .other
        ]
        
        for (keyword, category) in keywordsMap {
            if text.contains(keyword) {
                self.category = category.rawValue
                return
            }
        }
    }
    
    // Сохранение транзакции из чека
    func saveTransactionFromReceipt(completion: @escaping () -> Void) {
        guard let amount = Double(amountString.replacingOccurrences(of: ",", with: ".")),
              let groupId = AppState.shared.user?.groupId else {
            alertTitle = "Ошибка"
            alertMessage = "Не удалось сохранить транзакцию. Проверьте введенные данные."
            showAlert = true
            return
        }
        
        // Создаем запись о финансовой операции
        let record = FinanceRecord(
            type: transactionType,
            amount: amount,
            currency: currency,
            category: category,
            details: transactionDetails,
            date: transactionDate,
            receiptUrl: nil, // В будущем здесь можно сохранять URL изображения чека
            groupId: groupId
        )
        
        // Сохраняем запись через сервис
        FinanceService.shared.add(record) { success in
            if success {
                // Если есть изображение чека, можно его сохранить
                if let image = self.scannedImage {
                    self.saveReceiptImage(image, for: record)
                }
                
                completion()
            } else {
                self.alertTitle = "Ошибка"
                self.alertMessage = "Не удалось сохранить транзакцию. Повторите попытку позже."
                self.showAlert = true
            }
        }
    }
    
    // Сохранение изображения чека
    private func saveReceiptImage(_ image: UIImage, for record: FinanceRecord) {
        // В реальном приложении здесь был бы код для загрузки изображения в Firebase Storage
        // и обновления записи с URL сохраненного изображения
        print("Сохранение изображения чека для записи: \(record.id ?? "unknown")")
    }
}
