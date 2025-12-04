import Foundation

/// Comprehensive database of rehab exercises organized by body region and type
class ExerciseDatabase {

    // MARK: - Exercise Library

    static let allExercises: [RehabExercise] = [
        // MARK: Foot & Ankle Exercises
        RehabExercise(
            name: "Calf Raises",
            type: .strengthening,
            description: "Strengthens calf muscles and Achilles tendon",
            duration: "3 sets of 15",
            targetRegions: [.leftCalf, .rightCalf, .leftAnkle, .rightAnkle],
            instructions: [
                "Stand with feet hip-width apart",
                "Rise up onto toes, lifting heels",
                "Hold for 2 seconds at top",
                "Lower slowly back down",
                "Progress to single-leg when ready"
            ]
        ),

        RehabExercise(
            name: "Ankle Circles",
            type: .mobilityDrill,
            description: "Improves ankle mobility and reduces stiffness",
            duration: "2 min each direction",
            targetRegions: [.leftAnkle, .rightAnkle],
            instructions: [
                "Sit or stand, lift one foot off ground",
                "Draw large circles with your toes",
                "10 circles clockwise",
                "10 circles counterclockwise",
                "Keep movement slow and controlled"
            ]
        ),

        RehabExercise(
            name: "Toe Towel Curls",
            type: .strengthening,
            description: "Strengthens intrinsic foot muscles and arch",
            duration: "3 sets of 10",
            targetRegions: [.leftFoot, .rightFoot],
            instructions: [
                "Place towel flat on floor",
                "Sit with foot on towel",
                "Use toes to scrunch towel toward you",
                "Release and repeat",
                "Add weight to towel for progression"
            ]
        ),

        RehabExercise(
            name: "Calf Foam Rolling",
            type: .foamRolling,
            description: "Releases tension in calf muscles",
            duration: "2 min per leg",
            targetRegions: [.leftCalf, .rightCalf],
            instructions: [
                "Sit on floor with foam roller under calf",
                "Lift hips off ground",
                "Roll from ankle to below knee",
                "Pause on tender spots for 20-30 sec",
                "Cross legs to increase pressure if needed"
            ]
        ),

        // MARK: Shin & Lower Leg
        RehabExercise(
            name: "Tibialis Anterior Stretch",
            type: .stretch,
            description: "Stretches shin muscles to prevent shin splints",
            duration: "30 sec per leg",
            targetRegions: [.leftShin, .rightShin],
            instructions: [
                "Kneel on ground with tops of feet flat",
                "Sit back on heels gently",
                "Feel stretch in front of shins",
                "Hold for 30 seconds",
                "Release slowly"
            ]
        ),

        RehabExercise(
            name: "Toe Walks",
            type: .strengthening,
            description: "Strengthens anterior tibialis and shin muscles",
            duration: "2 sets of 30 sec",
            targetRegions: [.leftShin, .rightShin],
            instructions: [
                "Stand tall on toes",
                "Walk forward on toes only",
                "Keep heels elevated entire time",
                "Maintain upright posture",
                "Rest and repeat"
            ]
        ),

        // MARK: Knee Exercises
        RehabExercise(
            name: "Wall Sits",
            type: .strengthening,
            description: "Strengthens quads and stabilizes knee joint",
            duration: "3 sets of 30-60 sec",
            targetRegions: [.leftKnee, .rightKnee, .leftQuad, .rightQuad],
            instructions: [
                "Stand with back against wall",
                "Slide down until thighs parallel to ground",
                "Keep knees behind toes",
                "Hold position for time",
                "Press back to stand"
            ]
        ),

        RehabExercise(
            name: "Terminal Knee Extensions",
            type: .resistanceBand,
            description: "Strengthens VMO muscle for knee stability",
            duration: "3 sets of 15",
            targetRegions: [.leftKnee, .rightKnee, .leftQuad, .rightQuad],
            instructions: [
                "Loop resistance band behind knee",
                "Stand facing anchor point",
                "Slightly bend knee",
                "Straighten knee fully against resistance",
                "Hold 2 sec, release slowly"
            ]
        ),

        RehabExercise(
            name: "Quad Foam Rolling",
            type: .foamRolling,
            description: "Releases tension in quadriceps muscles",
            duration: "2 min per leg",
            targetRegions: [.leftQuad, .rightQuad, .leftKnee, .rightKnee],
            instructions: [
                "Lie face down with roller under thigh",
                "Support weight on forearms",
                "Roll from hip to above knee",
                "Rotate leg slightly to hit different angles",
                "Spend extra time on tender spots"
            ]
        ),

        RehabExercise(
            name: "Quad Stretch",
            type: .stretch,
            description: "Lengthens quadriceps muscles",
            duration: "30 sec per leg",
            targetRegions: [.leftQuad, .rightQuad, .leftKnee, .rightKnee],
            instructions: [
                "Stand on one leg (use wall for balance)",
                "Bend opposite knee, grab ankle",
                "Pull heel toward glute",
                "Keep knees together",
                "Feel stretch in front of thigh"
            ]
        ),

        // MARK: Hamstring Exercises
        RehabExercise(
            name: "Nordic Hamstring Curls",
            type: .strengthening,
            description: "Eccentric strengthening for hamstring injury prevention",
            duration: "3 sets of 5-8",
            targetRegions: [.leftHamstring, .rightHamstring],
            instructions: [
                "Kneel with ankles anchored (partner or bench)",
                "Keep body straight from knees to head",
                "Lower torso slowly forward",
                "Control descent as long as possible",
                "Use hands to catch yourself, push back up"
            ]
        ),

        RehabExercise(
            name: "Standing Hamstring Stretch",
            type: .stretch,
            description: "Lengthens hamstring muscles",
            duration: "30 sec per leg",
            targetRegions: [.leftHamstring, .rightHamstring],
            instructions: [
                "Place heel on elevated surface",
                "Keep leg straight",
                "Hinge forward at hips",
                "Reach toward toes",
                "Feel stretch in back of thigh"
            ]
        ),

        RehabExercise(
            name: "Hamstring Foam Rolling",
            type: .foamRolling,
            description: "Releases tension in hamstring muscles",
            duration: "2 min per leg",
            targetRegions: [.leftHamstring, .rightHamstring],
            instructions: [
                "Sit with roller under back of thigh",
                "Hands support weight behind you",
                "Roll from below glute to above knee",
                "Cross legs to increase pressure",
                "Pause on tender areas"
            ]
        ),

        // MARK: Hip & Glute Exercises
        RehabExercise(
            name: "Clamshells",
            type: .resistanceBand,
            description: "Strengthens hip abductors and glute medius",
            duration: "3 sets of 15",
            targetRegions: [.leftHip, .rightHip, .leftGlute, .rightGlute],
            instructions: [
                "Lie on side with knees bent",
                "Place band above knees",
                "Keep feet together",
                "Open top knee against resistance",
                "Slowly close, repeat"
            ]
        ),

        RehabExercise(
            name: "Glute Bridges",
            type: .strengthening,
            description: "Strengthens glutes and posterior chain",
            duration: "3 sets of 15",
            targetRegions: [.leftGlute, .rightGlute, .leftHamstring, .rightHamstring],
            instructions: [
                "Lie on back, knees bent, feet flat",
                "Drive through heels",
                "Lift hips toward ceiling",
                "Squeeze glutes at top",
                "Lower slowly, repeat"
            ]
        ),

        RehabExercise(
            name: "Pigeon Pose",
            type: .stretch,
            description: "Deep hip and glute stretch",
            duration: "2 min per side",
            targetRegions: [.leftHip, .rightHip, .leftGlute, .rightGlute],
            instructions: [
                "Start in plank position",
                "Bring one knee forward, angle to side",
                "Extend back leg straight behind",
                "Lower hips toward ground",
                "Fold forward to deepen stretch"
            ]
        ),

        RehabExercise(
            name: "Hip Flexor Stretch",
            type: .stretch,
            description: "Opens up tight hip flexors",
            duration: "30 sec per side",
            targetRegions: [.leftHip, .rightHip],
            instructions: [
                "Kneel in lunge position",
                "Back knee on ground (use pad)",
                "Front knee at 90 degrees",
                "Push hips forward",
                "Feel stretch in front of back hip"
            ]
        ),

        RehabExercise(
            name: "Glute Foam Rolling",
            type: .foamRolling,
            description: "Releases tension in glute muscles",
            duration: "2 min per side",
            targetRegions: [.leftGlute, .rightGlute, .leftHip, .rightHip],
            instructions: [
                "Sit on foam roller",
                "Cross one ankle over opposite knee",
                "Shift weight toward crossed leg side",
                "Roll slowly back and forth",
                "Spend time on tender areas"
            ]
        ),

        // MARK: Lower Back Exercises
        RehabExercise(
            name: "Cat-Cow Stretch",
            type: .mobilityDrill,
            description: "Mobilizes spine and reduces lower back tension",
            duration: "2 min",
            targetRegions: [.lowerBack, .upperBack],
            instructions: [
                "Start on hands and knees",
                "Inhale: arch back, look up (cow)",
                "Exhale: round back, tuck chin (cat)",
                "Move slowly between positions",
                "Repeat for 10-15 cycles"
            ]
        ),

        RehabExercise(
            name: "Bird Dogs",
            type: .strengthening,
            description: "Strengthens core and lower back stabilizers",
            duration: "3 sets of 10 per side",
            targetRegions: [.lowerBack, .core],
            instructions: [
                "Start on hands and knees",
                "Extend opposite arm and leg",
                "Keep hips level, back flat",
                "Hold for 3 seconds",
                "Return to start, switch sides"
            ]
        ),

        RehabExercise(
            name: "Child's Pose",
            type: .stretch,
            description: "Gentle lower back and hip stretch",
            duration: "2 min",
            targetRegions: [.lowerBack, .leftGlute, .rightGlute],
            instructions: [
                "Kneel on ground",
                "Sit back on heels",
                "Reach arms forward on ground",
                "Rest forehead on floor",
                "Breathe deeply, relax"
            ]
        ),

        RehabExercise(
            name: "Lower Back Foam Rolling",
            type: .foamRolling,
            description: "Gentle release for lower back muscles",
            duration: "2 min",
            targetRegions: [.lowerBack],
            instructions: [
                "Lie on back with roller at lower back",
                "Cross arms over chest",
                "Lift hips slightly",
                "Roll gently side to side",
                "Avoid rolling directly on spine"
            ]
        ),

        // MARK: Core Exercises
        RehabExercise(
            name: "Dead Bug",
            type: .strengthening,
            description: "Core stability and control exercise",
            duration: "3 sets of 10",
            targetRegions: [.core, .lowerBack],
            instructions: [
                "Lie on back, arms up, knees bent at 90°",
                "Lower opposite arm and leg",
                "Keep lower back pressed to floor",
                "Return to start",
                "Alternate sides"
            ]
        ),

        RehabExercise(
            name: "Planks",
            type: .strengthening,
            description: "Builds overall core strength",
            duration: "3 sets of 30-60 sec",
            targetRegions: [.core, .lowerBack],
            instructions: [
                "Start on forearms and toes",
                "Keep body in straight line",
                "Engage core, squeeze glutes",
                "Don't let hips sag",
                "Breathe steadily, hold time"
            ]
        ),

        // MARK: Upper Back & Shoulders
        RehabExercise(
            name: "Thoracic Spine Foam Rolling",
            type: .foamRolling,
            description: "Mobilizes upper back",
            duration: "2 min",
            targetRegions: [.upperBack],
            instructions: [
                "Lie on back with roller under upper back",
                "Support head with hands",
                "Roll from mid-back to below neck",
                "Extend back over roller for extra stretch",
                "Avoid lower back"
            ]
        ),

        RehabExercise(
            name: "Shoulder Blade Squeezes",
            type: .strengthening,
            description: "Strengthens upper back and improves posture",
            duration: "3 sets of 15",
            targetRegions: [.upperBack, .leftShoulder, .rightShoulder],
            instructions: [
                "Sit or stand with arms at sides",
                "Pull shoulder blades together",
                "Squeeze for 3 seconds",
                "Release slowly",
                "Keep shoulders down"
            ]
        ),

        RehabExercise(
            name: "Band Pull-Aparts",
            type: .resistanceBand,
            description: "Strengthens rear deltoids and upper back",
            duration: "3 sets of 15",
            targetRegions: [.upperBack, .leftShoulder, .rightShoulder],
            instructions: [
                "Hold resistance band at chest height",
                "Arms straight in front",
                "Pull band apart to sides",
                "Squeeze shoulder blades",
                "Return to start slowly"
            ]
        ),

        RehabExercise(
            name: "Neck Stretches",
            type: .stretch,
            description: "Releases neck tension",
            duration: "30 sec per direction",
            targetRegions: [.neck],
            instructions: [
                "Sit or stand tall",
                "Tilt head to one side",
                "Gentle pull with hand for deeper stretch",
                "Hold 30 seconds",
                "Repeat other side, forward, and back"
            ]
        )
    ]

