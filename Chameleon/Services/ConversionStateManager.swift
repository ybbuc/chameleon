//
//  ConversionStateManager.swift
//  Chameleon
//
//  Created by Jakob Wells on 05.07.25.
//

import Foundation
import Combine

class ConversionStateManager: ObservableObject {
    static let shared = ConversionStateManager()
    
    @Published private(set) var isConverting = false
    
    private init() {}
    
    func setConverting(_ converting: Bool) {
        DispatchQueue.main.async {
            self.isConverting = converting
        }
    }
}