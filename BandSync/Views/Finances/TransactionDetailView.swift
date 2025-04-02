//
//  TransactionDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct TransactionDetailView: View {
    let record: FinanceRecord
    @State private var showShareSheet = false
    @State private var exportedPDF: Data?

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Логистика": return "car.fill"
        case "Питание": return "fork.knife"
        case "Оборудование": return "guitars"
        case "Площадка": return "building.2.fill"
        case "Промо": return "megaphone.fill"
        case "Другое": return "ellipsis.circle.fill"
        case "Выступление": return "music.note"
        case "Мерч": return "tshirt.fill"
        case "Стриминг": return "headphones"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Заголовок и сумма
                VStack(spacing: 8) {
                    Text("\(record.type == .income ? "+" : "-")\(String(format: "%.2f", record.amount)) \(record.currency)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(record.type == .income ? .green : .red)

                    Text(formattedDate(record.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Детали транзакции
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: record.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundColor(record.type == .income ? .green : .red)
                            .font(.title2)
                        Text("Тип")
                            .font(.headline)
                        Spacer()
                        Text(record.type == .income ? "Доход" : "Расход")
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    HStack {
                        Image(systemName: categoryIcon(for: record.category))
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Категория")
                            .font(.headline)
                        Spacer()
                        Text(record.category)
                            .foregroundColor(.secondary)
                    }

                    if !record.details.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Text("Описание")
                                    .font(.headline)
                            }

                            Text(record.details)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 34)
                        }
                    }

                    if record.isCached == true {
                        Divider()

                        HStack {
                            Image(systemName: "cloud.slash")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("Статус")
                                .font(.headline)
                            Spacer()
                            Text("Ожидает синхронизации")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Кнопки действий
                HStack(spacing: 16) {
                    Button {
                        createPDF()
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text("Поделиться")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        // В будущем здесь можно добавить функциональность редактирования
                    } label: {
                        VStack {
                            Image(systemName: "pencil")
                                .font(.title2)
                            Text("Изменить")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("Детали операции")
        .sheet(isPresented: $showShareSheet) {
            if let pdf = exportedPDF {
                DocumentShareSheet(items: [pdf])
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    // Создание PDF для экспорта - добавляем защиту от краша
    private func createPDF() {
        guard let pdf = generateSafePDF() else { return }
        self.exportedPDF = pdf
        self.showShareSheet = true
    }

    // Отдельный метод для безопасного создания PDF
    private func generateSafePDF() -> Data? {
        let formatter = DateFormatter()
        formatter.dateStyle = .long

        do {
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 595, height: 842), nil)
            UIGraphicsBeginPDFPage()

            let font = UIFont.systemFont(ofSize: 14)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            let titleFont = UIFont.boldSystemFont(ofSize: 24)

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .paragraphStyle: paragraphStyle
            ]

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]

            let title = "Финансовая операция"
            title.draw(in: CGRect(x: 50, y: 50, width: 495, height: 30), withAttributes: titleAttributes)

            var y = 100.0
            let lineHeight = 25.0

            let details = [
                "Тип: \(record.type == .income ? "Доход" : "Расход")",
                "Категория: \(record.category)",
                "Сумма: \(String(format: "%.2f", record.amount)) \(record.currency)",
                "Дата: \(formatter.string(from: record.date))",
                "Описание: \(record.details)"
            ]

            for detail in details {
                detail.draw(in: CGRect(x: 50, y: y, width: 495, height: lineHeight), withAttributes: attributes)
                y += lineHeight
            }

            UIGraphicsEndPDFContext()
            return pdfData as Data
        } catch {
            print("Ошибка при создании PDF: \(error)")
            return nil
        }
    }
}

// Исправляем компонент для отображения ShareSheet
struct TransactionShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Добавление поля для отслеживания статуса синхронизации
extension FinanceRecord {
    var isCached: Bool {
        // Здесь можно добавить реальную логику проверки статуса кэширования
        // Для примера просто возвращаем false
        return false
    }
}
