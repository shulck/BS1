import SwiftUI
import Contacts
import ContactsUI // Добавьте этот импорт

struct ContactPickerView: UIViewControllerRepresentable {
    var onContactPicked: (CNContact?) -> Void
    
    // Создание координатора
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Создание UIViewController
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    // Обновление UIViewController (обычно пустой)
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    // Координатор для обработки делегата
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onContactPicked(nil)
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactPicked(contact)
        }
    }
}
