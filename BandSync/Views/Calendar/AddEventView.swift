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
    
    // Проверка прав доступа пользователя для финансовой информации
    private var hasFinanceAccess: Bool {
        return AppState.shared.hasEditPermission(for: .finances)
    }
    
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
        hotelAddress: nil, // Новое поле для адреса гостиницы
        fee: nil,
        currency: "EUR",
        notes: nil,
        schedule: [],
        setlistId: nil,
        groupId: AppState.shared.user?.groupId ?? "",
        isPersonal: false
    )
    
    // Шаги для форм
    @State private var currentStep = 0
    
    private var maxSteps: Int {
        switch event.type {
        case .concert:
            return 5 // Больше шагов для концертов
        case .rehearsal:
            return 3
        case .personal:
            return 2 // Меньше шагов для личных событий
        default:
            return 4
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Индикатор шага
                StepperView(currentStep: currentStep, totalSteps: maxSteps)
                    .padding()
                
                // Контент текущего шага
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 0:
                            basicInfoStep
                        case 1:
                            locationStep
                        case 2:
                            // Разные шаги в зависимости от типа события
                            if event.type == .concert || event.type == .rehearsal {
                                setlistStep
                            } else if event.type == .personal {
                                notesStep
                            } else {
                                organizerStep
                            }
                        case 3:
                            if event.type == .concert {
                                financialStep
                            } else {
                                hotelStep
                            }
                        case 4:
                            if event.type == .concert {
                                hotelStep
                            } else {
                                notesStep
                            }
                        case 5:
                            notesStep
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                // Кнопки навигации
                HStack {
                    if currentStep > 0 {
                        Button("Назад") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep < maxSteps - 1 {
                        Button("Далее") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canMoveToNextStep())
                    } else {
                        Button("Сохранить") {
                            saveEvent()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(event.title.isEmpty || isLoading)
                    }
                }
                .padding()
            }
            .navigationTitle("Новое событие")
            .toolbar {
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
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Ошибка"),
                    message: Text(errorMessage ?? "Неизвестная ошибка"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Form Steps
    
    // Шаг 1: Основная информация
    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Основная информация")
                .font(.headline)
                .padding(.bottom, 5)
            
            TextField("Название события", text: $event.title)
                .textFieldStyle(.roundedBorder)
            
            DatePicker("Дата и время", selection: $event.date)
            
            Picker("Тип события", selection: $event.type) {
                ForEach(EventType.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            
            Picker("Статус", selection: $event.status) {
                ForEach(EventStatus.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            
            Toggle("Личное событие", isOn: $event.isPersonal)
                .padding(.top, 5)
        }
    }
    
    // Шаг 2: Локация
    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Локация")
                .font(.headline)
                .padding(.bottom, 5)
            
            Button(action: {
                showingLocationPicker = true
            }) {
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.blue)
                    Text("Выбрать на карте")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let location = selectedLocation {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                    Text(location.address)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                TextField("Место проведения", text: Binding(
                    get: { event.location ?? "" },
                    set: { event.location = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    // Шаг 3: Сетлист (для концертов и репетиций)
    private var setlistStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Сетлист")
                .font(.headline)
                .padding(.bottom, 5)
            
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
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // Шаг 4: Финансы (только для концертов и при наличии прав)
    private var financialStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Финансы")
                .font(.headline)
                .padding(.bottom, 5)
            
            if hasFinanceAccess {
                HStack {
                    TextField("Сумма", value: Binding(
                        get: { event.fee ?? 0 },
                        set: { event.fee = $0 > 0 ? $0 : nil }
                    ), formatter: NumberFormatter())
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    
                    TextField("Валюта", text: Binding(
                        get: { event.currency ?? "EUR" },
                        set: { event.currency = $0.isEmpty ? "EUR" : $0 }
                    ))
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                }
            } else {
                Text("У вас нет доступа к финансовой информации")
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Организатор (независимо от доступа)
            Text("Организатор")
                .font(.headline)
                .padding(.vertical, 5)
            
            TextField("Имя", text: Binding(
                get: { event.organizerName ?? "" },
                set: { event.organizerName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            TextField("Email", text: Binding(
                get: { event.organizerEmail ?? "" },
                set: { event.organizerEmail = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.emailAddress)
            .textFieldStyle(.roundedBorder)
            
            TextField("Телефон", text: Binding(
                get: { event.organizerPhone ?? "" },
                set: { event.organizerPhone = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.phonePad)
            .textFieldStyle(.roundedBorder)
            
            // Координатор
            Text("Координатор")
                .font(.headline)
                .padding(.vertical, 5)
            
            TextField("Имя", text: Binding(
                get: { event.coordinatorName ?? "" },
                set: { event.coordinatorName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            TextField("Email", text: Binding(
                get: { event.coordinatorEmail ?? "" },
                set: { event.coordinatorEmail = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.emailAddress)
            .textFieldStyle(.roundedBorder)
            
            TextField("Телефон", text: Binding(
                get: { event.coordinatorPhone ?? "" },
                set: { event.coordinatorPhone = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.phonePad)
            .textFieldStyle(.roundedBorder)
        }
    }
    
    // Шаг для информации об организаторе
    private var organizerStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Организатор")
                .font(.headline)
                .padding(.bottom, 5)
            
            TextField("Имя", text: Binding(
                get: { event.organizerName ?? "" },
                set: { event.organizerName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            TextField("Email", text: Binding(
                get: { event.organizerEmail ?? "" },
                set: { event.organizerEmail = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.emailAddress)
            .textFieldStyle(.roundedBorder)
            
            TextField("Телефон", text: Binding(
                get: { event.organizerPhone ?? "" },
                set: { event.organizerPhone = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.phonePad)
            .textFieldStyle(.roundedBorder)
            
            // Координатор
            Text("Координатор")
                .font(.headline)
                .padding(.vertical, 5)
            
            TextField("Имя", text: Binding(
                get: { event.coordinatorName ?? "" },
                set: { event.coordinatorName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            TextField("Email", text: Binding(
                get: { event.coordinatorEmail ?? "" },
                set: { event.coordinatorEmail = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.emailAddress)
            .textFieldStyle(.roundedBorder)
            
            TextField("Телефон", text: Binding(
                get: { event.coordinatorPhone ?? "" },
                set: { event.coordinatorPhone = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.phonePad)
            .textFieldStyle(.roundedBorder)
        }
    }
    
    // Шаг для информации об отеле
    private var hotelStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Проживание")
                .font(.headline)
                .padding(.bottom, 5)
            
            TextField("Название отеля", text: Binding(
                get: { event.hotelName ?? "" },
                set: { event.hotelName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            // Добавлено новое поле для адреса отеля
            TextField("Адрес отеля", text: Binding(
                get: { event.hotelAddress ?? "" },
                set: { event.hotelAddress = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            if event.hotelName != nil && !event.hotelName!.isEmpty {
                // Улучшенный выбор даты и времени для заезда
                DatePicker("Заезд", selection: Binding(
                    get: { event.hotelCheckIn ?? Date() },
                    set: { event.hotelCheckIn = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                
                // Улучшенный выбор даты и времени для выезда
                DatePicker("Выезд", selection: Binding(
                    get: { event.hotelCheckOut ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())! },
                    set: { event.hotelCheckOut = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
            }
        }
    }
    
    // Шаг с заметками
    private var notesStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Заметки")
                .font(.headline)
                .padding(.bottom, 5)
            
            TextEditor(text: Binding(
                get: { event.notes ?? "" },
                set: { event.notes = $0.isEmpty ? nil : $0 }
            ))
            .frame(minHeight: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Расписание дня
            Text("Расписание дня")
                .font(.headline)
                .padding(.vertical, 5)
            
            ScheduleEditorView(schedule: Binding(
                get: { event.schedule ?? [] },
                set: { event.schedule = $0.isEmpty ? nil : $0 }
            ))
        }
    }
    
    // MARK: - Вспомогательные методы
    
    // Проверка, можно ли перейти к следующему шагу
    private func canMoveToNextStep() -> Bool {
        switch currentStep {
        case 0:
            return !event.title.isEmpty // Требуем заполнения названия
        default:
            return true // Остальные поля необязательны
        }
    }
    
    // Сохранение события
    private func saveEvent() {
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "Не удалось определить группу"
            return
        }
        
        isLoading = true
        event.groupId = groupId
        
        // Очищаем финансовую информацию, если у пользователя нет прав
        if !hasFinanceAccess {
            event.fee = nil
            event.currency = nil
        }
        
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

// MARK: - Вспомогательные компоненты

// Компонент для отображения шагов формы
struct StepperView: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundColor(step <= currentStep ? .blue : .gray.opacity(0.3))
                
                if step < totalSteps - 1 {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(step < currentStep ? .blue : .gray.opacity(0.3))
                }
            }
        }
    }
}

// Компонент для редактирования расписания
struct ScheduleEditorView: View {
    @Binding var schedule: [String]
    @State private var newItem = ""
    
    var body: some View {
        VStack {
            HStack {
                TextField("Добавить пункт расписания", text: $newItem)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: {
                    if !newItem.isEmpty {
                        schedule.append(newItem)
                        newItem = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            List {
                ForEach(schedule.indices, id: \.self) { index in
                    HStack {
                        Text(schedule[index])
                        Spacer()
                        Button(action: {
                            schedule.remove(at: index)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .onMove { indices, newOffset in
                    schedule.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .frame(minHeight: 100, maxHeight: 200)
            .overlay(
                Group {
                    if schedule.isEmpty {
                        Text("Нет пунктов расписания")
                            .foregroundColor(.gray)
                    }
                }
            )
        }
    }
}
