//
//  AddEventView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
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
                }

                Section(header: Text("Локация и гонорар")) {
                    TextField("Место", text: Binding(
                        get: { event.location ?? "" },
                        set: { event.location = $0 }
                    ))
                    
                    TextField("Гонорар", value: Binding(
                        get: { event.fee ?? 0 },
                        set: { event.fee = $0 }
                    ), formatter: NumberFormatter())
                    
                    TextField("Валюта", text: Binding(
                        get: { event.currency ?? "" },
                        set: { event.currency = $0 }
                    ))
                }

                Section(header: Text("Организатор")) {
                    TextField("Имя", text: Binding(
                        get: { event.organizerName ?? "" },
                        set: { event.organizerName = $0 }
                    ))
                    
                    TextField("Email", text: Binding(
                        get: { event.organizerEmail ?? "" },
                        set: { event.organizerEmail = $0 }
                    ))
                    
                    TextField("Телефон", text: Binding(
                        get: { event.organizerPhone ?? "" },
                        set: { event.organizerPhone = $0 }
                    ))
                }

                Section(header: Text("Отель")) {
                    TextField("Название отеля", text: Binding(
                        get: { event.hotelName ?? "" },
                        set: { event.hotelName = $0 }
                    ))

                    DatePicker("Заезд", selection: Binding(
                        get: { event.hotelCheckIn ?? Date() },
                        set: { event.hotelCheckIn = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                    
                    DatePicker("Выезд", selection: Binding(
                        get: { event.hotelCheckOut ?? Date() },
                        set: { event.hotelCheckOut = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text("Заметки")) {
                    TextEditor(text: Binding(
                        get: { event.notes ?? "" },
                        set: { event.notes = $0 }
                    ))
                }
            }

            .navigationTitle("Новое событие")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        EventService.shared.addEvent(event) { success in
                            if success { dismiss() }
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

