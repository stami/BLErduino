//
//  ViewController.swift
//  Bluetooth
//
//  Created by Samuli Tamminen on 7.12.2015.
//  Copyright © 2015 Samuli Tamminen. All rights reserved.
//

import UIKit
import CoreBluetooth


// Hard coded values for my chip
let transferServiceUUID = CBUUID(string: "FFE0")
let transferCharacteristicUUID = CBUUID(string: "FFE1")


class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @IBOutlet weak var textView: UITextView!

    @IBOutlet weak var sendTextField: UITextField!

    @IBAction func sendButton(sender: AnyObject) {
        if let text = sendTextField.text {
            writeValue(text)
            print("Send: " + text)
        }
    }

    private var centralManager: CBCentralManager?
    private var discoveredPeripheral: CBPeripheral?
    private var discoveredCharacteristic: CBCharacteristic?

    private let data = NSMutableData()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Start up the CBCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        print("Stopping scan")
        centralManager?.stopScan()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // Dismiss keyboard when clicked out of input
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?){
        view.endEditing(true)
        super.touchesBegan(touches, withEvent: event)
    }


    func writeValue(data: String){
        if let data = (data as NSString).dataUsingEncoding(NSUTF8StringEncoding) {
            if let peripheralDevice = discoveredPeripheral {
                if let deviceCharacteristics = discoveredCharacteristic {
                    peripheralDevice.writeValue(data, forCharacteristic: deviceCharacteristics, type: CBCharacteristicWriteType.WithoutResponse)
                }
            }
        }
    }


    /** centralManagerDidUpdateState is a required protocol method.
     *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
     *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
     *  the Central is ready to be used.
     */
    func centralManagerDidUpdateState(central: CBCentralManager) {
        print("\(__LINE__) \(__FUNCTION__)")

        if central.state != .PoweredOn {
            // In a real app, you'd deal with all the states correctly
            return
        }

        // The state must be CBCentralManagerStatePoweredOn...

        // ... so start scanning
        centralManager?.scanForPeripheralsWithServices(
            nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(bool: true)
            ]
        )
        print("Scanning started")
    }

    /** Scan for peripherals - specifically for our service's CBUUID
     */
    func scan() {

        centralManager?.scanForPeripheralsWithServices(
            nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(bool: true)
            ]
        )
        print("Scanning started")
    }

    /** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
     */
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {

        // Reject any where the value is above reasonable range
        // Reject if the signal strength is too low to be close enough (Close is around -22dB)

        //        if  RSSI.integerValue < -15 && RSSI.integerValue > -35 {
        //            println("Device not at correct range")
        //            return
        //        }

        print("Discovered \(peripheral.name) at \(RSSI)")

        // Ok, it's in range - have we already seen it?

        if discoveredPeripheral != peripheral {
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
            discoveredPeripheral = peripheral

            // And connect
            print("Connecting to peripheral \(peripheral)")
            centralManager?.connectPeripheral(peripheral, options: nil)
        }
    }

    /** If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Failed to connect to \(peripheral). (\(error!.localizedDescription))")

        cleanup()
    }

    /** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("Peripheral Connected")

        // Stop scanning
        centralManager?.stopScan()
        print("Scanning stopped")

        // Clear the data that we may already have
        data.length = 0

        // Make sure we get the discovery callbacks
        peripheral.delegate = self

        // Search only for services that match our UUID
        // or nil, to discover all
        peripheral.discoverServices(nil)
    }

    /** The Transfer Service was discovered
     */
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print("didDiscoverServices")

        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            cleanup()
            return
        }

        // Discover the characteristic we want...

        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        for service in peripheral.services as [CBService]! {

            print(service)
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }

    /** The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {

        print("\(__LINE__) \(__FUNCTION__)")

        print(service)

        // Deal with errors (if any)
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            cleanup()
            return
        }

        // Again, we loop through the array, just in case.
        for characteristic in service.characteristics as [CBCharacteristic]! {
            // And check if it's the right one
            print(characteristic)
            print("uuid: \(characteristic.UUID)")
            if characteristic.UUID.isEqual(transferCharacteristicUUID) {

                discoveredCharacteristic = characteristic

                // If it is, subscribe to it
                print("subscribe to charasteristic")
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
        }
        // Once this is complete, we just need to wait for the data to come in.
    }

    /** This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {

        print("\(__LINE__) \(__FUNCTION__)")

        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }

        // Have we got everything we need?
        if let stringFromData = NSString(data: characteristic.value!, encoding: NSUTF8StringEncoding) {

            print("Received: \(stringFromData)")

            data.appendData(characteristic.value!)

            // We have, so show the data,
            textView.text = NSString(data: (data.copy() as! NSData) as NSData, encoding: NSUTF8StringEncoding) as! String

            // Cancel our subscription to the characteristic
            //peripheral.setNotifyValue(false, forCharacteristic: characteristic)

            // and disconnect from the peripehral
            //centralManager?.cancelPeripheralConnection(peripheral)
            //}

        } else {
            print("Invalid data")
        }
    }

    /** The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {

        print("didUpdateNotificationStateForCharacteristic")

        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
        }

        // Exit if it's not the transfer characteristic
        if !characteristic.UUID.isEqual(transferCharacteristicUUID) {
            return
        }

        // Notification has started
        if (characteristic.isNotifying) {
            print("Notification began on \(characteristic)")
        } else {
            // Notification has stopped
            print("Notification stopped on (\(characteristic))  Disconnecting")
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }

    /** Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {

        print("Peripheral Disconnected")
        discoveredPeripheral = nil

        // We're disconnected, so start scanning again
        scan()
    }

    /** Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    private func cleanup() {

        print("\(__LINE__) \(__FUNCTION__)")

        // Don't do anything if we're not connected
        // self.discoveredPeripheral.isConnected is deprecated
        if discoveredPeripheral?.state != CBPeripheralState.Connected { // explicit enum required to compile here?
            return
        }

        // See if we are subscribed to a characteristic on the peripheral
        if let services = discoveredPeripheral?.services as [CBService]? {
            for service in services {
                if let characteristics = service.characteristics as [CBCharacteristic]? {
                    for characteristic in characteristics {
                        if characteristic.UUID.isEqual(transferCharacteristicUUID) && characteristic.isNotifying {
                            discoveredPeripheral?.setNotifyValue(false, forCharacteristic: characteristic)
                            // And we're done.
                            return
                        }
                    }
                }
            }
        }
        
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager?.cancelPeripheralConnection(discoveredPeripheral!)
    }
}