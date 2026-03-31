import Foundation

/// Processed feature packet derived from raw IMU data
struct FeaturePacket {
    var timestamp: Double
    var rmsAD: Double       // RMS of accelerometer (mg) — used for activity detection
    var restPct: Double     // placeholder, computed over time window later
    var peakCount: Int      // placeholder

    // Raw sensor values for display
    var accX: Double = 0; var accY: Double = 0; var accZ: Double = 0
    var gyroX: Double = 0; var gyroY: Double = 0; var gyroZ: Double = 0
    var magX: Double = 0;  var magY: Double = 0;  var magZ: Double = 0

    // Environmental
    var temperature: Double? = nil
    var humidity: Double?    = nil
    var pressure: Double?    = nil

    /// Build a FeaturePacket from real BLE data
    static func from(motion: AccGyroMagData, env: EnvironmentalData?) -> FeaturePacket {
        FeaturePacket(
            timestamp: Date().timeIntervalSince1970,
            rmsAD:     motion.rmsAcc,
            restPct:   0,
            peakCount: 0,
            accX:  Double(motion.accX),  accY:  Double(motion.accY),  accZ:  Double(motion.accZ),
            gyroX: Double(motion.gyroX), gyroY: Double(motion.gyroY), gyroZ: Double(motion.gyroZ),
            magX:  Double(motion.magX),  magY:  Double(motion.magY),  magZ:  Double(motion.magZ),
            temperature: env.flatMap { $0.temp1.map { Double($0) } },
            humidity:    env.flatMap { $0.humidity.map { Double($0) } },
            pressure:    env.flatMap { $0.pressure.map { Double($0) } }
        )
    }
}
