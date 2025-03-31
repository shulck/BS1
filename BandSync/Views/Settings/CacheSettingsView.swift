//
//  CacheSettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  CacheSettingsView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI

struct CacheSettingsView: View {
    @State private var cacheInfo: [String: Any] = [:]
    @State private var isClearing = false
    @State private var showClearConfirmation = false
    
    var body: some View {
        List {
            Section(header: Text("Cache Information".localized)) {
                // Общий размер кэша
                HStack {
                    Text("Total Size".localized)
                    Spacer()
                    Text(formattedSize)
                        .foregroundColor(.secondary)
                }
                
                // Количество файлов
                HStack {
                    Text("Files".localized)
                    Spacer()
                    Text("\(fileCount)")
                        .foregroundColor(.secondary)
                }
                
                // Дата самого старого кэша
                HStack {
                    Text("Oldest Cache".localized)
                    Spacer()
                    Text(formattedOldestDate)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                // Кнопка очистки кэша
                Button(action: {
                    showClearConfirmation = true
                }) {
                    HStack {
                        Text("Clear Cache".localized)
                        Spacer()
                        if isClearing {
                            ProgressView()
                        }
                    }
                    .foregroundColor(.red)
                }
                .disabled(isClearing)
                
                // Кнопка очистки старого кэша
                Button(action: {
                    clearOldCache()
                }) {
                    Text("Clear Older Than 30 Days".localized)
                }
                .disabled(isClearing)
            }
        }
        .navigationTitle("Cache Settings".localized)
        .onAppear {
            loadCacheInfo()
        }
        .alert(isPresented: $showClearConfirmation) {
            Alert(
                title: Text("Clear Cache?".localized),
                message: Text("This will delete all cached data. The app will download fresh data when online.".localized),
                primaryButton: .destructive(Text("Clear".localized)) {
                    clearAllCache()
                },
                secondaryButton: .cancel()
            )
        }
        .refreshable {
            loadCacheInfo()
        }
    }
    
    // Загрузка информации о кэше
    private func loadCacheInfo() {
        cacheInfo = CacheService.shared.getCacheInfo()
    }
    
    // Очистка всего кэша
    private func clearAllCache() {
        isClearing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            CacheService.shared.clearAllCache()
            
            DispatchQueue.main.async {
                isClearing = false
                loadCacheInfo()
            }
        }
    }
    
    // Очистка старого кэша
    private func clearOldCache() {
        isClearing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            CacheService.shared.clearOldCache()
            
            DispatchQueue.main.async {
                isClearing = false
                loadCacheInfo()
            }
        }
    }
    
    // Форматированный размер кэша
    private var formattedSize: String {
        let size = cacheInfo["totalSize"] as? UInt64 ?? 0
        
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }
    
    // Количество файлов
    private var fileCount: Int {
        return cacheInfo["fileCount"] as? Int ?? 0
    }
    
    // Форматированная дата самого старого кэша
    private var formattedOldestDate: String {
        guard let date = cacheInfo["oldestCache"] as? Date else {
            return "—"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}