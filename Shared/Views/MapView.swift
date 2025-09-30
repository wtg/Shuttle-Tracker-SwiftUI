import SwiftUI
import MapKit

struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 42.730216326401114,
            longitude: -73.67568961656735
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 0.02,
            longitudeDelta: 0.02
        )
    )
    
    var body: some View {
        // Wrap the coordinate in MapCameraPosition
        Map(position: .constant(.region(region))) {
            // Add markers here if needed
        }
        .ignoresSafeArea()
    }
}

#Preview {
    MapView()
}
