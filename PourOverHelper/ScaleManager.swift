import CoreBluetooth
import Foundation
import Observation

/// 藍牙咖啡秤。目前支援藍牙標準「Weight Scale」服務（0x181D）。
/// Acaia、Timemore 等品牌使用各自的私有協定，需要另外實作對應的解析器。
@Observable
@MainActor
final class ScaleManager: NSObject {
    enum Status: Equatable {
        case idle, unsupported, unauthorized, poweredOff, scanning, connecting(String), connected(String)

        var text: String {
            switch self {
            case .idle:               "未連線"
            case .unsupported:        "此裝置不支援藍牙（模擬器無法使用）"
            case .unauthorized:       "未允許藍牙權限，請到「設定」開啟"
            case .poweredOff:         "藍牙已關閉"
            case .scanning:           "搜尋中…"
            case .connecting(let n):  "連線中：\(n)"
            case .connected(let n):   "已連線：\(n)"
            }
        }
    }

    private(set) var status: Status = .idle
    private(set) var discovered: [CBPeripheral] = []
    /// 扣除歸零值後的重量（克）。
    private(set) var weight: Double?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var rawWeight: Double?
    private var tareOffset: Double = 0
    private var wantsScan = false

    static let weightService = CBUUID(string: "181D")
    static let weightMeasurement = CBUUID(string: "2A9D")

    var isConnected: Bool { if case .connected = status { true } else { false } }

    func startScan() {
        wantsScan = true
        if central == nil {
            // 第一次建立時系統才會跳出藍牙權限詢問。
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central?.state == .poweredOn {
            beginScan()
        }
    }

    func stopScan() {
        wantsScan = false
        central?.stopScan()
        if status == .scanning { status = .idle }
    }

    func connect(_ peripheral: CBPeripheral) {
        central?.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        status = .connecting(peripheral.name ?? "秤")
        central?.connect(peripheral)
    }

    func disconnect() {
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        weight = nil
        status = .idle
    }

    func tare() {
        tareOffset = rawWeight ?? 0
        weight = 0
    }

    private func beginScan() {
        discovered = []
        status = .scanning
        central?.scanForPeripherals(withServices: [Self.weightService])
    }

    /// 解析 Weight Measurement（0x2A9D）：flags 第 0 位 = 0 表示公制，數值單位 5 g；= 1 表示英制，單位 0.01 lb。
    private func handle(_ data: Data) {
        guard data.count >= 3 else { return }
        let flags = data[data.startIndex]
        let raw = Double(UInt16(data[data.startIndex + 1]) | UInt16(data[data.startIndex + 2]) << 8)
        let grams = flags & 0x01 == 0 ? raw * 5 : raw * 0.01 * 453.592
        rawWeight = grams
        weight = grams - tareOffset
    }
}

extension ScaleManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:    if wantsScan { beginScan() } else { status = .idle }
        case .unsupported:  status = .unsupported
        case .unauthorized: status = .unauthorized
        case .poweredOff:   status = .poweredOff
        default:            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discovered.contains(where: { $0.identifier == peripheral.identifier }) {
            discovered.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = .connected(peripheral.name ?? "秤")
        peripheral.discoverServices([Self.weightService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        weight = nil
        status = .idle
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        status = .idle
    }
}

extension ScaleManager: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] where service.uuid == Self.weightService {
            peripheral.discoverCharacteristics([Self.weightMeasurement], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for c in service.characteristics ?? [] where c.uuid == Self.weightMeasurement {
            peripheral.setNotifyValue(true, for: c)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let data = characteristic.value { handle(data) }
    }
}
