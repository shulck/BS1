import SwiftUI
import MapKit
import EventKit

struct EventDetailView: View {
    @StateObject private var setlistService = SetlistService.shared
    
    // Состояние события и интерфейса
    @State private var event: Event
    @State private var isEditing = false
    @State private var showingSetlistSelector = false
    @State private var showingLocationPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingScheduleEditor = false
    @State private var showingMapOptions = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLocation: LocationDetails?
    @State private var showingAddToCalendarConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    // Проверка прав доступа пользователя для финансовой информации
    private var hasFinanceAccess: Bool {
        return AppState.shared.hasEditPermission(for: .finances)
    }
    
    // Упрощенный инициализатор
    init(event: Event) {
        self._event = State(initialValue: event)
    }
    
    var body: some View {
        // Упрощаем структуру, разбивая на подкомпоненты
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Заголовок события
                eventHeaderSection
                
                Divider()
                
                // Секция локации
                locationSection
                
                Divider()
                
                // Секция сетлиста (только для соответствующих типов событий)
                if event.type == .concert || event.type == .rehearsal {
                    setlistSection
                    Divider()
                }
                
                // Финансовая информация (только для определенных ролей)
                if hasFinanceAccess && event.fee != nil {
                    financesSection
                    Divider()
                }
                
                // Организатор
                organizerSection
                
                Divider()
                
                // Координатор
                coordinatorSection
                
                Divider()
                
                // Отель
                hotelSection
                
                Divider()
                
                // Расписание дня
                scheduleSection
                
                Divider()
                
                // Заметки
                notesSection
                
                // Отображение ошибок
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Кнопки действий
                if !isEditing {
                    actionButtonsSection
                }
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle(isEditing ? "Редактирование" : "Событие")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            mainToolbarItems
        }
        .overlay(loadingOverlay)
        .alert("Удалить событие?", isPresented: $showingDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Вы уверены, что хотите удалить это событие? Это действие нельзя отменить.")
        }
        .alert("Добавить в календарь", isPresented: $showingAddToCalendarConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Добавить") {
                addToCalendar()
            }
        } message: {
            Text("Добавить это событие в ваш личный календарь?")
        }
        .actionSheet(isPresented: $showingMapOptions) {
            ActionSheet(title: Text("Открыть карты"), buttons: [
                .default(Text("Apple Maps")) { openInAppleMaps() },
                .default(Text("Google Maps")) { openInGoogleMaps() },
                .cancel()
            ])
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
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorSheet(schedule: $event.schedule)
        }
        .onAppear {
            setupOnAppear()
        }
    }
    
    // MARK: - UI Components
    
    // Заголовок события
    private var eventHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                if isEditing {
                    TextField("Название события", text: $event.title)
                        .font(.title.bold())
                        .padding(.bottom, 4)
                } else {
                    Text(event.title)
                        .font(.title.bold())
                        .padding(.bottom, 4)
                }
                
                // Индикатор личного события
                if event.isPersonal {
                    Image(systemName: "person.fill")
                        .foregroundColor(event.typeColor)
                        .background(
                            Circle()
                                .fill(event.typeColor.opacity(0.2))
                                .frame(width: 24, height: 24)
                        )
                }
            }
            
            eventTypeAndStatusRow
            
            if isEditing {
                DatePicker("Дата и время", selection: $event.date)
                
                Toggle("Личное событие", isOn: $event.isPersonal)
                    .padding(.top, 5)
            } else {
                Label {
                    Text(formatDate(event.date))
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(event.typeColor)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // Строка с типом и статусом события
    private var eventTypeAndStatusRow: some View {
        HStack(spacing: 16) {
            if isEditing {
                Picker("Тип", selection: $event.type) {
                    ForEach(EventType.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Label {
                    Text(event.type.rawValue)
                } icon: {
                    Image(systemName: getIconForEventType(event.type))
                        .foregroundColor(event.typeColor)
                }
            }
            
            if isEditing {
                Picker("Статус", selection: $event.status) {
                    ForEach(EventStatus.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Label {
                    Text(event.status.rawValue)
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(getStatusColor(event.status))
                }
            }
        }
    }
    
    // Секция локации
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Локация")
                    .font(.headline)
                
                Spacer()
                
                // Кнопка для открытия локации в картах
                if !isEditing && event.location != nil {
                    Button(action: {
                        showingMapOptions = true
                    }) {
                        Label("Маршрут", systemImage: "map")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            
            if isEditing {
                editingLocationView
            } else {
                if let location = event.location, !location.isEmpty {
                    VStack(alignment: .leading) {
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        // Минимальная карта для предпросмотра локации
                        EventMapPreview(location: location)
                            .frame(height: 150)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                } else {
                    Text("Место не указано")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // Редактирование локации
    private var editingLocationView: some View {
        VStack(spacing: 10) {
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
            .padding(.horizontal)
            
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
                .padding(.horizontal)
            } else {
                TextField("Место проведения", text: Binding(
                    get: { event.location ?? "" },
                    set: { event.location = $0.isEmpty ? nil : $0 }
                ))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Секция сетлиста
    private var setlistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Сетлист")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingSetlistView
            } else {
                displaySetlistView
            }
        }
    }
    
    // Редактирование сетлиста
    private var editingSetlistView: some View {
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
        .padding(.horizontal)
    }
    
    // Отображение сетлиста
    private var displaySetlistView: some View {
        Group {
            if let setlistId = event.setlistId,
               let setlist = setlistService.setlists.first(where: { $0.id == setlistId }) {
                NavigationLink(destination: SetlistDetailView(setlist: setlist)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(setlist.name, systemImage: "music.note.list")
                        Text("\(setlist.songs.count) песен • \(setlist.formattedTotalDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                Text("Сетлист не выбран")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Секция финансов
    private var financesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Финансы")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                HStack {
                    TextField("Сумма", value: Binding(
                        get: { event.fee ?? 0 },
                        set: { event.fee = $0 > 0 ? $0 : nil }
                    ), formatter: NumberFormatter())
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    TextField("Валюта", text: Binding(
                        get: { event.currency ?? "EUR" },
                        set: { event.currency = $0.isEmpty ? "EUR" : $0 }
                    ))
                    .frame(width: 80)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                if let fee = event.fee, let currency = event.currency {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Гонорар: \(Int(fee)) \(currency)", systemImage: "dollarsign.circle")
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                } else {
                    Text("Нет информации о гонораре")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // Секция организатора
    private var organizerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Организатор")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                VStack(spacing: 10) {
                    TextField("Имя", text: Binding(
                        get: { event.organizerName ?? "" },
                        set: { event.organizerName = $0.isEmpty ? nil : $0 }
                    ))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    TextField("Email", text: Binding(
                        get: { event.organizerEmail ?? "" },
                        set: { event.organizerEmail = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    TextField("Телефон", text: Binding(
                        get: { event.organizerPhone ?? "" },
                        set: { event.organizerPhone = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 8) {
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
                    
                    if event.organizerName == nil && event.organizerEmail == nil && event.organizerPhone == nil {
                        Text("Нет информации об организаторе")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Секция координатора
    private var coordinatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Координатор")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                VStack(spacing: 10) {
                    TextField("Имя", text: Binding(
                        get: { event.coordinatorName ?? "" },
                        set: { event.coordinatorName = $0.isEmpty ? nil : $0 }
                    ))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    TextField("Email", text: Binding(
                        get: { event.coordinatorEmail ?? "" },
                        set: { event.coordinatorEmail = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    TextField("Телефон", text: Binding(
                        get: { event.coordinatorPhone ?? "" },
                        set: { event.coordinatorPhone = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let name = event.coordinatorName, !name.isEmpty {
                        Label(name, systemImage: "person")
                    }
                    
                    if let email = event.coordinatorEmail, !email.isEmpty {
                        Button {
                            openMail(email)
                        } label: {
                            Label(email, systemImage: "envelope")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let phone = event.coordinatorPhone, !phone.isEmpty {
                        Button {
                            call(phone)
                        } label: {
                            Label(phone, systemImage: "phone")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if event.coordinatorName == nil && event.coordinatorEmail == nil && event.coordinatorPhone == nil {
                        Text("Нет информации о координаторе")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Секция отеля
    private var hotelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Проживание")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                VStack(spacing: 10) {
                    TextField("Название отеля", text: Binding(
                        get: { event.hotelName ?? "" },
                        set: { event.hotelName = $0.isEmpty ? nil : $0 }
                    ))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Новое поле для адреса отеля
                    TextField("Адрес отеля", text: Binding(
                        get: { event.hotelAddress ?? "" },
                        set: { event.hotelAddress = $0.isEmpty ? nil : $0 }
                    ))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    if event.hotelName != nil && !event.hotelName!.isEmpty {
                        DatePicker("Заезд", selection: Binding(
                            get: { event.hotelCheckIn ?? Date() },
                            set: { event.hotelCheckIn = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        DatePicker("Выезд", selection: Binding(
                            get: { event.hotelCheckOut ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())! },
                            set: { event.hotelCheckOut = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let hotelName = event.hotelName, !hotelName.isEmpty {
                        Label(hotelName, systemImage: "house")
                        
                        // Отображение адреса отеля
                        if let hotelAddress = event.hotelAddress, !hotelAddress.isEmpty {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.secondary)
                                Text(hotelAddress)
                                    .foregroundColor(.secondary)
                                
                                // Кнопка для открытия адреса отеля в картах
                                Button(action: {
                                    openHotelInMaps()
                                }) {
                                    Image(systemName: "map")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        if let checkIn = event.hotelCheckIn {
                            Label("Заезд: \(formatDateTime(checkIn))", systemImage: "arrow.down.to.line")
                        }
                        
                        if let checkOut = event.hotelCheckOut {
                            Label("Выезд: \(formatDateTime(checkOut))", systemImage: "arrow.up.to.line")
                        }
                    } else {
                        Text("Нет информации об отеле")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // Секция расписания дня
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Расписание дня")
                    .font(.headline)
                
                Spacer()
                
                // Кнопка редактирования расписания
                if isEditing {
                    Button(action: {
                        showingScheduleEditor = true
                    }) {
                        Label("Редактировать", systemImage: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            
            if let schedule = event.schedule, !schedule.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(schedule.indices, id: \.self) { index in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(schedule[index])
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            } else {
                Text("Нет расписания")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Секция заметок
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Заметки")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                TextEditor(text: Binding(
                    get: { event.notes ?? "" },
                    set: { event.notes = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 100)
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            } else if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            } else {
                Text("Нет заметок")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
    }
    
    // Кнопки действий
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Кнопка добавления в календарь
            Button(action: {
                showingAddToCalendarConfirmation = true
            }) {
                Label("Добавить в календарь", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Кнопка удаления (только для администраторов и менеджеров)
            if AppState.shared.hasEditPermission(for: .calendar) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Удалить событие", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 12)
    }
    
    // Элементы панели инструментов
    @ToolbarContentBuilder
    private var mainToolbarItems: some ToolbarContent {
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
                    cancelEditing()
                }
            }
        }
    }
    
    // Индикатор загрузки
    private var loadingOverlay: some View {
        Group {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Инициализация при первом появлении
    private func setupOnAppear() {
        if let groupId = AppState.shared.user?.groupId {
            setlistService.fetchSetlists(for: groupId)
        }
        
        // Пытаемся извлечь информацию о локации из текстового поля
        if selectedLocation == nil, let locationText = event.location, !locationText.isEmpty {
            geocodeEventLocation(locationText)
        }
    }
    
    // Отмена редактирования
    private func cancelEditing() {
        // Восстанавливаем первоначальные данные
        if let original = EventService.shared.events.first(where: { $0.id == event.id }) {
            event = original
            selectedLocation = nil
        }
        isEditing = false
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
    
    // Получение цвета статуса
    private func getStatusColor(_ status: EventStatus) -> Color {
        switch status {
        case .booked: return .orange
        case .confirmed: return .green
        }
    }
    
    // Форматирование даты
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Форматирование даты и времени
    private func formatDateTime(_ date: Date) -> String {
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
    
    // Геокодирование текстового описания локации
    private func geocodeEventLocation(_ locationText: String) {
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(locationText) { placemarks, error in
            // Проверка на ошибки
            if let error = error {
                print("Ошибка геокодирования: \(error.localizedDescription)")
                return
            }
            
            // Получаем первый результат
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                return
            }
            
            // Получаем название места
            let name: String
            if let placemarkName = placemark.name {
                name = placemarkName
            } else if let eventLocation = self.event.location {
                name = eventLocation
            } else {
                name = "Место события"
            }
            
            // Получаем адрес
            let address = self.formatAddress(from: placemark)
            
            // Создаем идентификатор
            let detailsId = UUID().uuidString
            
            // Получаем координаты
            let coordinates = location.coordinate
            
            // Создаем объект с деталями локации
            let details = LocationDetails(
                id: detailsId,
                name: name,
                address: address,
                coordinate: coordinates
            )
            
            // Обновляем локацию в основном потоке
            DispatchQueue.main.async {
                self.selectedLocation = details
            }
        }
    }
    
    // Форматирование адреса из метки места
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var address = ""
        
        if let thoroughfare = placemark.thoroughfare {
            address += thoroughfare
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            if !address.isEmpty {
                address += " "
            }
            address += subThoroughfare
        }
        
        if let locality = placemark.locality {
            if !address.isEmpty {
                address += ", "
            }
            address += locality
        }
        
        if let administrativeArea = placemark.administrativeArea {
            if !address.isEmpty {
                address += ", "
            }
            address += administrativeArea
        }
        
        if address.isEmpty {
            address = "Неизвестный адрес"
        }
        
        return address
    }
    
    // Сохранение изменений
    private func saveChanges() {
        isLoading = true
        
        // Очищаем финансовую информацию, если у пользователя нет прав
        if !hasFinanceAccess {
            event.fee = nil
            event.currency = nil
        }
        
        EventService.shared.updateEvent(event) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    // Обновляем уведомления для событий
                    NotificationManager.shared.scheduleEventNotification(event: self.event)
                    self.isEditing = false
                } else {
                    self.errorMessage = "Не удалось сохранить изменения"
                }
            }
        }
    }
    
    // Удаление события
    private func deleteEvent() {
        // Отменяем уведомления для этого события
        if let eventId = event.id {
            NotificationManager.shared.cancelNotification(withIdentifier: "event_day_before_\(eventId)")
            NotificationManager.shared.cancelNotification(withIdentifier: "event_hour_before_\(eventId)")
        }
        
        EventService.shared.deleteEvent(event)
        dismiss()
    }
    
    // Открытие в Apple Maps
    private func openInAppleMaps() {
        guard let location = event.location else { return }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            if let error = error {
                print("Ошибка геокодирования: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first, let location = placemark.location {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                mapItem.name = self.event.title
                mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            }
        }
    }
    
    // Открытие в Google Maps
    private func openInGoogleMaps() {
        guard let location = event.location else { return }
        
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    // Открытие адреса отеля в картах
    private func openHotelInMaps() {
        guard let hotelAddress = event.hotelAddress else { return }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(hotelAddress) { placemarks, error in
            if let error = error {
                print("Ошибка геокодирования: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first, let location = placemark.location {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                mapItem.name = self.event.hotelName
                mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            }
        }
    }
    
    // Добавление события в календарь устройства
    private func addToCalendar() {
        let eventStore = EKEventStore()
        
        // Запрос разрешения на доступ к календарю
        eventStore.requestAccess(to: .event) { granted, error in
            if granted && error == nil {
                // Создаем событие
                let ekEvent = EKEvent(eventStore: eventStore)
                ekEvent.title = self.event.title
                ekEvent.startDate = self.event.date
                ekEvent.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: self.event.date) ?? self.event.date
                ekEvent.notes = self.event.notes
                
                // Добавляем место
                if let location = self.event.location {
                    ekEvent.location = location
                }
                
                // Добавляем предупреждения
                ekEvent.addAlarm(EKAlarm(relativeOffset: -24*60*60)) // За день
                ekEvent.addAlarm(EKAlarm(relativeOffset: -60*60))    // За час
                
                // Выбираем календарь
                ekEvent.calendar = eventStore.defaultCalendarForNewEvents
                
                do {
                    try eventStore.save(ekEvent, span: .thisEvent)
                    
                    DispatchQueue.main.async {
                        // Отображаем сообщение об успехе
                        self.errorMessage = "Событие добавлено в календарь"
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Ошибка добавления в календарь: \(error.localizedDescription)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Нет доступа к календарю"
                }
            }
        }
    }
}
