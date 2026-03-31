import Foundation
import CoreBluetooth
import Combine

// MARK: - UUIDs (match your SensorTile firmware)
// HW Service UUID from uuid_ble_service.h: COPY_HW_SENS_W2ST_SERVICE_UUID
let HW_SERVICE_UUID         = CBUUID(string: "00000000-0001-11E1-9AB4-0002A5D5C51B")
// Environmental characteristic
let ENV_CHAR_UUID           = CBUUID(string: "00140000-0001-11E1-AC36-0002A5D5C51B")
// AccGyroMag characteristic (defined in our sensor_service.c)
let ACC_GYRO_MAG_CHAR_UUID  = CBUUID(string: "00E00000-0001-11E1-AC36-0002A5D5C51B")

// MARK: - Parsed data models
struct AccGyroMagData {
    var timestamp: UInt16
    var accX: Int16;  var accY: Int16;  var accZ: Int16   // mg
    var gyroX: Int16; var gyroY: Int16; var gyroZ: Int16  // mdps/100
    var magX: Int16;  var magY: Int16;  var magZ: Int16   // mgauss

    /// RMS of accelerometer axes (useful for activity detection)
    var rmsAcc: Double {
        let x = Double(accX), y = Double(accY), z = Double(accZ)
        return sqrt((x*x + y*y + z*z) / 3.0)
    }
}

struct EnvironmentalData {
    var timestamp: UInt16
    var pressure: Float?    // mbar
    var humidity: Float?    // %RH
    var temp1: Float?       // °C
    var temp2: Float?       // °C
}

// MARK: - BLE Manager
class BLEManager: NSObject, ObservableObject {

    // Published state
    @Published var isScanning       = false
    @Published var isConnected      = false
    @Published var deviceName       = "Not connected"
    @Published var statusMessage    = "Searching for SensorTile…"

    @Published var latestMotion: AccGyroMagData?
    @Published var latestEnv:    EnvironmentalData?

    // CoreBluetooth internals
    private var centralManager:  CBCentralManager!
    private var peripheral:      CBPeripheral?
    private var envChar:         CBCharacteristic?
    private var motionChar:      CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        statusMessage = "Scanning…"
        // nil = scan ALL peripherals, filter by name in didDiscover
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func disconnect() {
        if let p = peripheral { centralManager.cancelPeripheralConnection(p) }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
            startScan()
        case .poweredOff:
            statusMessage = "Bluetooth is off"
            isConnected = false
        case .unauthorized:
            statusMessage = "Bluetooth not authorized"
        default:
            statusMessage = "Bluetooth unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {

        let name = peripheral.name ??
                   advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        
        guard name.contains("STLB") || name.contains("STLBLE") else { return }
        
        statusMessage = "Found: \(name) — connecting…"
        stopScan()
        self.peripheral = peripheral
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        isConnected = true
        deviceName  = peripheral.name ?? "SensorTile"
        statusMessage = "Connected to \(deviceName)"
        peripheral.delegate = self
        peripheral.discoverServices([HW_SERVICE_UUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        isConnected   = false
        deviceName    = "Not connected"
        statusMessage = "Disconnected — scanning…"
        self.peripheral = nil
        envChar    = nil
        motionChar = nil
        startScan()
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        statusMessage = "Connection failed — retrying…"
        startScan()
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == HW_SERVICE_UUID {
            peripheral.discoverCharacteristics(
                [ENV_CHAR_UUID, ACC_GYRO_MAG_CHAR_UUID],
                for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            switch char.uuid {
            case ENV_CHAR_UUID:
                envChar = char
                peripheral.setNotifyValue(true, for: char)
            case ACC_GYRO_MAG_CHAR_UUID:
                motionChar = char
                peripheral.setNotifyValue(true, for: char)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else { return }

        switch characteristic.uuid {
        case ACC_GYRO_MAG_CHAR_UUID:
            latestMotion = parseAccGyroMag(data)
        case ENV_CHAR_UUID:
            latestEnv = parseEnvironmental(data)
        default:
            break
        }
    }
}

// MARK: - Parsers
// Payload layout matches AccGyroMag_Update() in sensor_service.c
// [0-1] timestamp  [2-7] Acc XYZ  [8-13] Gyro XYZ  [14-19] Mag XYZ  (all Int16 LE)
private func parseAccGyroMag(_ data: Data) -> AccGyroMagData? {
    guard data.count >= 20 else { return nil }
    func i16(_ lo: Int) -> Int16 {
        Int16(data[lo]) | (Int16(data[lo+1]) << 8)
    }
    return AccGyroMagData(
        timestamp: UInt16(data[0]) | (UInt16(data[1]) << 8),
        accX:  i16(2),  accY:  i16(4),  accZ:  i16(6),
        gyroX: i16(8),  gyroY: i16(10), gyroZ: i16(12),
        magX:  i16(14), magY:  i16(16), magZ:  i16(18)
    )
}

// Environmental layout matches Environmental_Update() in sensor_service.c
// [0-1] timestamp, then optional: Press(4B) Hum(2B) Temp2(2B) Temp1(2B) depending on sensors present
// We attempt to parse conservatively
private func parseEnvironmental(_ data: Data) -> EnvironmentalData? {
    guard data.count >= 2 else { return nil }
    var env = EnvironmentalData(timestamp: UInt16(data[0]) | (UInt16(data[1]) << 8))
    var offset = 2

    // Pressure (4 bytes, Int32 → /100.0 mbar)
    if data.count >= offset + 4 {
        let raw = Int32(data[offset]) | (Int32(data[offset+1]) << 8)
                | (Int32(data[offset+2]) << 16) | (Int32(data[offset+3]) << 24)
        env.pressure = Float(raw) / 100.0
        offset += 4
    }
    // Humidity (2 bytes, UInt16 → /10.0 %RH)
    if data.count >= offset + 2 {
        let raw = UInt16(data[offset]) | (UInt16(data[offset+1]) << 8)
        env.humidity = Float(raw) / 10.0
        offset += 2
    }
    // Temp2 (2 bytes, Int16 → /10.0 °C)
    if data.count >= offset + 2 {
        let raw = Int16(data[offset]) | (Int16(data[offset+1]) << 8)
        env.temp2 = Float(raw) / 10.0
        offset += 2
    }
    // Temp1
    if data.count >= offset + 2 {
        let raw = Int16(data[offset]) | (Int16(data[offset+1]) << 8)
        env.temp1 = Float(raw) / 10.0
    }
    return env
}
