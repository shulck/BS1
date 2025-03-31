//
//  EventDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct EventDetailView: View {
    @StateObject private var setlistService = SetlistService.shared
    @State private var event: Event
    @State private var isEditing = false
    @State private var showingSetlistSelector = false
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    init(event: Event) {
        _event = State(initialValue: event)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Заголовок события и основная информация
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing {
                        TextField("Название события", text: $event.title)
                            .font(.title.bold())
                            .padding(.bottom, 4)
                    } else {
                        Text(event.title)
                            .font(.title.bold())
                            .padding(.bottom, 4)
                    }
                    
                    // Информация о типе и статусе
                    HStack(spacing: 16) {
                        if isEditing {
                            Picker("Тип", selection: $event.type) {
                                ForEach(EventType.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                        } else {
                            Label(event.type.rawValue, systemImage: getIconForEventType(event.type))
                        }
                        
                        if isEditing {
                            Picker("Статус", selection: $event.status) {
                                ForEach(EventStatus.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                        } else {
                            Label(event.status.rawValue, systemImage: "checkmark.circle")
                        }
                    }
                    
                    // Дата события
                    if isEditing {
                        DatePicker("Дата и время", selection: $event.date)
                    } else {
                        Label(formatDate(event.date), systemImage: "calendar")
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Местоположение и финансы
                VStack(alignment: .leading, spacing: 8) {
                    Text("Детали")
                        .font(.headline)
                    
                    if isEditing {
                        HStack {
                            Text("Место:")
                            TextField("Место проведения", text: Binding(
                                get: { event.location ?? "" },
                                set: { event.location = $0.isEmpty ? nil : $0 }
                            ))
                        }
                    } else if let location = event.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                    
                    if isEditing {
                        HStack {
                            Text("Гонорар:")
                            TextField("Сумма", value: Binding(
                                get: { event.fee ?? 0 },
                                set: { event.fee = $0 > 0 ? $0 : nil }
                            ), formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            
                            TextField("Валюта", text: Binding(
                                get: { event.currency ?? "EUR" },
                                set: { event.currency = $0.isEmpty ? "EUR" : $0 }
                            ))
                            .frame(width: 80)
                        }
                    } else if let fee = event.fee, let currency = event.currency {
                        Label("Гонорар: \(Int(fee)) \(currency)", systemImage: "dollarsign")
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Сетлист (новый раздел)
                if event.type == .concert || event.type == .rehearsal {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сетлист")
                            .font(.headline)
                        
                        if isEditing {
                            Button {
                                showingSetlistSelector = true
                            } label: {
                                HStack {
                                    if let setlistId = event.setlistId,
                                       let setlist = setlistService.setlists.first(where: { $0.id == setlistId }) {
                                        Label(setlist.name, systemImage: "music.note.list")
                                    } else {
                                        Label("Выбрать сетлист", systemImage: "plus.circle")
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .padding(10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else if let setlistId = event.setlistId,
                                  let setlist = setlistService.setlists.first(where: { $0.id == setlistId }) {
                            NavigationLink(destination: SetlistDetailView(setlist: setlist)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(setlist.name, systemImage: "music.note.list")
                                    Text("\(setlist.songs.count) песен • \(setlist.formattedTotalDuration)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text("Сетлист не выбран")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // Организатор
                if let organizerName = event.organizerName, !organizerName.isEmpty ||
                   let organizerEmail = event.organizerEmail, !organizerEmail.isEmpty ||
                   let organizerPhone = event.organizerPhone, !organizerPhone.isEmpty {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Организатор")
                            .font(.headline)
                        
                        if isEditing {
                            Group {
                                TextField("Имя", text: Binding(
                                    get: { event.organizerName ?? "" },
                                    set: { event.organizerName = $0.isEmpty ? nil : $0 }
                                ))
                                
                                TextField("Email", text: Binding(
                                    get: { event.organizerEmail ?? "" },
                                    set: { event.organizerEmail = $0.isEmpty ? nil : $0 }
                                ))
                                .keyboardType(.emailAddress)
                                
                                TextField("Телефон", text: Binding(
                                    get: { event.organizerPhone ?? "" },
                                    set: { event.organizerPhone = $0.isEmpty ? nil : $0 }
                                ))
                                .keyboardType(.phonePad)
                            }
                        } else {
                            if let name = event.organizerName, !name.isEmpty {
                                Label(name, systemImage: "person")
                            }
                            
                            if let email = event.organizerEmail, !email.isEmpty {
                                Button {
                                    openMail(email)
                                } label: {
                                    Label(email, systemImage: "envelope")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if let phone = event.organizerPhone, !phone.isEmpty {
                                Button {
                                    call(phone)
                                } label: {
                                    Label(phone, systemImage: "phone")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // Отель
                if let hotelName = event.hotelName, !hotelName.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Проживание")
                            .font(.headline)
                        
                        if isEditing {
                            TextField("Отель", text: Binding(
                                get: { event.hotelName ?? "" },
                                set: { event.hotelName = $0.isEmpty ? nil : $0 }
                            ))
                            
                            if let checkIn = event.hotelCheckIn {
                                DatePicker("Заезд", selection: Binding(
                                    get: { checkIn },
                                    set: { event.hotelCheckIn = $0 }
                                ))
                            }
                            
                            if let checkOut = event.hotelCheckOut {
                                DatePicker("Выезд", selection: Binding(
                                    get: { checkOut },
                                    set: { event.hotelCheckOut = $0 }
                                ))
                            }
                        } else {
                            Label(hotelName, systemImage: "house")
                            
                            if let checkIn = event.hotelCheckIn {
                                Label("Заезд: \(formatDate(checkIn))", systemImage: "arrow.down.to.line")
                            }
                            
                            if let checkOut = event.hotelCheckOut {
                                Label("Выезд: \(formatDate(checkOut))", systemImage: "arrow.up.to.line")
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // Заметки
                VStack(alignment: .leading, spacing: 8) {
                    Text("Заметки")
                        .font(.headline)
                    
                    if isEditing {
                        TextEditor(text: Binding(
                            get: { event.notes ?? "" },
                            set: { event.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 100)
                        .border(Color.gray.opacity(0.2), width: 1)
                    } else if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .padding(.top, 4)
                    } else {
                        Text("Нет заметок")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Ошибки
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Кнопка удаления (только для администраторов и менеджеров)
                if AppState.shared.hasEditPermission(for: .calendar) && !isEditing {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Удалить событие", systemImage: "trash")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle(isEditing ? "Редактирование" : "Событие")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Кнопка редактирования/сохранения (только для администраторов и менеджеров)
            if AppState.shared.hasEditPermission(for: .calendar) {
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Сохранить") {
                            saveChanges()
                        }
                        .disabled(event.title.isEmpty || isLoading)
                    } else {
                        Button("Редактировать") {
                            isEditing = true
                        }
                    }
                }
            }
            
            // Кнопка отмены (только в режиме редактирования)
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        // Восстанавливаем первоначальные данные
                        if let original = EventService.shared.events.first(where: { $0.id == event.id }) {
                            event = original
                        }
                        isEditing = false
                    }
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
        .alert("Удалить событие?", isPresented: $showingDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Вы уверены, что хотите удалить это событие? Это действие нельзя отменить.")
        }
        .sheet(isPresented: $showingSetlistSelector) {
            SetlistSelectorView(selectedSetlistId: $event.setlistId)
        }
        .onAppear {
            if let groupId = AppState.shared.user?.groupId {
                setlistService.fetchSetlists(for: groupId)
            }
        }
    }
    
    // Получение иконки в зависимости от типа события
    private func getIconForEventType(_ type: EventType) -> String {
        switch type {
        case .concert: return "music.mic"
        case .rehearsal: return "pianokeys"
        case .meeting: return "person.2"
        case .interview: return "quote.bubble"
        case .photoshoot: return "camera"
        case .personal: return "person.crop.circle"
        }
    }
    
    // Форматирование даты
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Функция звонка
    private func call(_ phone: String) {
        if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Функция отправки email
    private func openMail(_ email: String) {
        if let url = URL(string: "mailto:\(email)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Сохранение изменений
    private func saveChanges() {
        isLoading = true
        
        EventService.shared.updateEvent(event) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    isEditing = false
                } else {
                    errorMessage = "Не удалось сохранить изменения"
                }
            }
        }
    }
    
    // Удаление события
    private func deleteEvent() {
        EventService.shared.deleteEvent(event)
        dismiss()
    }
}
