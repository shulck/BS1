//
//  MapView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import MapKit

struct EventMapView: View {
    // Объект для работы с регионом карты
    @Binding var region: MKCoordinateRegion
    // Точки (пины) на карте
    var annotations: [MapAnnotation]
    // Обратный вызов при выборе местоположения
    var onLocationSelected: ((CLLocationCoordinate2D) -> Void)?
    // Разрешить выбор локации на карте
    var allowSelection: Bool = false
    
    // Состояние карты
    @State private var selectedAnnotation: MapAnnotation?
    @State private var mapType: MKMapType = .standard
    @State private var userTrackingMode: MKUserTrackingMode = .none
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Карта
            MapViewRepresentable(
                region: $region,
                annotations: annotations,
                selectedAnnotation: $selectedAnnotation,
                mapType: $mapType,
                userTrackingMode: $userTrackingMode,
                onLocationSelected: onLocationSelected,
                allowSelection: allowSelection
            )
            
            // Кнопки управления
            VStack(spacing: 10) {
                // Кнопка изменения типа карты
                Button(action: {
                    mapType = mapType == .standard ? .satellite : .standard
                }) {
                    Image(systemName: mapType == .standard ? "map" : "map.fill")
                        .padding(10)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                
                // Кнопка отслеживания местоположения пользователя
                Button(action: {
                    userTrackingMode = userTrackingMode == .none ? .follow : .none
                }) {
                    Image(systemName: userTrackingMode == .none ? "location" : "location.fill")
                        .padding(10)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
            }
            .padding()
        }
        // Отображение детальной информации о выбранном месте
        .sheet(item: $selectedAnnotation) { annotation in
            VStack(spacing: 15) {
                Text(annotation.title)
                    .font(.headline)
                
                Text(annotation.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let date = annotation.date {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let onLocationSelected = onLocationSelected, allowSelection {
                    Button("Выбрать это место") {
                        onLocationSelected(annotation.coordinate)
                        selectedAnnotation = nil
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button("Закрыть") {
                    selectedAnnotation = nil
                }
                .padding(.top)
            }
            .padding()
        }
    }
    
    // Форматирование даты для отображения
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Модель для аннотации на карте
struct MapAnnotation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    let date: Date?
    var eventId: String?
    
    enum AnnotationType {
        case event
        case venue
        case custom
    }
}

// UIKit обертка для карты
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [MapAnnotation]
    @Binding var selectedAnnotation: MapAnnotation?
    @Binding var mapType: MKMapType
    @Binding var userTrackingMode: MKUserTrackingMode
    var onLocationSelected: ((CLLocationCoordinate2D) -> Void)?
    var allowSelection: Bool
    
    // Создание MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Длинное нажатие для выбора локации
        if allowSelection {
            let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
            mapView.addGestureRecognizer(longPressGesture)
        }
        
        return mapView
    }
    
    // Обновление MKMapView
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Обновление региона карты
        mapView.setRegion(region, animated: true)
        
        // Обновление типа карты
        mapView.mapType = mapType
        
        // Обновление режима отслеживания пользователя
        mapView.userTrackingMode = userTrackingMode
        
        // Обновление аннотаций
        updateAnnotations(on: mapView)
    }
    
    // Создание координатора для делегирования
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Обновление аннотаций на карте
    private func updateAnnotations(on mapView: MKMapView) {
        // Удаляем все текущие аннотации
        mapView.removeAnnotations(mapView.annotations)
        
        // Добавляем новые аннотации
        for annotation in annotations {
            let mapAnnotation = MKPointAnnotation()
            mapAnnotation.title = annotation.title
            mapAnnotation.subtitle = annotation.subtitle
            mapAnnotation.coordinate = annotation.coordinate
            mapView.addAnnotation(mapAnnotation)
        }
    }
    
    // Координатор для делегирования и обработки событий
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        // Настройка внешнего вида аннотации
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !annotation.isKind(of: MKUserLocation.self) else {
                return nil
            }
            
            let identifier = "MapPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                // Добавляем кнопку информации справа
                let infoButton = UIButton(type: .detailDisclosure)
                annotationView?.rightCalloutAccessoryView = infoButton
            } else {
                annotationView?.annotation = annotation
            }
            
            // Настройка цвета и глифа маркера
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .blue
                markerView.glyphImage = UIImage(systemName: "music.mic")
            }
            
            return annotationView
        }
        
        // Обработка нажатия на кнопку информации
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let annotation = view.annotation else { return }
            
            // Находим аннотацию в списке
            if let matchingAnnotation = parent.annotations.first(where: { $0.coordinate.latitude == annotation.coordinate.latitude && $0.coordinate.longitude == annotation.coordinate.longitude }) {
                parent.selectedAnnotation = matchingAnnotation
            }
        }
        
        // Обработка длительного нажатия на карту для выбора локации
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView, gesture.state == .began else { return }
            
            let touchPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            // Получаем информацию о выбранном месте
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    print("Ошибка геокодирования: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    return
                }
                
                // Создаем аннотацию для выбранного места
                let title = placemark.name ?? "Выбранное место"
                var subtitle = ""
                
                if let thoroughfare = placemark.thoroughfare {
                    subtitle += thoroughfare
                }
                
                if let locality = placemark.locality {
                    if !subtitle.isEmpty {
                        subtitle += ", "
                    }
                    subtitle += locality
                }
                
                if subtitle.isEmpty {
                    subtitle = "Неизвестный адрес"
                }
                
                let annotation = MapAnnotation(
                    title: title,
                    subtitle: subtitle,
                    coordinate: coordinate,
                    type: .custom,
                    date: nil
                )
                
                self.parent.selectedAnnotation = annotation
            }
        }
        
        // Обработка изменения видимой области карты
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}
