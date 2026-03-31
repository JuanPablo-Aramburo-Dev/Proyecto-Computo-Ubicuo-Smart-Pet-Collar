import Foundation
import SwiftUI

func computeDynamicAcc(accX: Double, accY: Double, accZ: Double) -> Double {
    // Eliminamos gravedad sin importar orientacion del sensor
    // Restamos la componente gravitacional usando la magnitud total
    let magnitude = sqrt(accX*accX + accY*accY + accZ*accZ)
    let dynamicG = abs(magnitude - 1000.0) // 1000mg = 1g de gravedad
    return dynamicG
}

func detectActivityFromAxes(accX: Double, accY: Double, accZ: Double) -> String {
    let dynamic = computeDynamicAcc(accX: accX, accY: accY, accZ: accZ)
    switch dynamic {
    // Perro acostado/durmiendo — puede rodar o acomodarse (hasta 300mg)
    case 0..<250:   return "Resting 🐩"
    // Perro caminando — pasos moderados
    case 300..<700: return "Walking 🐾"
    // Perro corriendo — mucho movimiento
    default:        return "Running 🐕"
    }
}

func activityColorFromAxes(accX: Double, accY: Double, accZ: Double) -> Color {
    let dynamic = computeDynamicAcc(accX: accX, accY: accY, accZ: accZ)
    switch dynamic {
    case 0..<300:   return .blue
    case 300..<700: return .green
    default:        return .orange
    }
}
