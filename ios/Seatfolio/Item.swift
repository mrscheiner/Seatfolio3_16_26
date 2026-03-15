//
//  Item.swift
//  Seatfolio
//
//  Created by Rork on March 13, 2026.
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
