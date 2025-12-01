import SwiftUI

struct BodyDiagramView: View {
    let injuries: [Injury]
    let onRegionTapped: (BodyRegion) -> Void

    @State private var selectedRegion: BodyRegion?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerX = width / 2

            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Tap a body region to add or view injuries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Body diagram
                    ZStack {
                        // HEAD & NECK
                        bodyPart(
                            shape: Circle(),
                            x: centerX,
                            y: 60,
                            width: 50,
                            height: 50,
                            region: .neck,
                            label: "Neck"
                        )

                        // SHOULDERS
                        bodyPart(
                            shape: Capsule(),
                            x: centerX - 60,
                            y: 100,
                            width: 40,
                            height: 20,
                            region: .leftShoulder,
                            label: "L Shoulder"
                        )

                        bodyPart(
                            shape: Capsule(),
                            x: centerX + 60,
                            y: 100,
                            width: 40,
                            height: 20,
                            region: .rightShoulder,
                            label: "R Shoulder"
                        )

                        // UPPER BACK
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 10),
                            x: centerX,
                            y: 130,
                            width: 80,
                            height: 40,
                            region: .upperBack,
                            label: "Upper Back"
                        )

                        // CORE
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 10),
                            x: centerX,
                            y: 180,
                            width: 80,
                            height: 35,
                            region: .core,
                            label: "Core"
                        )

                        // LOWER BACK
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 10),
                            x: centerX,
                            y: 225,
                            width: 80,
                            height: 35,
                            region: .lowerBack,
                            label: "Lower Back"
                        )

                        // HIPS & GLUTES
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 8),
                            x: centerX - 40,
                            y: 270,
                            width: 35,
                            height: 40,
                            region: .leftHip,
                            label: "L Hip"
                        )

                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 8),
                            x: centerX + 40,
                            y: 270,
                            width: 35,
                            height: 40,
                            region: .rightHip,
                            label: "R Hip"
                        )

                        bodyPart(
                            shape: Circle(),
                            x: centerX - 40,
                            y: 285,
                            width: 30,
                            height: 30,
                            region: .leftGlute,
                            label: "L Glute"
                        )

                        bodyPart(
                            shape: Circle(),
                            x: centerX + 40,
                            y: 285,
                            width: 30,
                            height: 30,
                            region: .rightGlute,
                            label: "R Glute"
                        )

                        // QUADS
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 15),
                            x: centerX - 35,
                            y: 350,
                            width: 30,
                            height: 70,
                            region: .leftQuad,
                            label: "L Quad"
                        )

                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 15),
                            x: centerX + 35,
                            y: 350,
                            width: 30,
                            height: 70,
                            region: .rightQuad,
                            label: "R Quad"
                        )

                        // HAMSTRINGS (slightly behind quads visually)
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 15),
                            x: centerX - 38,
                            y: 350,
                            width: 25,
                            height: 70,
                            region: .leftHamstring,
                            label: "L Hamstring",
                            opacity: 0.7
                        )

                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 15),
                            x: centerX + 38,
                            y: 350,
                            width: 25,
                            height: 70,
                            region: .rightHamstring,
                            label: "R Hamstring",
                            opacity: 0.7
                        )

                        // KNEES
                        bodyPart(
                            shape: Circle(),
                            x: centerX - 35,
                            y: 395,
                            width: 25,
                            height: 25,
                            region: .leftKnee,
                            label: "L Knee"
                        )

                        bodyPart(
                            shape: Circle(),
                            x: centerX + 35,
                            y: 395,
                            width: 25,
                            height: 25,
                            region: .rightKnee,
                            label: "R Knee"
                        )

                        // SHINS
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 12),
                            x: centerX - 35,
                            y: 450,
                            width: 20,
                            height: 60,
                            region: .leftShin,
                            label: "L Shin"
                        )

                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 12),
                            x: centerX + 35,
                            y: 450,
                            width: 20,
                            height: 60,
                            region: .rightShin,
                            label: "R Shin"
                        )

                        // CALVES (slightly behind shins)
                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 12),
                            x: centerX - 37,
                            y: 450,
                            width: 18,
                            height: 60,
                            region: .leftCalf,
                            label: "L Calf",
                            opacity: 0.7
                        )

                        bodyPart(
                            shape: RoundedRectangle(cornerRadius: 12),
                            x: centerX + 37,
                            y: 450,
                            width: 18,
                            height: 60,
                            region: .rightCalf,
                            label: "R Calf",
                            opacity: 0.7
                        )

                        // ANKLES
                        bodyPart(
                            shape: Circle(),
                            x: centerX - 35,
                            y: 490,
                            width: 18,
                            height: 18,
                            region: .leftAnkle,
                            label: "L Ankle"
                        )

                        bodyPart(
                            shape: Circle(),
                            x: centerX + 35,
                            y: 490,
                            width: 18,
                            height: 18,
                            region: .rightAnkle,
                            label: "R Ankle"
                        )

                        // FEET
                        bodyPart(
                            shape: Capsule(),
                            x: centerX - 35,
                            y: 510,
                            width: 25,
                            height: 35,
                            region: .leftFoot,
                            label: "L Foot"
                        )

                        bodyPart(
                            shape: Capsule(),
                            x: centerX + 35,
                            y: 510,
                            width: 25,
                            height: 35,
                            region: .rightFoot,
                            label: "R Foot"
                        )
                    }
                    .frame(height: 550)
                }
                .padding()
            }
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
