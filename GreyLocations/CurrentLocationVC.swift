//
//  FirstViewController.swift
//  GreyLocations
//
//  Created by Grey Markling on 5/30/17.
//  Copyright © 2017 Grey Markling. All rights reserved.
//

import UIKit
import CoreLocation

class CurrentLocationVC: UIViewController, CLLocationManagerDelegate {

    var location: CLLocation?
    var timer: Timer?
    
    //handling errors
    var updatingLocation = false
    var lastLocationError: Error?
    
    
    //MARK: -- GEOCODER
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingRGC = false
    var lastGeocodingErr: Error?
    
    
    //MARK: -- core location properties
    // will give me the GPS coordinates
    let locationManager = CLLocationManager()
    
    //MARK: -- CLLocationManagerDelegate 
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError \(error)")
        
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            return
        }
        
        lastLocationError = error
        
        stopLocationManager()
        configureGetGPSButton()
        updateLabels()
        
    }
    
    
    
    func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            updatingLocation  = true
            
            
            timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(didTimeOut), userInfo: nil, repeats: false)
        }
    
    
    
    
    }
    
    
    func stopLocationManager() {
    
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
            
            if let timer = timer {
                timer.invalidate()
            }
        }
    
    
    
    }
    
    
    func didTimeOut() {
        print("***TIMEOUT***")
        if location == nil {
            stopLocationManager()
            lastLocationError = NSError(domain: "MyLocationsSTringError", code: 1, userInfo: nil)
            updateLabels()
            configureGetGPSButton()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last!
        print("didUpdateLocations \(newLocation)")
        
        //1 
        if newLocation.timestamp.timeIntervalSinceNow < -5 {
            return
        }
        //2 
        if newLocation.horizontalAccuracy < 0 {
            return
        }
        var distance  = CLLocationDistance(DBL_MAX)
        if let location = location {
            distance = newLocation.distance(from: location)
        }
    
        
        
        if location == nil ||
            location!.horizontalAccuracy > newLocation.horizontalAccuracy {
            //4
            lastLocationError = nil
            location = newLocation
            updateLabels()
            
            //5
            if newLocation.horizontalAccuracy <=
                locationManager.desiredAccuracy {
               print("***WE are DONE!")
                stopLocationManager()
                configureGetGPSButton()
                
                if distance > 0 {
                    performingRGC = false
                }
            }
            if !performingRGC {
                print("*** Preparing Reverse GeoCoding Module***")
                performingRGC = true
                geocoder.reverseGeocodeLocation(newLocation, completionHandler: { placemarks, error in
                    print("***Found Placemarks: \(placemarks), error: \(error)")
                    
                    self.lastGeocodingErr = error
                    if error == nil, let p = placemarks, !p.isEmpty {
                        self.placemark = p.last!
                    } else {
                        self.placemark = nil
                    }
                    self.performingRGC = false
                    self.updateLabels()
                    
                })}
            } else if distance < 1 {
                let timeInterval = newLocation.timestamp.timeIntervalSince(location!.timestamp)
                if timeInterval > 10 {
                    print("*** FORCE DONE! ***")
                    stopLocationManager()
                    updateLabels()
                    configureGetGPSButton()
                    
                }
            }
    }
    
    
    func updateLabels() {
        if let location = location {
            latitudeLabel.text = String(format: "%.8f", location.coordinate.latitude)
            longitudeLabel.text = String(format: "%.8f", location.coordinate.longitude)
            tagButton.isHidden = false
            messageLabel.text = ""
            if let placemark = placemark {
                addressLabel.text = string(from: placemark)
            } else if performingRGC {
                addressLabel.text = "Searching for Address..."
            } else if lastGeocodingErr != nil {
                addressLabel.text = "Error Finding Address"
            } else {
                addressLabel.text = "No Address Found"
            }
        } else {
            latitudeLabel.text = ""
            longitudeLabel.text = ""
            addressLabel.text = ""
            tagButton.isHidden = true
            messageLabel.text = "Tap 'Get my Location'"
            
            let statusMessage: String
            if let error = lastLocationError as? NSError {
                if error.domain == kCLErrorDomain &&
                    error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error getting location..."
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = "Tap 'Get GPS Coordinates' to Start"
            }
            messageLabel.text = statusMessage
        }
    }
    
    
    func string(from placemark: CLPlacemark) -> String {
        var line1 = ""
        if let s = placemark.subThoroughfare {
            line1 += s + " "
        }
        if let s = placemark.thoroughfare {
            line1 += s
        }
        var line2 = ""
        
        if let s = placemark.locality {
            line2 += s + " "
        }
        if let s = placemark.administrativeArea {
            line2 += s + " "
        }
        if let s = placemark.postalCode {
            line2 += s
        }
        
        return line1 + "\n" + line2
    }
    //MARK: -- interface instance properties 
    
    //MARK: -- labels
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    //MARK: -- buttons
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getGPSButton: UIButton!
    
    @IBAction func getLocation() {
        // do nothing so far 
        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil 
            placemark = nil
            lastGeocodingErr = nil
            startLocationManager()
        }
        
        configureGetGPSButton()
        updateLabels()
        
    }
    
    func configureGetGPSButton() {
        if updatingLocation {
            getGPSButton.setTitle("Stop", for: .normal)
        } else {
            getGPSButton.setTitle("Get GPS", for: .normal)
        }
    }
    
    
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled",
                                      message: "Please enable location services for this app in Settings.",
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK",
                                     style: .default,
                                     handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
        
    }
    
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateLabels()
        configureGetGPSButton()
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

