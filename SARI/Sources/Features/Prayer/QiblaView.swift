import SwiftUI
import CoreLocation

@MainActor
final class CompassStore: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {

    @Published var heading: Double = 0
    @Published var accuracy: Double = -1

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
    }

    func start() {
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        heading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading

        accuracy = newHeading.headingAccuracy
    }
}

struct QiblaView: View {

    @EnvironmentObject private var prayer: PrayerStore
    @StateObject private var compass = CompassStore()

    private var relative: Double {
        (prayer.qiblaBearing - compass.heading + 360)
            .truncatingRemainder(dividingBy: 360)
    }

    private var aligned: Bool {
        min(relative, 360 - relative) < 4
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SariDesign.mint.opacity(0.75),
                    Color(.systemBackground),
                    SariDesign.gold.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {

                VStack(spacing: 5) {
                    Text(
                        SariUIStrings.text(
                            "qibla",
                            SariLanguage.selected
                        )
                    )
                    .font(.largeTitle.bold())

                    Text(prayer.locationName)
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.9))
                        .shadow(
                            color: .black.opacity(0.08),
                            radius: 24,
                            y: 10
                        )

                    ForEach(0..<36, id: \.self) { i in
                        Capsule()
                            .fill(
                                i % 9 == 0
                                    ? Color.primary
                                    : Color.secondary.opacity(0.35)
                            )
                            .frame(
                                width: 2,
                                height: i % 9 == 0 ? 18 : 10
                            )
                            .offset(y: -145)
                            .rotationEffect(
                                .degrees(Double(i) * 10)
                            )
                    }

                    Image(systemName: "location.north.fill")
                        .font(
                            .system(
                                size: 72,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            aligned
                                ? Color.green
                                : SariDesign.emerald
                        )
                        .rotationEffect(.degrees(relative))

                    Circle()
                        .fill(Color.primary)
                        .frame(width: 10, height: 10)
                }
                .frame(
                    maxWidth: 320,
                    maxHeight: 320
                )
                .aspectRatio(
                    1,
                    contentMode: .fit
                )
                .padding(.horizontal, 12)

                VStack(spacing: 8) {
                    Text(
                        aligned
                            ? SariUIStrings.text(
                                "facing_qibla",
                                SariLanguage.selected
                            )
                            : SariUIStrings.text(
                                "move_phone_qibla",
                                SariLanguage.selected
                            )
                    )
                    .font(.title3.bold())

                    Text(
                        SariUIStrings.format(
                            "qibla_heading",
                            SariLanguage.selected,
                            [
                                "qibla":
                                    "\(Int(prayer.qiblaBearing.rounded()))",
                                "heading":
                                    "\(Int(compass.heading.rounded()))"
                            ]
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if compass.accuracy > 20 {
                        Label(
                            SariUIStrings.text(
                                "calibrate_compass",
                                SariLanguage.selected
                            ),
                            systemImage:
                                "iphone.gen3.radiowaves.left.and.right"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
                .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(22)
        }
        .environment(
            \.layoutDirection,
            SariLanguage.selected.isArabic
                ? .rightToLeft
                : .leftToRight
        )
        .onAppear {
            prayer.start()
            compass.start()
        }
        .onDisappear {
            compass.stop()
        }
    }
}