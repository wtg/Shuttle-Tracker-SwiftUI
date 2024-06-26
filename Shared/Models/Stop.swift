//
//  Stop.swift
//  Shuttle Tracker
//
//  Created by Gabriel Jacoby-Cooper on 9/21/20.
//

import MapKit
import STLogging

class Stop: NSObject, Decodable, Identifiable, CustomAnnotation {
	
	enum CodingKeys: String, CodingKey {
		
		case name, coordinate
		
	}
	
	let name: String
	
	let coordinate: CLLocationCoordinate2D
	
	var location: CLLocation {
		get {
			return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
		}
	}
	
	var title: String? {
		get {
			return self.name
		}
	}
    #if !os(watchOS)
	@MainActor
	let annotationView: MKAnnotationView = {
		let annotationView = MKAnnotationView()
		annotationView.displayPriority = .defaultHigh
		annotationView.canShowCallout = true
		#if canImport(AppKit)
		annotationView.image = NSImage(systemSymbolName: SFSymbol.stop.systemName, accessibilityDescription: nil)?
			.withTintColor(.white)
		annotationView.layer?.borderColor = .black
		annotationView.layer?.borderWidth = 2
		annotationView.layer?.cornerRadius = annotationView.frame.width / 2
		#elseif canImport(UIKit) // canImport(AppKit)
		let image = UIImage(systemName: SFSymbol.stop.systemName)!
		let imageView = UIImageView(image: image)
		imageView.tintColor = .white
		imageView.layer.borderColor = UIColor.black.cgColor
		imageView.layer.borderWidth = 2
		imageView.layer.cornerRadius = imageView.frame.width / 2
		imageView.frame = imageView.frame.offsetBy(dx: imageView.frame.width / -2, dy: imageView.frame.height / -2)
		annotationView.addSubview(imageView)
		#endif // canImport(UIKit)
		return annotationView
	}()
    #endif
	
	@MainActor
	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.name = try container.decode(String.self, forKey: .name)
		self.coordinate = try container.decode(Coordinate.self, forKey: .coordinate).convertedForCoreLocation()
	}
	
}

extension Array where Element == Stop {
	
	static func download() async -> [Stop] {
		do {
			return try await API.readStops.perform(as: [Stop].self, onMainActor: true) // Stops must be decoded on the main thread because initializing the annotationView property indirectly invokes UIView’s main-thread-isolated init() initializer.
		} catch {
			await #log(system: Logging.system, category: .api, level: .error, "Failed to download stops: \(error, privacy: .public)")
			return []
		}
	}
	
}
