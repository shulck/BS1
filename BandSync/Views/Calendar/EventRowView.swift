import SwiftUI

struct EventRowView: View {
    let event: Event
    
    var body: some View {
        HStack {
            // Индикатор цвета слева
            Rectangle()
                .fill(event.typeColor)
                .frame(width: 4)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(event.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(event.typeColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(event.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Отображаем время события
                    Text(event.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 4)
            
            // Иконка личного события (будет добавлена в следующем шаге)
            if event.isPersonal {
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
