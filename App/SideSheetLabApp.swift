import SwiftUI
import MapKit

@main
struct SideSheetLabApp: App {
    var body: some Scene {
        WindowGroup {
            SideSheetLabView()
        }
    }
}

struct SideSheetLabView: View {
    private static let jerusalem = CLLocationCoordinate2D(latitude: 31.7768, longitude: 35.2345)
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: jerusalem,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.15)
        )
    )
    @State private var showingSheet = false
    @State private var selectedDetent: PresentationDetent = .medium

    private let tinyDetent: PresentationDetent = .height(155)
    private let arguments = ProcessInfo.processInfo.arguments

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Map(position: $camera) {
                    Marker("Old City", coordinate: Self.jerusalem)
                    Marker("Israel Museum", coordinate: CLLocationCoordinate2D(latitude: 31.7721, longitude: 35.2045))
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea()
                .accessibilityIdentifier("backgroundMap")

                VStack(alignment: .leading, spacing: 9) {
                    Label("NATIVE SHEET / iPadOS 27", systemImage: "map")
                        .font(.headline)
                    Text("Window: \(Int(geometry.size.width)) × \(Int(geometry.size.height)) pt")
                        .font(.subheadline.monospacedDigit())
                        .accessibilityIdentifier("windowDimensions")
                    Text("Behind the sheet: the map stays full-width.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showingSheet = true
                    } label: {
                        Label("Open side sheet", systemImage: "rectangle.portrait.on.rectangle.portrait")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("openSheetButton")
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(24)
            }
        }
        .sheet(isPresented: $showingSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("Jerusalem")
                                .font(.headline)
                            Text("Native SwiftUI presentation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        stateButton("Peek", value: tinyDetent)
                        stateButton("Half", value: .medium)
                        stateButton("Full", value: .large)
                    }
                    .accessibilityIdentifier("detentButtons")

                    if selectedDetent != tinyDetent {
                        Divider()
                        Label("Map remains interactive behind this sheet.", systemImage: "hand.draw")
                        Label("Drag the grabber to change sheet height.", systemImage: "arrow.up.and.down")
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .navigationTitle("Places")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingSheet = false }
                    }
                }
            }
            .presentationDetents([tinyDetent, .medium, .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            // This is the actual new iPadOS 27 SwiftUI system API:
            .presentationPlacement(.trailing)
        }
        .task {
            if let idx = arguments.firstIndex(of: "--detent"),
               arguments.indices.contains(idx + 1) {
                switch arguments[idx + 1] {
                case "peek": selectedDetent = tinyDetent
                case "full": selectedDetent = .large
                default: selectedDetent = .medium
                }
            }
            if !arguments.contains("--manual") {
                try? await Task.sleep(for: .milliseconds(450))
                showingSheet = true
            }
        }
    }

    @ViewBuilder
    private func stateButton(_ title: String, value: PresentationDetent) -> some View {
        Button(title) {
            withAnimation(.smooth) {
                selectedDetent = value
            }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
        .tint(selectedDetent == value ? .blue : .secondary)
        .accessibilityIdentifier("detent_\(title.lowercased())")
    }
}
