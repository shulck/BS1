//
//  UserModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import Foundation

struct UserModel: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let phone: String
    let groupId: String?
    let role: UserRole

    enum UserRole: String, Codable, CaseIterable {
        case admin = "Admin"
        case manager = "Manager"
        case musician = "Musician"
        case member = "Member"
    }
}
