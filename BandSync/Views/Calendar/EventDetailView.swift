import SwiftUI
import MapKit

struct EventDetailView: View {
    @StateObject private var setlistService = SetlistService.shared
    
    // Разбиваем состояние на более мелкие части
    @State private var event: Event
    @State private var isEditing = false
    @State private var showingSetlistSelector = false
    @State private var showingLocationPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLocation: LocationDetails?
    @Environment(\.dismiss) var dismiss
    
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
                
                // Организатор
                organizerSection
                
                Divider()
                
                // Отель
                hotelSection
                
                Divider()
                
                // Гонорар
                financesSection
                
                Divider()
                
                // Заметки
                notesSection
                
                // Отображение ошибок
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Кнопка удаления (только для админов и менеджеров)
                if AppState.shared.hasEditPermission(for: .calendar) && !isEditing {
                    deleteButton
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
        .onAppear {
            setupOnAppear()
        }
    }
    
    // MARK: - UI Components
    
    // Заголовок события
    private var eventHeaderSection: some View {
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
            
            eventTypeAndStatusRow
            
            if isEditing {
                DatePicker("Дата и время", selection: $event.date)
            } else {
                Label(formatDate(event.date), systemImage: "calendar")
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
    }
    
    // Секция локации
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Локация")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingLocationView
            } else {
                EventMapView(event: event)
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
    
    // Секция организатора
    private var organizerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Организатор")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingOrganizerView
            } else {
                displayOrganizerView
            }
        }
    }
    
    // Редактирование информации об организаторе
    private var editingOrganizerView: some View {
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
    }
    
    // Отображение информации об организаторе
    private var displayOrganizerView: some View {
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
    
    // Секция отеля
    private var hotelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Проживание")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingHotelView
            } else {
                displayHotelView
            }
        }
    }
    
    // Редактирование информации об отеле
    private var editingHotelView: some View {
        VStack(spacing: 10) {
            TextField("Название отеля", text: Binding(
                get: { event.hotelName ?? "" },
                set: { event.hotelName = $0.isEmpty ? nil : $0 }
            ))
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            if event.hotelName != nil && !event.hotelName!.isEmpty {
                DatePicker("Заезд", selection: Binding(
                    get: { event.hotelCheckIn ?? Date() },
                    set: { event.hotelCheckIn = $0 }
                ))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                DatePicker("Выезд", selection: Binding(
                    get: { event.hotelCheckOut ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())! },
                    set: { event.hotelCheckOut = $0 }
                ))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    // Отображение информации об отеле
    private var displayHotelView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hotelName = event.hotelName, !hotelName.isEmpty {
                Label(hotelName, systemImage: "house")
                
                if let checkIn = event.hotelCheckIn {
                    Label("Заезд: \(formatDate(checkIn))", systemImage: "arrow.down.to.line")
                }
                
                if let checkOut = event.hotelCheckOut {
                    Label("Выезд: \(formatDate(checkOut))", systemImage: "arrow.up.to.line")
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
    
    // Секция финансов
    private var financesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Финансы")
                .font(.headline)
                .padding(.horizontal)
            
            if isEditing {
                editingFinancesView
            } else {
                displayFinancesView
            }
        }
    }
    
    // Редактирование финансовой информации
    private var editingFinancesView: some View {
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
    }
    
    // Отображение финансовой информации
    private var displayFinancesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fee = event.fee, let currency = event.currency {
                Label("Гонорар: \(Int(fee)) \(currency)", systemImage: "dollarsign")
            } else {
                Text("Нет информации о гонораре")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
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
    
    // Кнопка удаления
    private var deleteButton: some View {
        Button {
            showingDeleteConfirmation = true
        } label: {
            Label("Удалить событие", systemImage: "trash")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.top, 16)
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
}
