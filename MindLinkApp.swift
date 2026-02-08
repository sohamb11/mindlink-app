import SwiftUI
import CoreBluetooth

// MARK: - App Entry
@main
struct MindLinkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Main UI
struct ContentView: View {
    @StateObject private var bluetooth = BluetoothManager()

    var body: some View {
        VStack(spacing: 30) {

            Text("MindLink")
                .font(.largeTitle)
                .bold()

            VStack {
                Text("EMG Signal")
                    .font(.headline)
                Text(bluetooth.emgValue)
                    .font(.system(size: 40))
            }

            VStack {
                Text("Temperature (°C)")
                    .font(.headline)
                Text(bluetooth.tempValue)
                    .font(.system(size: 40))
            }

            Button {
                bluetooth.startScanning()
            } label: {
                Text(bluetooth.isConnected ? "Connected" : "Connect to MindLink")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(bluetooth.isConnected ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Bluetooth Manager
class BluetoothManager: NSObject, ObservableObject {

    @Published var emgValue = "--"
    @Published var tempValue = "--"
    @Published var isConnected = false

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    // CHANGE THESE IF YOUR BLE DEVICE USES DIFFERENT UUIDs
    private let serviceUUID = CBUUID(string: "FFE0")
    private let characteristicUUID = CBUUID(string: "FFE1")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID])
        }
    }
}

// MARK: - Central Manager Delegate
extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {

        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }
}

// MARK: - Peripheral Delegate
extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {

        peripheral.services?.forEach {
            peripheral.discoverCharacteristics([characteristicUUID], for: $0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {

        service.characteristics?.forEach {
            peripheral.setNotifyValue(true, for: $0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {

        guard let data = characteristic.value,
              let text = String(data: data, encoding: .utf8) else { return }

        parseSensorData(text)
    }

    private func parseSensorData(_ text: String) {
        // Expected format: EMG:450,TEMP:36.7
        let parts = text.split(separator: ",")

        for part in parts {
            if part.contains("EMG") {
                emgValue = part.replacingOccurrences(of: "EMG:", with: "")
            } else if part.contains("TEMP") {
                tempValue = part.replacingOccurrences(of: "TEMP:", with: "")
            }
        }
    }
}
