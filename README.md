# Voxel Strides

## Hackathon MVP: Agentic Task Management 

Voxel Strides transforms daily tasks and long-term goals into a motivating, gamified adventure. This app combines a simple task manager with an AR companion that celebrates your achievements.

project demonstration video : https://drive.google.com/file/d/1R2gX26QWYrmgLlM8FiIhjL8kEeM993Fg/view?usp=sharing

## Project Structure

The project is organized into the following structure:

```
Voxel Strides/
├── App/                     # Core application files
│   ├── Voxel_StridesApp.swift
│   ├── ContentView.swift
│   └── LaunchScreen.swift
├── Models/                  # Data models
│   ├── Task.swift
│   └── Collectible.swift
├── Views/                   # UI components
│   └── Components/          # Reusable UI components
│       ├── NeonBackgroundView.swift
│       └── SettingsView.swift
├── Features/                # Feature modules
│   ├── Tasks/               # Task management features
│   │   ├── AddTaskView.swift
│   │   ├── TaskView.swift
│   │   ├── TaskVerificationView.swift
│   │   ├── TaskNLPAnalyzer.swift
│   │   └── TaskVerificationManager.swift
│   ├── AR/                  # Augmented Reality features
│   │   ├── ARCompanionView.swift
│   │   ├── CompanionUtility.swift
│   │   └── AnimatedCollectibleARView.swift
│   ├── Game/                # Game mechanics
│   │   ├── FocusQuestView.swift
│   │   ├── GamePathView.swift
│   │   └── StoreView.swift
│   ├── Collectibles/        # Collectibles system
│   │   ├── CollectiblesView.swift
│   │   └── CollectibleUnlockedView.swift
│   └── Planning/            # Planning and assistance agents
│       ├── PlanningAgent.swift
│       └── AccountabilityAgent.swift
├── Managers/                # Service managers
│   ├── MLModelManager.swift
│   ├── MusicManager.swift
│   └── CoinManager.swift
└── Utils/                   # Utilities and helpers
```

## Features

1. **Enhanced Task Management Engine**
   - Add, view, and complete tasks
   - Task categories with emoji presets (Exercise, Study, Health, Travel, etc.)
   - Priority levels (Low, Medium, High) with visual indicators
   - Custom color themes for each task
   - Notes support for detailed task information
   - Task list organized by completion status and priority
   - Overdue task highlighting and prioritization
   - Detailed task view with status information and editing capabilities

2. **"Focus Quest" Mode (Pomodoro Timer)**
   - Start a timed focus session for any task
   - Automatically marks task as complete when timer finishes
   - For demo purposes, timer is set to 10 seconds (would be 25 minutes in production)
   - Visual countdown with animations and haptic feedback

3. **AR Companion & Reward System**
   - After completing a task, launch the AR celebration view
   - AR companion appears in your environment and performs a celebratory animation
   - Different animations for completed vs. overdue tasks
   - Confetti effects and visual enhancements for better visibility
   - Companion shows disappointment for missed deadlines

4. **Progress Gamification**
   - Interactive Duolingo-style journey path
   - Character moves along the path as you complete tasks
   - Nodes light up and display stars for level completion
   - Treasure chest reward at journey's end

5. **Audio Celebrations**
   - Plays celebration sounds when tasks are completed
   - Integrates with Apple Music for customized rewards (when authorized)
   - Falls back to built-in sound effects

## Setup Instructions

### Prerequisites
- Xcode 15+ (Xcode 16 beta recommended for iOS 18)
- iOS device with ARKit support (for AR features)

### Adding the 3D Model
For the AR companion feature to work properly, you need to add a 3D model file:

1. Download a simple USDZ model or create one using Reality Composer
2. Name the file `companion.usdz`
3. Add it to your Xcode project by dragging it into the project navigator
4. Ensure "Copy items if needed" is checked
5. Add to target "Voxel Strides"

### Adding Sound Effects
For the audio celebration feature, add these sound files:
1. Add `success.mp3`, `victory.mp3`, and `cheer.mp3` to your project
2. Ensure they are included in the app bundle

### Running the App
1. Open `Voxel Strides.xcodeproj` in Xcode
2. Select your development team in project settings
3. Build and run on a device with ARKit support for the full experience

## Technologies Used
- SwiftUI for the user interface
- SwiftData for local data persistence
- AVFoundation and MediaPlayer for audio features
- Combine for timer management

