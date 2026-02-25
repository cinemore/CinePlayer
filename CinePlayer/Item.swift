//
//  Item.swift
//  CinePlayer
//
//  Created by Zero on 2026/2/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
