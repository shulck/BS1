//
//  SetlistExportView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  SetlistExportView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI
import PDFKit

struct SetlistExportView: View {
    let setlist: Setlist
    @State private var pdfData: Data?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            if let pdfData = pdfData, let pdfDocument = PDFDocument(data: pdfData) {
                PDFPreviewView(document: pdfDocument)
                    .padding()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                    
                    Text("Предпросмотр PDF")
                        .font(.title2)
                    
                    Text("Сетлист: \(setlist.name)")
                        .font(.headline)
                    
                    Text("\(setlist.songs.count) песен • \(setlist.formattedTotalDuration)")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Spacer()
            
            // Кнопки действий
            VStack(spacing: 16) {
                Button {
                    generatePDF()
                } label: {
                    Label("Создать PDF", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button {
                    showShareSheet = true
                } label: {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pdfData == nil ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(pdfData == nil)
            }
            .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Экспорт сетлиста")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
        .overlay(Group {
            if isExporting {
                VStack {
                    ProgressView()
                    Text("Генерация PDF...")
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
                .shadow(radius: 5)
            }
        })
        .onAppear {
            generatePDF()
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData = pdfData {
                ShareSheet(items: [pdfData])
            }
        }
    }
    
    // Генерация PDF
    private func generatePDF() {
        isExporting = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let generatedPDF = SetlistPDFExporter.export(setlist: setlist)
            
            DispatchQueue.main.async {
                isExporting = false
                
                if let pdf = generatedPDF {
                    pdfData = pdf
                } else {
                    errorMessage = "Не удалось создать PDF. Пожалуйста, попробуйте снова."
                }
            }
        }
    }
}

// Представление для предпросмотра PDF
struct PDFPreviewView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// Представление для отправки PDF
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}