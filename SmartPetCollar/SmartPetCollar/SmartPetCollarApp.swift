//
//  SmartPetCollarApp.swift
//  SmartPetCollar
//
//  Created by Juan Pablo Aramburo Silva on 13/03/26.
//

import SwiftUI

@main
struct SmartPetCollarApp: App {
    
    // Inicializar BLEManager aquí fuerza el permiso al arrancar
    @StateObject private var ble = BLEManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
        }
    }
}
