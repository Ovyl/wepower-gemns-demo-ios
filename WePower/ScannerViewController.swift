import CoreBluetooth
import CryptoSwift
import UIKit

struct DeviceData: Equatable, Identifiable {
  var id: UInt16
  var lifetimePresses: UInt32 = 0
  var beaconsRXd = 0
  var accelX: Float = 0.0
  var accelY: Float = 0.0
  var accelZ: Float = 0.0
  var temp: Float = 0.0
  var pressure: Float = 0.0

  var labelTextDeviceInfo: String {
    let date = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "y-MM-dd H:mm:ss"

    let timestamp = formatter.string(from: date)
    return """
      Lifetime Presses: \(lifetimePresses)
      Beacon Reps: \(beaconsRXd)
      Time: \(timestamp)
      """
  }

  var labelTextAccelInfo: String {
    return """
      X: \(accelX)
      Y: \(accelY)
      Z: \(accelZ)
      """
  }

  var labelTextEnviroInfo: String {
    return """
      Temperature: \(String(format: "%05.2f", temp))°C
      Pressure: \(String(format: "%05.2f", pressure))kPa"
      """
  }
}

enum Constant {
  static let encryptedPayloadStartIndex = 2
  static let encryptedPayloadEndIndex = encryptedPayloadStartIndex + 15

  static let encryptedStatusFlagIndex = 20
  static let clearDeviceID = 18
  static let rfuIndex = 21

  static let framStart = 0
  static let accelXStart = framStart + 4
  static let accelYStart = accelXStart + 2
  static let accelZStart = accelYStart + 2
  static let tempStart = accelZStart + 2

  static let pressureStart = tempStart + 2
  static let encDeviceID = pressureStart + 2
}

class ScannerViewController: UIViewController {
  @IBOutlet weak var headerView: UIView!

  @IBOutlet weak var device1View: UIView!
  @IBOutlet weak var device1InfoLabel: UILabel!
  @IBOutlet weak var device1AccelLabel: UILabel!
  @IBOutlet weak var device1EnviroLabel: UILabel!

  @IBOutlet weak var device2View: UIView!
  @IBOutlet weak var device2InfoLabel: UILabel!
  @IBOutlet weak var device2AccelLabel: UILabel!
  @IBOutlet weak var device2EnviroLabel: UILabel!

  @IBOutlet weak var device3View: UIView!
  @IBOutlet weak var device3InfoLabel: UILabel!
  @IBOutlet weak var device3EnviroLabel: UILabel!
  @IBOutlet weak var device3AccelLabel: UILabel!

  @IBAction func restart(_ sender: UIButton) {
    fullReset()
    centralManager.stopScan()
    startScanning()
  }

  private let serviceUUID = "5750"
  var centralManager: CBCentralManager!

  var beaconCounts: [DeviceData.ID: Int] = [:]
  var prevFRAM: [DeviceData.ID: UInt32] = [:]

  override func viewDidLoad() {
    super.viewDidLoad()

    headerView.backgroundColor = UIColor(
      red: 61 / 255,
      green: 174 / 255,
      blue: 43 / 255,
      alpha: 1
    )

    centralManager = CBCentralManager(delegate: self, queue: nil)

    device3View.layer.cornerRadius = 10
    device2View.layer.cornerRadius = 10
    device1View.layer.cornerRadius = 10

    fullReset()
  }
}

// MARK: - Helpers

extension ScannerViewController {

  func fullReset() {
    beaconCounts.removeAll()

    // Generate new device data
    for id in UInt16(1)...3 {
      let seedData = DeviceData(id: id)
      updateDevice(updatedData: seedData)
    }
  }

  func updateDevice(updatedData: DeviceData) {
    var updatedData = updatedData
    if updatedData.lifetimePresses > prevFRAM[updatedData.id, default: 0] {
      updatedData.beaconsRXd = 1
      beaconCounts[updatedData.id] = 1
    }

    prevFRAM[updatedData.id] = updatedData.lifetimePresses
    updateLabels(for: updatedData)
  }

  func updateLabels(for deviceData: DeviceData) {
    switch deviceData.id {
    case 1:
      device1InfoLabel.text = deviceData.labelTextDeviceInfo
      device1AccelLabel.text = deviceData.labelTextAccelInfo
      device1EnviroLabel.text = deviceData.labelTextEnviroInfo
    case 2:
      device2InfoLabel.text = deviceData.labelTextDeviceInfo
      device2AccelLabel.text = deviceData.labelTextAccelInfo
      device2EnviroLabel.text = deviceData.labelTextEnviroInfo
    case 3:
      device3InfoLabel.text = deviceData.labelTextDeviceInfo
      device3AccelLabel.text = deviceData.labelTextAccelInfo
      device3EnviroLabel.text = deviceData.labelTextEnviroInfo
    default:
      // This sample only supports IDs 1, 2 and 3
      break
    }
  }

  func startScanning() {
    let wePowerUUIDs = [CBUUID(string: serviceUUID)]
    let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    centralManager.scanForPeripherals(withServices: wePowerUUIDs, options: options)
  }

