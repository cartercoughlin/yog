import SwiftUI

struct BodyDiagramView: View {
    let injuries: [Injury]
    let onRegionTapped: (BodyRegion) -> Void

    @State private var selectedRegion: BodyRegion?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Tap a body region to add or view injuries")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                // Front View
                VStack(spacing: 10) {
                    Text("Front View")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    frontViewDiagram
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Back View
                VStack(spacing: 10) {
                    Text("Back View")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    backViewDiagram
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    private var frontViewDiagram: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerX = width / 2

            ZStack {
                // HEAD & NECK
                bodyPart(
                    shape: Circle(),
                    x: centerX,
                    y: 40,
                    width: 45,
                    height: 45,
                    region: .neck,
                    label: "Neck"
                )

                // SHOULDERS
                bodyPart(
                    shape: Capsule(),
                    x: centerX - 55,
                    y: 75,
                    width: 38,
                    height: 18,
                    region: .leftShoulder,
                    label: "L Shoulder"
                )

                bodyPart(
                    shape: Capsule(),
                    x: centerX + 55,
                    y: 75,
                    width: 38,
                    height: 18,
                    region: .rightShoulder,
                    label: "R Shoulder"
                )

                // CORE
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX,
                    y: 110,
                    width: 75,
                    height: 50,
                    region: .core,
                    label: "Core"
                )

                // HIPS
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 8),
                    x: centerX - 37,
                    y: 165,
                    width: 32,
                    height: 35,
                    region: .leftHip,
                    label: "L Hip"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 8),
                    x: centerX + 37,
                    y: 165,
                    width: 32,
                    height: 35,
                    region: .rightHip,
                    label: "R Hip"
                )

                // QUADS
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 12),
                    x: centerX - 33,
                    y: 225,
                    width: 28,
                    height: 75,
                    region: .leftQuad,
                    label: "L Quad"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 12),
                    x: centerX + 33,
                    y: 225,
                    width: 28,
                    height: 75,
                    region: .rightQuad,
                    label: "R Quad"
                )

                // KNEES
                bodyPart(
                    shape: Circle(),
                    x: centerX - 33,
                    y: 275,
                    width: 26,
                    height: 26,
                    region: .leftKnee,
                    label: "L Knee"
                )

                bodyPart(
                    shape: Circle(),
                    x: centerX + 33,
                    y: 275,
                    width: 26,
                    height: 26,
                    region: .rightKnee,
                    label: "R Knee"
                )

                // SHINS
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX - 33,
                    y: 325,
                    width: 22,
                    height: 65,
                    region: .leftShin,
                    label: "L Shin"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX + 33,
                    y: 325,
                    width: 22,
                    height: 65,
                    region: .rightShin,
                    label: "R Shin"
                )

                // ANKLES
                bodyPart(
                    shape: Circle(),
                    x: centerX - 33,
                    y: 370,
                    width: 20,
                    height: 20,
                    region: .leftAnkle,
                    label: "L Ankle"
                )

                bodyPart(
                    shape: Circle(),
                    x: centerX + 33,
                    y: 370,
                    width: 20,
                    height: 20,
                    region: .rightAnkle,
                    label: "R Ankle"
                )

                // FEET
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 8),
                    x: centerX - 33,
                    y: 395,
                    width: 28,
                    height: 38,
                    region: .leftFoot,
                    label: "L Foot"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 8),
                    x: centerX + 33,
                    y: 395,
                    width: 28,
                    height: 38,
                    region: .rightFoot,
                    label: "R Foot"
                )
            }
            .frame(height: 430)
        }
    }

    private var backViewDiagram: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerX = width / 2

            ZStack {
                // NECK
                bodyPart(
                    shape: Circle(),
                    x: centerX,
                    y: 40,
                    width: 45,
                    height: 45,
                    region: .neck,
                    label: "Neck"
                )

                // SHOULDERS (back)
                bodyPart(
                    shape: Capsule(),
                    x: centerX - 55,
                    y: 75,
                    width: 38,
                    height: 18,
                    region: .leftShoulder,
                    label: "L Shoulder"
                )

                bodyPart(
                    shape: Capsule(),
                    x: centerX + 55,
                    y: 75,
                    width: 38,
                    height: 18,
                    region: .rightShoulder,
                    label: "R Shoulder"
                )

                // UPPER BACK
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX,
                    y: 105,
                    width: 75,
                    height: 35,
                    region: .upperBack,
                    label: "Upper Back"
                )

                // LOWER BACK
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX,
                    y: 145,
                    width: 75,
                    height: 35,
                    region: .lowerBack,
                    label: "Lower Back"
                )

                // GLUTES
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX - 37,
                    y: 185,
                    width: 32,
                    height: 35,
                    region: .leftGlute,
                    label: "L Glute"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX + 37,
                    y: 185,
                    width: 32,
                    height: 35,
                    region: .rightGlute,
                    label: "R Glute"
                )

                // HAMSTRINGS
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 12),
                    x: centerX - 33,
                    y: 235,
                    width: 28,
                    height: 70,
                    region: .leftHamstring,
                    label: "L Hamstring"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 12),
                    x: centerX + 33,
                    y: 235,
                    width: 28,
                    height: 70,
                    region: .rightHamstring,
                    label: "R Hamstring"
                )

                // KNEES (back)
                bodyPart(
                    shape: Circle(),
                    x: centerX - 33,
                    y: 282,
                    width: 24,
                    height: 24,
                    region: .leftKnee,
                    label: "L Knee"
                )

                bodyPart(
                    shape: Circle(),
                    x: centerX + 33,
                    y: 282,
                    width: 24,
                    height: 24,
                    region: .rightKnee,
                    label: "R Knee"
                )

                // CALVES
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX - 33,
                    y: 330,
                    width: 24,
                    height: 60,
                    region: .leftCalf,
                    label: "L Calf"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 10),
                    x: centerX + 33,
                    y: 330,
                    width: 24,
                    height: 60,
                    region: .rightCalf,
                    label: "R Calf"
                )

                // ANKLES (back)
                bodyPart(
                    shape: Circle(),
                    x: centerX - 33,
                    y: 372,
                    width: 20,
                    height: 20,
                    region: .leftAnkle,
                    label: "L Ankle"
                )

                bodyPart(
                    shape: Circle(),
                    x: centerX + 33,
                    y: 372,
                    width: 20,
                    height: 20,
                    region: .rightAnkle,
                    label: "R Ankle"
                )

                // FEET (back)
                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 8),
                    x: centerX - 33,
                    y: 397,
                    width: 28,
                    height: 38,
                    region: .leftFoot,
                    label: "L Foot"
                )

                bodyPart(
                    shape: RoundedRectangle(cornerRadius: 8),
                    x: centerX + 33,
                    y: 397,
                    width: 28,
                    height: 38,
                    region: .rightFoot,
                    label: "R Foot"
                )
            }
            .frame(height: 430)
        }
    }

    @ViewBuilder
    private func bodyPart<S: Shape>(
        shape: S,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        region: BodyRegion,
        label: String,
        opacity: Double = 1.0
    ) -> some View {
        let hasInjury = injuries.contains { $0.region == region && $0.isActive }
        let injurySeverity = injuries.first { $0.region == region && $0.isActive }?.severity

        Button {
            selectedRegion = region
            onRegionTapped(region)
        } label: {
            ZStack {
                shape
                    .fill(fillColor(for: region, hasInjury: hasInjury, severity: injurySeverity))
                    .opacity(opacity)
                    .frame(width: width, height: height)
                    .overlay(
                        shape
                            .stroke(strokeColor(for: region), lineWidth: 2)
                            .frame(width: width, height: height)
                    )

                if hasInjury, let severity = injurySeverity {
                    Image(systemName: severity.icon)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
        }
        .position(x: x, y: y)
        .buttonStyle(PlainButtonStyle())
    }

    private func fillColor(for region: BodyRegion, hasInjury: Bool, severity: InjurySeverity?) -> Color {
        if hasInjury, let severity = severity {
            return severity.color.opacity(0.7)
        }
        return selectedRegion == region ? Color.blue.opacity(0.3) : Color.blue.opacity(0.15)
    }

    private func strokeColor(for region: BodyRegion) -> Color {
        selectedRegion == region ? .blue : .gray.opacity(0.5)
    }
}

#Preview {
    BodyDiagramView(
        injuries: [
            Injury(
                region: .leftKnee,
                severity: .moderate,
                name: "Runner's Knee"
            ),
            Injury(
                region: .rightCalf,
                severity: .minor,
                name: "Calf Strain"
            )
        ],
        onRegionTapped: { _ in }
    )
}
