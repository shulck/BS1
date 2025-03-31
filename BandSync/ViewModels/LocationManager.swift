//
//  LocationManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import Foundation
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var isAuthorized = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Проверяем текущий статус авторизации
        authorizationStatus = manager.authorizationStatus
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // Запрос разрешения на использование местоположения
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    // Запрос местоположения (однократно)
    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        if isAuthorized {
            manager.requestLocation()
            
            // Ждем получения местоположения или используем последнее известное
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                completion(self.location)
            }
        } else {
            // Если нет разрешения, запрашиваем его
            requestWhenInUseAuthorization()
            completion(nil)
        }
    }
    
    // Начать отслеживание местоположения
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
    
    // Остановить отслеживание местоположения
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    // Получение обновления местоположения
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    // Обработка ошибок
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Ошибка определения местоположения: \(error.localizedDescription)")
    }
    
    // Обработка изменения статуса авторизации
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // MARK: - Utility Methods
    
    // Получение названия места по координатам
    func getPlaceName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                completion(nil)
                return
            }
            
            var placeName = ""
            
            if let name = placemark.name {
                placeName = name
            } else if let thoroughfare = placemark.thoroughfare {
                placeName = thoroughfare
                
                if let subThoroughfare = placemark.subThoroughfare {
                    placeName += " " + subThoroughfare
                }
            }
            
            if placeName.isEmpty {
                if let locality = placemark.locality {
                    placeName = locality
                } else if let administrativeArea = placemark.administrativeArea {
                    placeName = administrativeArea
                } else {
                    placeName = "Неизвестное место"
                }
            }
            
            completion(placeName)
        }
    }
    
    // Построение маршрута между двумя точками
    func calculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, completion: @escaping (MKRoute?) -> Void) {
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destinationItem
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first, error == nil else {
                completion(nil)
                return
            }
            
            completion(route)
        }
    }
    
    // Расчет расстояния между двумя точками
    func distance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        return sourceLocation.distance(from: destinationLocation)
    }
    
    // Форматирование расстояния для отображения
    func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
}