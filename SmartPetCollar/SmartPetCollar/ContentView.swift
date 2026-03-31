import SwiftUI

struct ContentView: View {

    @EnvironmentObject var ble: BLEManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    ConnectionBanner(ble: ble)

                    if ble.isConnected, let motion = ble.latestMotion {

                        ActivityCard(
                            accX: Double(motion.accX),
                            accY: Double(motion.accY),
                            accZ: Double(motion.accZ)
                        )

                        SensorCard(title: "Accelerometer", unit: "mg",
                                   x: Double(motion.accX),
                                   y: Double(motion.accY),
                                   z: Double(motion.accZ),
                                   color: .blue)

                        SensorCard(title: "Gyroscope", unit: "mdps×100",
                                   x: Double(motion.gyroX),
                                   y: Double(motion.gyroY),
                                   z: Double(motion.gyroZ),
                                   color: .purple)

                        SensorCard(title: "Magnetometer", unit: "mgauss",
                                   x: Double(motion.magX),
                                   y: Double(motion.magY),
                                   z: Double(motion.magZ),
                                   color: .orange)

                        if let env = ble.latestEnv {
                            EnvCard(env: env)
                        }

                    } else if !ble.isConnected {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.4)
                            Text(ble.statusMessage)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("🐾 Smart Pet Collar")
        }
    }
}

// MARK: - Connection Banner
struct ConnectionBanner: View {
    @ObservedObject var ble: BLEManager
    var body: some View {
        HStack {
            Circle()
                .fill(ble.isConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(ble.isConnected ? ble.deviceName : ble.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if ble.isConnected {
                Button("Disconnect") { ble.disconnect() }
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Activity Card
struct ActivityCard: View {
    let accX, accY, accZ: Double
    var activity: String { detectActivityFromAxes(accX: accX, accY: accY, accZ: accZ) }
    var color: Color { activityColorFromAxes(accX: accX, accY: accY, accZ: accZ) }
    var dynamic: Double { computeDynamicAcc(accX: accX, accY: accY, accZ: accZ) }

    var body: some View {
        VStack(spacing: 6) {
            Text(activity)
                .font(.largeTitle.bold())
            Text("Dynamic Acc: \(dynamic, specifier: "%.0f") mg")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(color.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: 1.5))
        .cornerRadius(14)
    }
}

// MARK: - Sensor Card
struct SensorCard: View {
    let title: String
    let unit: String
    let x, y, z: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            HStack {
                AxisValue(label: "X", value: x, unit: unit, color: color)
                Spacer()
                AxisValue(label: "Y", value: y, unit: unit, color: color)
                Spacer()
                AxisValue(label: "Z", value: z, unit: unit, color: color)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

struct AxisValue: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(color)
            Text("\(value, specifier: "%.0f")")
                .font(.system(.body, design: .monospaced).bold())
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
    }
}

// MARK: - Environmental Card
struct EnvCard: View {
    let env: EnvironmentalData
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Environment")
                .font(.headline)
                .foregroundColor(.teal)
            HStack(spacing: 0) {
                if let t = env.temp1 {
                    EnvItem(icon: "thermometer", label: "Temp", value: String(format: "%.1f°C", t))
                    Spacer()
                }
                if let h = env.humidity {
                    EnvItem(icon: "humidity", label: "Humidity", value: String(format: "%.1f%%", h))
                    Spacer()
                }
                if let p = env.pressure {
                    EnvItem(icon: "gauge", label: "Pressure", value: String(format: "%.0f mbar", p))
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

struct EnvItem: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.teal)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BLEManager())
}
