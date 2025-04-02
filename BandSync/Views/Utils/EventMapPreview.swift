//
//  EventMapPreview.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//
import SwiftUI
import MapKit

struct EventMapPreview: View {
    var location: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.450001, longitude: 30.523333), // Киев
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var annotation: MapAnnotation?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let annotation = annotation {
                Map(coordinateRegion: $region, annotationItems: [annotation]) { item in
                    MapMarker(coordinate: item.coordinate, tint: item.type.mapColor)
                }
            } else {
                Map(coordinateRegion: $region)
            }
            
            // Индикатор загрузки
            if isLoading {
                ProgressView()
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            geocodeLocation()
        }
    }
    
    private func geocodeLocation() {
        isLoading = true
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            if let error = error {
                print("Ошибка геокодирования локации: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            guard let placemark = placemarks?.first, let location = placemark.location else {
                isLoading = false
                return
            }
            
            // Создаем аннотацию
            let coordinate = location.coordinate
            let name = placemark.name ?? "Место проведения"
            let address = formatAddress(from: placemark)
            
            // Создаем аннотацию для карты
            let newAnnotation = MapAnnotation(
                title: name,
                subtitle: address,
                coordinate: coordinate,
                type: .event,
                date: nil
            )
            
            // Обновляем регион и аннотацию
            DispatchQueue.main.async {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                annotation = newAnnotation
                isLoading = false
            }
        }
    }
    
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
}

// Расширение для типа аннотации
extension MapAnnotation.AnnotationType {
    var mapColor: Color {
        switch self {
        case .event: return .red
        case .venue: return .orange
        case .custom: return .blue
        }
    }
}