  func parsePayload(payloadBytes: Data) -> DeviceData? {

    print("CLEARTEXT PORTION OF PAYLOAD: ")
    print(" - STATUS: \(payloadBytes[Constant.encryptedStatusFlagIndex])")

    // Device ID
    let deviceIDClr =
      (UInt16(payloadBytes[Constant.clearDeviceID + 1]) << 8)
      + (UInt16(payloadBytes[Constant.clearDeviceID]))

    print(" - DEVICE ID: \(deviceIDClr)")
    print(" - RFU: \(payloadBytes[Constant.rfuIndex])")

    // Decrypt if encrypted
    var cipherPayload: [UInt8] = Array(
      payloadBytes[Constant.encryptedPayloadStartIndex...Constant.encryptedPayloadEndIndex])
    if payloadBytes[Constant.encryptedStatusFlagIndex] == 0 {
      print("Encrypted payload detected, decrypting...")
      // Decrypt
      let aesKey: [UInt8] = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e,
        0x0f,
      ]
      let aes = try! AES(key: aesKey, blockMode: ECB(), padding: .noPadding)
      let encrypted = cipherPayload
      let encString = encrypted.map { String(format: "%02X", $0) }.joined(separator: " ")
      print("Encrypted (\(encrypted.count)): \(encString)")
      
      let decrypted = try! aes.decrypt(encrypted)
      cipherPayload = decrypted
      let decString = cipherPayload.map { String(format: "%02X", $0) }.joined(separator: " ")
      print("Decrypted: (\(cipherPayload.count)): \(decString)")
    }

    print("CIPHERTEXT PORTION OF PAYLOAD: ")

    // FRAM Count
    let framCount =
      (UInt32(cipherPayload[Constant.framStart + 3]) << 24)
      + (UInt32(cipherPayload[Constant.framStart + 2]) << 16)
      + (UInt32(cipherPayload[Constant.framStart + 1]) << 8)
      + (UInt32(cipherPayload[Constant.framStart]))

    print(" - FRAM: \(framCount)")

    // Accel X
    let accelX =
      (Int16(cipherPayload[Constant.accelXStart + 1]) << 8)
      + (Int16(cipherPayload[Constant.accelXStart]))

    let accelXF = (Float(accelX)) / 1000
    print(" - ACCEL X: \(accelXF)")

    // Accel Y
    let accelY =
      (Int16(cipherPayload[Constant.accelYStart + 1]) << 8)
      + (Int16(cipherPayload[Constant.accelYStart]))

    let accelYF = (Float(accelY)) / 1000
    print(" - ACCEL Y: \(accelYF)")

    // Accel Z
    let accelZ =
      (Int16(cipherPayload[Constant.accelZStart + 1]) << 8)
      + (Int16(cipherPayload[Constant.accelZStart]))

    let accelZF = (Float(accelZ)) / 1000
    print(" - ACCEL Z: \(accelZF)")

    // Temp
    let temperature =
      (Int16(cipherPayload[Constant.tempStart + 1]) << 8)
      + (Int16(cipherPayload[Constant.tempStart]))

    let temperatureF = (Float(temperature)) / 100
    print(" - TEMPERATURE: \(temperatureF) C")

    // Pressure
    let pressure =
      (Int16(cipherPayload[Constant.pressureStart + 1]) << 8)
      + (Int16(cipherPayload[Constant.pressureStart]))

    let pressureF = (Float(pressure)) / 100
    print(" - PRESSURE: \(pressureF) kPa")

    let deviceIDEnc =
      (UInt16(cipherPayload[Constant.encDeviceID + 1]) << 8)
      + (UInt16(cipherPayload[Constant.encDeviceID]))

    print(" - ENC DEVICE ID: \(deviceIDEnc)")

    guard deviceIDEnc == deviceIDClr else {
      print(" - ERROR: DEVICE ID MISMATCH!!!")
      return nil
    }

    beaconCounts[deviceIDEnc, default: 0] += 1

    return DeviceData(
      id: deviceIDEnc,
      lifetimePresses: framCount,
      beaconsRXd: beaconCounts[deviceIDEnc] ?? 1,
      accelX: accelXF,
      accelY: accelYF,
      accelZ: accelZF,
      temp: temperatureF,
      pressure: pressureF
    )
  }
}

// MARK: - CBCentralManagerDelegate

extension ScannerViewController: CBCentralManagerDelegate {

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      print("central.state is .unknown")
    case .resetting:
      print("central.state is .resetting")
    case .unsupported:
      print("central.state is .unsupported")
    case .unauthorized:
      print("central.state is .unauthorized")
    case .poweredOff:
      print("central.state is .poweredOff")
    case .poweredOn:
      print("central.state is .poweredOn")
      startScanning()
    @unknown default:
      fatalError()
    }
  }

  func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    guard
      let name = peripheral.name,
      let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    else { return }

    print("\(name): \(data)")
    if data.count == 22, let data = parsePayload(payloadBytes: data) {
      updateDevice(updatedData: data)
    }
  }
}
