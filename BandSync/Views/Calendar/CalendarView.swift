import SwiftUI

struct CalendarView: View {
    @StateObject private var eventService = EventService.shared
    @State private var selectedDate = Date()
    @State private var showAddEvent = false
    @State private var showPersonalEventsOnly = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Селектор даты
                DatePicker("Выберите дату", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                // Переключатель для личных событий
                Toggle("Только личные события", isOn: $showPersonalEventsOnly)
                    .padding(.horizontal)
                
                // Список событий
                List {
                    ForEach(filteredEvents(), id: \.id) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            EventRowView(event: event)
                        }
                    }
                }
                
                if filteredEvents().isEmpty {
                    Text("Нет событий на выбранную дату")
                        .foregroundColor(.gray)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Календарь")
            .toolbar {
                Button(action: {
                    showAddEvent = true
                }) {
                    Label("Добавить", systemImage: "plus")
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    eventService.fetchEvents(for: groupId)
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView()
            }
        }
    }
    
    private func filteredEvents() -> [Event] {
        // Фильтруем по дате
        let dateEvents = eventService.events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
        
        // Дополнительный фильтр для личных событий
        if showPersonalEventsOnly {
            return dateEvents.filter { $0.isPersonal }
        } else {
            // Если пользователь не админ/менеджер, показываем только общие события группы и его личные события
            if !AppState.shared.hasEditPermission(for: .calendar) {
                return dateEvents.filter { $0.isPersonal || $0.isPersonal == false }
            }
            return dateEvents
        }
    }
}
