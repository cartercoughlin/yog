# RecoveryApp

A comprehensive iOS app for tracking athletic recovery, monitoring health metrics, managing training plans, and preventing injuries.

## Features

### 1. Recovery Dashboard
- **Dynamic Recovery Score**: Real-time calculation based on HRV, resting heart rate, sleep quality, and steps
- **Plant Visualization**: Engaging visual metaphor showing recovery state through plant growth
- **Health Metrics**: Detailed tracking of HRV, resting heart rate, sleep, and daily activity
- **Smart Recommendations**: Personalized workout suggestions based on current recovery state
- **Weekly Trends**: 7-day average tracking with visual trend indicators

### 2. Training Plans
- **VDOT-Based Pacing**: Scientifically-backed training zones using Jack Daniels' VDOT methodology
- **Multiple Plan Support**: Create and manage multiple training plans simultaneously
- **Race-Specific Training**: Customized plans for 5K, 10K, Half Marathon, and Marathon distances
- **Weekly Progression**: Structured weekly training with varied workout types
- **Progress Tracking**: Monitor completed workouts and plan adherence

### 3. Injury Tracker
- **Body Region Mapping**: Track injuries by specific body regions
- **Severity Levels**: Categorize injuries from mild to severe
- **Recovery Timeline**: Monitor injury duration and healing progress
- **Exercise Recommendations**: Suggested exercises for injury recovery and prevention
- **Active/Resolved Status**: Separate views for current and past injuries
- **Recovery Impact**: Visual indication of how injuries affect overall recovery score

### 4. History & Analytics
- **Recovery Score Trends**: Interactive charts showing recovery patterns over time
- **Workout History**: Detailed logs of all completed activities
- **Performance Metrics**: Track distance, duration, heart rate, and more
- **Time Range Filtering**: View data by week, month, or custom periods
- **Statistics Cards**: Quick-glance summaries of key metrics

## Design System

### Theme Architecture
The app uses a sophisticated dynamic theming system that adapts to recovery state:

- **Subtle Gradient Accents**: Minimal use of gradients in header areas for visual interest
- **Clean Backgrounds**: System-native backgrounds for optimal readability and battery efficiency
- **Material Design**: Strategic use of `.secondarySystemBackground` for cards and sections
- **Adaptive Colors**: Theme colors that reflect recovery state without overwhelming the interface

### Visual Design Principles
1. **Clarity Over Decoration**: Information-first design with subtle visual enhancements
2. **Hierarchy**: Clear visual hierarchy through typography and spacing
3. **Native Feel**: Follows iOS Human Interface Guidelines for familiar UX
4. **Accessibility**: High contrast ratios and system color support for dark mode

### Component System
- **RecoveryScoreCard**: Hero card with subtle gradient header and clean breakdown
- **MetricItem**: Uniform metric display with consistent iconography
- **AdaptiveCard**: Reusable card component with system background
- **PlantVisualization**: Animated plant growth with realistic spring physics

## Technical Stack

### Frameworks
- **SwiftUI**: Modern declarative UI framework
- **HealthKit**: Deep integration with Apple Health for accurate metrics
- **Charts**: Native Swift Charts for data visualization
- **WeatherKit**: Real-time weather data for training context

### Architecture
- **MVVM Pattern**: Clear separation of concerns with ViewModels
- **Environment Objects**: Shared state management for themes and injury data
- **Async/Await**: Modern concurrency for data loading and API calls
- **Codable**: Type-safe data persistence and serialization

### Key Services
- **HealthKitManager**: Centralized health data access and queries
- **TrainingPlanViewModel**: Training plan management and VDOT calculations
- **InjuryTrackerViewModel**: Injury tracking with recovery impact calculations
- **ThemeManager**: Dynamic theme updates based on recovery score

## Data Models

### Core Models
- **RecoveryData**: Comprehensive recovery score with breakdown by metric
- **HealthMetrics**: HRV, resting heart rate, sleep, and activity data
- **WorkoutData**: Detailed workout information with performance metrics
- **Injury**: Injury tracking with severity, region, and recovery exercises
- **TrainingPlan**: Structured training plans with VDOT-based pacing

## Setup & Requirements

### Requirements
- iOS 18.1+
- Xcode 16.0+
- HealthKit access permissions
- Optional: WeatherKit API key for weather features

### Installation
1. Clone the repository
2. Open `RecoveryApp.xcodeproj` in Xcode
3. Configure HealthKit capabilities in project settings
4. Build and run on device or simulator

### HealthKit Permissions
The app requests access to:
- Heart Rate Variability (HRV)
- Resting Heart Rate
- Sleep Analysis
- Step Count
- Workout Data

## Recent Updates

### UI/UX Refinements (December 2025)
- Removed full-screen gradients in favor of cleaner, more focused design
- Implemented subtle gradient accents in card headers only
- Improved visual hierarchy with better contrast and spacing
- Enhanced plant animation with realistic spring physics
- Adopted system backgrounds for better dark mode support
- Reduced visual noise while maintaining personality

### Plant Visualization Enhancement
- Multi-stage growth animation with scale, rotation, and opacity
- Pulsing glow effect for dynamic visual interest
- Spring-based reactions to score changes
- Smooth transitions between recovery states

## Future Enhancements
- Strava integration for automatic workout import
- Advanced analytics and predictive modeling
- Social features for team training
- Coach dashboard and athlete management
- Export functionality for training data

## License
MIT License - see LICENSE file for details
