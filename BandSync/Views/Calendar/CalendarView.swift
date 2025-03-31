//
//  CalendarView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  CalendarView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct CalendarView: View {
    @StateObject private var eventService = EventService.shared
    @State private var selectedDate = Date()
    @State private var showAddEvent = false

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Выберите дату", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                List {
                    ForEach(eventsForSelectedDate(), id: \.id) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.headline)
                                Text(event.type.rawValue + " • " + event.status.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                if eventsForSelectedDate().isEmpty {
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

    private func eventsForSelectedDate() -> [Event] {
        eventService.events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }
}
