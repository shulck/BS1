//
//  GroupModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  GroupModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct GroupModel: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var code: String
    var members: [String]
    var pendingMembers: [String]
}
