import SwiftUI
import MapKit


struct MapView: View {
    @State private var showSheet = false
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D.RensselaerUnion,
        span: MKCoordinateSpan(
            latitudeDelta: 0.02,
            longitudeDelta: 0.02
        )
    )
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        // Wrap the coordinate in MapCameraPosition
        ZStack {
            Map(position: .constant(.region(region))) {
                // Add markers here if needed
                UserAnnotation()
            }
            ScheduleAndETA()
            
        }
        
    }
    
    
    
    
}

#Preview {
    MapView()
}

