import CoreLocation
import MapKit
import UIKit

class ViewController: UIViewController, MKMapViewDelegate {
    let locationManager = CLLocationManager()

    var first:MKPointAnnotation?
    var second:MKPointAnnotation?
    var circle:MKCircle?

    let diskStore = DiskStore()

    var regions:[Region] = [] {
        didSet {
            for region in oldValue {
                region.overlays.forEach({ mapView.removeOverlay($0) })
                region.annotations.forEach({ mapView.removeAnnotation($0) })
            }

            for region in regions {
                region.overlays.forEach({ mapView.addOverlay($0) })
                region.annotations.forEach({ mapView.addAnnotation($0) })
            }

            shareButton.enabled = (regions.count > 0)
            resetButton.enabled = (regions.count > 0)
            diskStore.save(regions)
        }

    }

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var firstButton: UIButton!
    @IBOutlet weak var secondButton: UIButton!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var resetButton: UIBarButtonItem!

    @IBAction func didTapFirstButton(sender: AnyObject) {
        if let coordinate = mapView.userLocation.location?.coordinate {
            replaceFirstWithCoordinate(coordinate)
        }
    }

    @IBAction func didTapSecondButton(sender: AnyObject) {
        if let coordinate = mapView.userLocation.location?.coordinate {
            replaceSecondWithCoordinate(coordinate)
        }
    }
    
    @IBAction func didTapDoneButton(sender: AnyObject) {
        if let first = first, second = second {
            let alert = UIAlertController(title: "Name This Region", message: nil, preferredStyle: .Alert)
            alert.addTextFieldWithConfigurationHandler({ (field) in

            })
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) in
                self.dismissViewControllerAnimated(true, completion: nil)

                if let title = alert.textFields?.first?.text {
                    let circle = CircularRegion(points:[first.coordinate, second.coordinate], title: title)
                    self.regions.append(circle)

                    self.resetCurrentRegion()
                }

            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: { (action) in
                self.dismissViewControllerAnimated(true, completion: nil)
            }))

            self.presentViewController(alert, animated: true, completion: nil)
        }
    }

    @IBAction func didTapResetButton(sender: AnyObject) {
        let alert = UIAlertController(title: "Rest All Data", message: "Are you sure you'd like to erase all local regions?", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .Default, handler: { (action) in
            self.dismissViewControllerAnimated(true, completion: nil)

            self.regions = []
            self.first = nil
            self.second = nil
            self.circle = nil
        }))

        alert.addAction(UIAlertAction(title: "No", style: .Cancel, handler: { (action) in
            self.dismissViewControllerAnimated(true, completion: nil)
        }))

        self.presentViewController(alert, animated: true, completion: nil)
    }

    @IBAction func didTapShareButton(sender: AnyObject) {
        let json = regionsAsJSON(self.regions)
        let activityViewController = UIActivityViewController(activityItems: [json as NSString], applicationActivities: nil)
        presentViewController(activityViewController, animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()

        mapView.showsUserLocation = true
        mapView.setUserTrackingMode(.FollowWithHeading, animated: true)

        regions = diskStore.load()
    }

    // -
    func replaceFirstWithCoordinate(coordinate:CLLocationCoordinate2D) {
        if let first = first {
            mapView.removeAnnotation(first)
        }

        first = MKPointAnnotation()
        if let first = first {
            first.coordinate = coordinate
            mapView.addAnnotation(first)

            recalculateCircle()
            recalculateDoneButton()
        }
    }

    func replaceSecondWithCoordinate(coordinate:CLLocationCoordinate2D) {
        if let second = second {
            mapView.removeAnnotation(second)
        }

        second = MKPointAnnotation()
        if let second = second {
            second.coordinate = coordinate
            mapView.addAnnotation(second)

            recalculateCircle()
            recalculateDoneButton()
        }
    }

    func resetCurrentRegion() {
        if let first = first, second = second {
            self.mapView.removeAnnotation(first)
            self.mapView.removeAnnotation(second)
        }

        if let circle = circle {
            self.mapView.removeAnnotation(circle)
            self.mapView.removeOverlay(circle)
        }

        self.first = nil
        self.second = nil
        self.circle = nil

        self.doneButton.enabled = false
    }

    func recalculateCircle() {
        if let first = first, second = second {
            if let circle = circle {
                mapView.removeOverlay(circle)
                mapView.removeAnnotation(circle)
            }

            circle = CircularRegion.circleFromPoints(first.coordinate, second.coordinate)

            if let circle = circle {
                circle.title = "Current Region"
                mapView.addOverlay(circle)
                mapView.addAnnotation(circle)
            }
        }
    }

    func recalculateDoneButton() {
        doneButton.enabled = (first != nil && second != nil)
    }

    //-
    // MKMapViewDelegate

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.isKindOfClass(MKPointAnnotation.self) || annotation.isKindOfClass(MKCircle.self) {
            let identifier = NSStringFromClass(MKPinAnnotationView.self)
            var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView
            if (pinView == nil) {
                pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }

            if annotation.isKindOfClass(MKCircle.self) {
                pinView?.pinTintColor = MKPinAnnotationView.greenPinColor()
                pinView?.canShowCallout = true

                let button = UIButton(type: .Custom)
                if let title = annotation.title {
                    if (title == "Current Region") {
                        button.setTitleColor(UIColor.redColor(), forState: .Normal)
                        button.tintColor = UIColor.redColor()
                        button.setTitle("X", forState: .Normal)
                    } else {
                        button.setTitleColor(self.view.tintColor, forState: .Normal)
                        button.setTitle("Edit", forState: .Normal)
                    }
                }
                button.sizeToFit()
                pinView?.rightCalloutAccessoryView = button
            } else {
                pinView?.pinTintColor = MKPinAnnotationView.redPinColor()
                pinView?.canShowCallout = false
                pinView?.rightCalloutAccessoryView = nil
            }
            
            return pinView
        }
        return nil
    }

    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKindOfClass(MKCircle.self) {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.fillColor = UIColor.cyanColor().colorWithAlphaComponent(0.2)
            renderer.strokeColor = UIColor.blueColor().colorWithAlphaComponent(0.7)
            renderer.lineWidth = 0.5;

            return renderer
        }

        // This case should never be reached, and fail silently.
        // But this function doesn't have a return type of Optional.
        // Obj-C interop is hard!
        return MKCircleRenderer()
    }

    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if (!view.annotation!.isKindOfClass(MKCircle.self)) { return }
            if let circle = view.annotation as? MKCircle {
                if let index = self.regions.indexOf({ $0.annotations == [circle] }) {
                    let region = self.regions[index]
                    self.regions.removeAtIndex(index)

                    self.circle = nil
                    replaceFirstWithCoordinate(region.points[0])
                    replaceSecondWithCoordinate(region.points[1])
                    self.title = region.title
                } else {
                    self.resetCurrentRegion()
                }
            }
        }
}

