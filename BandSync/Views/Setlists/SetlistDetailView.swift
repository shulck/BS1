//
//  SetlistDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct SetlistDetailView: View {
    @State var setlist: Setlist
    @State private var isEditing = false
    @State private var showAddSong = false
    @State private var showDeleteConfirmation = false
    @State private var showExportView = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    // Временное хранение для редактирования
    @State private var editName = ""
    
    var body: some View {
        VStack {
            // Заголовок и информация
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    TextField("Название сетлиста", text: $editName)
                        .font(.title2.bold())
                        .padding(.horizontal)
                } else {
                    Text(setlist.name)
                        .font(.title2.bold())
                        .padding(.horizontal)
                }
                
                HStack {
                    Text("\(setlist.songs.count) песен")
                    Spacer()
                    Text("Общая длительность: \(setlist.formattedTotalDuration)")
                        .bold()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
            .padding(.top)
            
            Divider()
            
            // Список песен
            List {
                ForEach(setlist.songs) { song in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                            Text("BPM: \(song.bpm)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(song.formattedDuration)
                            .monospacedDigit()
                    }
                }
                .onDelete(perform: isEditing ? deleteSong : nil)
                .onMove(perform: isEditing ? moveSong : nil)
                
                if setlist.songs.isEmpty {
                    Text("Сетлист пустой")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .listStyle(PlainListStyle())
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle(isEditing ? "Редактирование" : "Сетлист")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if AppState.shared.hasEditPermission(for: .setlists) {
                        if isEditing {
                            Button {
                                saveChanges()
                            } label: {
                                Label("Сохранить", systemImage: "checkmark")
                            }
                            
                            Button {
                                showAddSong = true
                            } label: {
                                Label("Добавить песню", systemImage: "music.note.plus")
                            }
                        } else {
                            Button {
                                startEditing()
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Удалить сетлист", systemImage: "trash")
                            }
                        }
                    }
                    
                    Button {
                        showExportView = true
                    } label: {
                        Label("Экспорт в PDF", systemImage: "arrow.up.doc")
                    }
                } label: {
                    Label("Меню", systemImage: "ellipsis.circle")
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        cancelEditing()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
        }
        .overlay(Group {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
        })
        .alert("Удалить сетлист?", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteSetlist()
            }
        } message: {
            Text("Вы уверены, что хотите удалить этот сетлист? Это действие нельзя отменить.")
        }
        .sheet(isPresented: $showAddSong) {
            AddSongView(setlist: $setlist, onSave: {
                // После добавления песни, обновляем сетлист
                updateSetlist()
            })
        }
        .sheet(isPresented: $showExportView) {
            SetlistExportView(setlist: setlist)
        }
    }
    
    // Начало редактирования
    private func startEditing() {
        editName = setlist.name
        isEditing = true
    }
    
    // Отмена редактирования
    private func cancelEditing() {
        editName = ""
        isEditing = false
    }
    
    // Сохранение изменений
    private func saveChanges() {
        // Обновляем имя сетлиста
        if !editName.isEmpty && editName != setlist.name {
            setlist.name = editName
        }
        
        updateSetlist()
        isEditing = false
    }
    
    // Удаление песни
    private func deleteSong(at offsets: IndexSet) {
        setlist.songs.remove(atOffsets: offsets)
    }
    
    // Перемещение песни
    private func moveSong(from source: IndexSet, to destination: Int) {
        setlist.songs.move(fromOffsets: source, toOffset: destination)
    }
    
    // Обновление сетлиста в базе данных
    private func updateSetlist() {
        isLoading = true
        errorMessage = nil
        
        SetlistService.shared.updateSetlist(setlist) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if !success {
                    errorMessage = "Не удалось сохранить изменения"
                }
            }
        }
    }
    
    // Удаление сетлиста
    private func deleteSetlist() {
        SetlistService.shared.deleteSetlist(setlist)
        dismiss()
    }
}

// Представление для добавления песни
struct AddSongView: View {
    @Binding var setlist: Setlist
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var bpm = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о песне")) {
                    TextField("Название", text: $title)
                    
                    HStack {
                        Text("Длительность:")
                        TextField("Мин", text: $minutes)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                        Text(":")
                        TextField("Сек", text: $seconds)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                    }
                    
                    TextField("BPM", text: $bpm)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Добавить песню")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        addSong()
                    }
                    .disabled(title.isEmpty || (minutes.isEmpty && seconds.isEmpty) || bpm.isEmpty)
                }
            }
        }
    }
    
    private func addSong() {
        guard !title.isEmpty else { return }
        
        let min = Int(minutes) ?? 0
        let sec = Int(seconds) ?? 0
        let bpmValue = Int(bpm) ?? 120
        
        // Проверка валидности данных
        if min == 0 && sec == 0 {
            return
        }
        
        // Создаем новую песню
        let newSong = Song(
            title: title,
            durationMinutes: min,
            durationSeconds: sec,
            bpm: bpmValue
        )
        
        // Добавляем песню в сетлист
        setlist.songs.append(newSong)
        
        // Вызываем обработчик сохранения
        onSave()
        
        // Закрываем модальное окно
        dismiss()
    }
}
