//
//  EventDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  EventDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct EventDetailView: View {
    let event: Event

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(event.title)
                    .font(.title.bold())

                Label(event.type.rawValue, systemImage: "music.note")
                Label(event.status.rawValue, systemImage: "checkmark.circle")

                if let location = event.location {
                    Label(location, systemImage: "map")
                }

                if let fee = event.fee, let currency = event.currency {
                    Label("Гонорар: \(Int(fee)) \(currency)", systemImage: "dollarsign")
                }

                if let hotel = event.hotelName {
                    Text("🏨 Отель: \(hotel)")
                }

                if let checkIn = event.hotelCheckIn {
                    Text("Заезд: \(formatted(checkIn))")
                }

                if let checkOut = event.hotelCheckOut {
                    Text("Выезд: \(formatted(checkOut))")
                }

                if let notes = event.notes {
                    Text("📝 Заметки:\n\(notes)")
                }

                if let schedule = event.schedule {
                    Text("🗓 Расписание:")
                    ForEach(schedule, id: \.self) { item in
                        Text("- \(item)")
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Событие")
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
