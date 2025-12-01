import SwiftUI

struct BodyMannequinView: View {
    @ObservedObject var viewModel: InjuryViewModel
    @Binding var selectedLocation: BodyLocation?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Body outline
                bodyOutline
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.9)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)

                // Pain indicators for each injured location
                ForEach(viewModel.affectedBodyLocations, id: \.self) { location in
                    if let injury = viewModel.mostSevereInjury(at: location) {
                        PainIndicator(
                            location: location,
                            severity: injury.severity,
                            isSelected: selectedLocation == location
                        )
                        .position(
                            x: geometry.size.width * location.mannequinPosition.x,
                            y: geometry.size.height * location.mannequinPosition.y
                        )
                        .onTapGesture {
                            selectedLocation = location
                        }
                    }
                }
            }
        }
    }

    // Simplified body outline path
    private var bodyOutline: some Shape {
        BodyOutlinePath()
    }
}

// MARK: - Body Outline Path
struct BodyOutlinePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let centerX = width / 2

        // Head (circle)
        path.addEllipse(in: CGRect(
            x: centerX - width * 0.12,
            y: height * 0.05,
            width: width * 0.24,
            height: height * 0.08
        ))

        // Neck
        path.move(to: CGPoint(x: centerX - width * 0.06, y: height * 0.13))
        path.addLine(to: CGPoint(x: centerX - width * 0.06, y: height * 0.17))
        path.move(to: CGPoint(x: centerX + width * 0.06, y: height * 0.13))
        path.addLine(to: CGPoint(x: centerX + width * 0.06, y: height * 0.17))

        // Shoulders
        path.move(to: CGPoint(x: centerX - width * 0.3, y: height * 0.20))
        path.addLine(to: CGPoint(x: centerX + width * 0.3, y: height * 0.20))

        // Torso
        path.move(to: CGPoint(x: centerX - width * 0.25, y: height * 0.20))
        path.addLine(to: CGPoint(x: centerX - width * 0.25, y: height * 0.48))
        path.move(to: CGPoint(x: centerX + width * 0.25, y: height * 0.20))
        path.addLine(to: CGPoint(x: centerX + width * 0.25, y: height * 0.48))

        // Left arm
        path.move(to: CGPoint(x: centerX - width * 0.30, y: height * 0.20))
        path.addLine(to: CGPoint(x: centerX - width * 0.35, y: height * 0.32))
        path.addLine(to: CGPoint(x: centerX - width * 0.38, y: height * 0.42))
        path.addLine(to: CGPoint(x: centerX - width * 0.40, y: height * 0.48))

        // Right arm
        path.move(to: CGPoint(x: centerX + width * 0.30, y: height * 0.20))
        path.addLine(to: CGPoint(x: centerX + width * 0.35, y: height * 0.32))
        path.addLine(to: CGPoint(x: centerX + width * 0.38, y: height * 0.42))
        path.addLine(to: CGPoint(x: centerX + width * 0.40, y: height * 0.48))

        // Hips
        path.move(to: CGPoint(x: centerX - width * 0.25, y: height * 0.48))
        path.addLine(to: CGPoint(x: centerX + width * 0.25, y: height * 0.48))

        // Left leg
        path.move(to: CGPoint(x: centerX - width * 0.15, y: height * 0.48))
        path.addLine(to: CGPoint(x: centerX - width * 0.15, y: height * 0.68))
        path.addLine(to: CGPoint(x: centerX - width * 0.15, y: height * 0.88))
        path.addLine(to: CGPoint(x: centerX - width * 0.15, y: height * 0.95))

        // Right leg
        path.move(to: CGPoint(x: centerX + width * 0.15, y: height * 0.48))
        path.addLine(to: CGPoint(x: centerX + width * 0.15, y: height * 0.68))
        path.addLine(to: CGPoint(x: centerX + width * 0.15, y: height * 0.88))
        path.addLine(to: CGPoint(x: centerX + width * 0.15, y: height * 0.95))

        return path
    }
}

// MARK: - Pain Indicator
struct PainIndicator: View {
    let location: BodyLocation
    let severity: PainSeverity
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Outer ring for selected state
            if isSelected {
                Circle()
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 32, height: 32)
            }

            // Pain indicator circle
            Circle()
                .fill(severityColor.opacity(0.8))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(severityColor, lineWidth: 2)
                )
                .shadow(color: severityColor.opacity(0.5), radius: 4)

            // Severity number
            Text("\(severity.numericValue)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var severityColor: Color {
        switch severity.color {
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @StateObject var viewModel = InjuryViewModel()
        @State var selectedLocation: BodyLocation? = nil

        var body: some View {
            VStack {
                BodyMannequinView(viewModel: viewModel, selectedLocation: $selectedLocation)
                    .frame(height: 500)
                    .padding()

                if let selected = selectedLocation {
                    Text("Selected: \(selected.displayName)")
                        .padding()
                }

                Button("Load Sample Data") {
                    viewModel.loadSampleData()
                }
            }
            .onAppear {
                viewModel.loadSampleData()
            }
        }
    }

    return PreviewWrapper()
}