    // MARK: - Exercise Retrieval

    /// Get exercises recommended for a specific body region
    static func exercisesFor(region: BodyRegion, limit: Int = 6) -> [RehabExercise] {
        let matchingExercises = allExercises.filter { $0.targetRegions.contains(region) }

        // Diversify types
        var selected: [RehabExercise] = []
        let types: [ExerciseType] = [.stretch, .foamRolling, .strengthening, .resistanceBand, .mobilityDrill]

        for type in types {
            if let exercise = matchingExercises.first(where: { $0.type == type && !selected.contains($0) }) {
                selected.append(exercise)
            }
            if selected.count >= limit { break }
        }

        // Fill remaining with any matches
        for exercise in matchingExercises {
            if !selected.contains(exercise) {
                selected.append(exercise)
            }
            if selected.count >= limit { break }
        }

        return selected
    }

    /// Get additional exercises (for "generate more" feature)
    /// Note: excluding contains exercise names (not UUIDs) to prevent duplicates
    static func additionalExercisesFor(
        region: BodyRegion,
        excludingNames: [String],
        limit: Int = 4
    ) -> [RehabExercise] {
        let available = allExercises.filter {
            $0.targetRegions.contains(region) && !excludingNames.contains($0.name)
        }

        return Array(available.prefix(limit))
    }

    /// Search exercises by name or description
    static func searchExercises(query: String) -> [RehabExercise] {
        let lowercased = query.lowercased()
        return allExercises.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased)
        }
    }

    /// Get exercises by type
    static func exercisesByType(_ type: ExerciseType) -> [RehabExercise] {
        allExercises.filter { $0.type == type }
    }
}
