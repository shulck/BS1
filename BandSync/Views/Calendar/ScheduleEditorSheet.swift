//
//  ScheduleEditorSheet.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//
import SwiftUI

struct ScheduleEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var schedule: [String]?
    @State private var workingSchedule: [String] = []
    @State private var newItem = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Поле для добавления нового пункта
                HStack {
                    TextField("Новый пункт расписания", text: $newItem)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        if !newItem.isEmpty {
                            withAnimation {
                                workingSchedule.append(newItem)
                                newItem = ""
                            }
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                // Список существующих пунктов
                List {
                    ForEach(workingSchedule.indices, id: \.self) { index in
                        HStack {
                            // Время и описание мероприятия
                            if workingSchedule[index].contains(" - ") {
                                let components = workingSchedule[index].split(separator: " - ", maxSplits: 1)
                                if components.count == 2 {
                                    Text(String(components[0]))
                                        .bold()
                                        .frame(width: 70, alignment: .leading)
                                    
                                    Text(String(components[1]))
                                }
                            } else {
                                Text(workingSchedule[index])
                            }
                            
                            Spacer()
                            
                            // Кнопка удаления
                            Button(action: {
                                withAnimation {
                                    workingSchedule.remove(at: index)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onMove { source, destination in
                        workingSchedule.move(fromOffsets: source, toOffset: destination)
                    }
                }
                
                // Подсказка о формате
                VStack(alignment: .leading, spacing: 4) {
                    Text("Совет: для указания времени используйте формат")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("«10:00 - Описание мероприятия»")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding()
            }
            .navigationTitle("Расписание дня")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if workingSchedule.isEmpty {
                            schedule = nil
                        } else {
                            schedule = workingSchedule
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
            .onAppear {
                // Инициализируем рабочий список
                if let existingSchedule = schedule {
                    workingSchedule = existingSchedule
                }
            }
        }
    }
}
