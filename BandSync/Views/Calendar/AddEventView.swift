import SwiftUI
import MapKit

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var setlistService = SetlistService.shared
    @State private var showingSetlistSelector = false
    @State private var showingLocationPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLocation: LocationDetails?
    
    @State private var event = Event(
        title: "",
        date: Date(),
        type: .concert,
        status: .booked,
        location: nil,
        organizerName: nil,
        organizerEmail: nil,
        organizerPhone: nil,
        coordinatorName: nil,
        coordinatorEmail: nil,
        coordinatorPhone: nil,
        hotelName: nil,
        hotelCheckIn: nil,
        hotelCheckOut: nil,
        fee: nil,
        currency: "EUR",
        notes: nil,
        schedule: [],
        setlistId: nil,
        groupId: AppState.shared.user?.groupId ?? "",
        isPersonal: false
    )

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Основное")) {
                    TextField("Название", text: $event.title)
                    DatePicker("Дата", selection: $event.date)
                    
                    Picker("Тип", selection: $event.type) {
                        ForEach(EventType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    
                    Picker("Статус", selection: $event.status) {
                        ForEach(EventStatus.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    
                    // Поле для сетлиста
                    if event.type == .concert || event.type == .rehearsal {
                        Button {
                            showingSetlistSelector = true
                        } label: {
                            HStack {
                                Text("Сетлист")
                                Spacer()
                                Text(getSetlistName())
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                }

                Section(header: Text("Локация")) {
                    // Кнопка для выбора локации на карте
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                            Text("Выбрать на карте")
                        }
                    }
                    
                    // Отображение выбранной локации
                    if let location = selectedLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.headline)
                            Text(location.address)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        
                        // Кнопка для сброса выбранной локации
                        Button("Сбросить локацию") {
                            selectedLocation = nil
                            event.location = nil
                        }
                        .foregroundColor(.red)
                    } else {
                        TextField("Место проведения", text: Binding(
                            get: { event.location ?? "" },
                            set: { event.location = $0.isEmpty ? nil : $0 }
                        ))
                    }
                }

                Section(header: Text("Гонорар")) {
                    HStack {
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
                }

                Section(header: Text("Организатор")) {
                    TextField("Имя", text: Binding(
                        get: { event.organizerName ?? "" },
                        set: { event.organizerName = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Email", text: Binding(
                        get: { event.organizerEmail ?? "" },
                        set: { event.organizerEmail = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    TextField("Телефон", text: Binding(
                        get: { event.organizerPhone ?? "" },
                        set: { event.organizerPhone = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.phonePad)
                }

                Section(header: Text("Отель")) {
                    TextField("Название отеля", text: Binding(
                        get: { event.hotelName ?? "" },
                        set: { event.hotelName = $0.isEmpty ? nil : $0 }
                    ))

                    if event.hotelName != nil && !event.hotelName!.isEmpty {
                        DatePicker("Заезд", selection: Binding(
                            get: { event.hotelCheckIn ?? Date() },
                            set: { event.hotelCheckIn = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        
                        DatePicker("Выезд", selection: Binding(
                            get: { event.hotelCheckOut ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())! },
                            set: { event.hotelCheckOut = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section(header: Text("Заметки")) {
                    TextEditor(text: Binding(
                        get: { event.notes ?? "" },
                        set: { event.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 100)
                }
                
                // Отображение ошибок
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Новое событие")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveEvent()
                    }
                    .disabled(event.title.isEmpty || isLoading)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSetlistSelector) {
                SetlistSelectorView(selectedSetlistId: $event.setlistId)
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
                    .onDisappear {
                        // Обновляем локацию события при выборе места на карте
                        if let location = selectedLocation {
                            event.location = location.name + ", " + location.address
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
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    setlistService.fetchSetlists(for: groupId)
                }
            }
        }
    }
    
    // Получение названия выбранного сетлиста
    private func getSetlistName() -> String {
        if let setlistId = event.setlistId,
           let setlist = setlistService.setlists.first(where: { $0.id == setlistId }) {
            return setlist.name
        }
        return "Не выбран"
    }
    
    // Сохранение события
    private func saveEvent() {
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "Не удалось определить группу"
            return
        }
        
        isLoading = true
        event.groupId = groupId
        
        EventService.shared.addEvent(event) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    // Планируем уведомления для событий
                    NotificationManager.shared.scheduleEventNotification(event: event)
                    dismiss()
                } else {
                    errorMessage = "Не удалось сохранить событие"
                }
            }
        }
    }
}
