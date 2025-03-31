//
//  TasksView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  TasksView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct TasksView: View {
    @StateObject private var taskService = TaskService.shared
    @State private var showAddTask = false

    var body: some View {
        NavigationView {
            List {
                if !pendingTasks.isEmpty {
                    Section(header: Text("Текущие задачи")) {
                        ForEach(pendingTasks) { task in
                            TaskRow(task: task)
                        }
                    }
                }

                if !completedTasks.isEmpty {
                    Section(header: Text("Выполнено")) {
                        ForEach(completedTasks) { task in
                            TaskRow(task: task)
                        }
                    }
                }
            }
            .navigationTitle("Задачи")
            .toolbar {
                Button {
                    showAddTask = true
                } label: {
                    Label("Новая задача", systemImage: "plus")
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    taskService.fetchTasks(for: groupId)
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView()
            }
        }
    }

    private var pendingTasks: [TaskModel] {
        taskService.tasks.filter { !$0.completed }
    }

    private var completedTasks: [TaskModel] {
        taskService.tasks.filter { $0.completed }
    }

    private func TaskRow(task: TaskModel) -> some View {
        HStack {
            Button(action: {
                TaskService.shared.toggleCompletion(task)
            }) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.completed ? .green : .gray)
            }

            VStack(alignment: .leading) {
                Text(task.title)
                    .font(.headline)
                Text("До: \(formattedDate(task.dueDate))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .swipeActions {
            Button(role: .destructive) {
                TaskService.shared.deleteTask(task)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
