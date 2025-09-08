//
//  MusicManager.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import Foundation
import AVFoundation
import MediaPlayer

class MusicManager: ObservableObject {
    static let shared = MusicManager()
    
    @Published var isPlaying = false
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var musicKitAuthorized = false
    
    // Sound effect names
    private let successSounds = ["success", "victory", "cheer"]
    
    // Sound effect types
    enum SoundEffect {
        case levelUp
        case select
        case notification
        case success
        case newNotification
        
        var fileName: String {
            switch self {
            case .levelUp:
                return "cute-level-up-2-189851"
            case .select:
                return "select-sound-121244"
            case .notification:
                return "positive-notification-alert-351299"
            case .success:
                return "success-340660"
            case .newNotification:
                return "new-notification-09-352705"
            }
        }
    }
    
    // Load and prepare audio player
    private func preparePlayer(soundName: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("Sound file \(soundName) not found")
            return nil
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("Failed to create audio player: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Play a specific sound effect
    func playSound(_ effect: SoundEffect) {
        audioPlayers[effect.fileName] = preparePlayer(soundName: effect.fileName)
        
        if let player = audioPlayers[effect.fileName] {
            player.play()
            
            // Auto-stop after sound finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self] in
                self?.stopSound()
            }
        } else {
            print("Could not play sound effect: \(effect.fileName)")
        }
    }
    
    // Play a victory sound
    func playVictorySound() {
        // Select a random sound from the array
        let soundName = successSounds.randomElement() ?? "success"
        
        // Use embedded sound as fallback
        audioPlayers[soundName] = preparePlayer(soundName: soundName)
        
        // Only play if we have a valid player
        if let player = audioPlayers[soundName] {
            player.play()
            isPlaying = true
            
            // Stop after a short duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.stopSound()
            }
        } else {
            // Try the success sound effect as fallback
            playSound(.success)
        }
    }
    
    // Play level up sound
    func playLevelUp() {
        playSound(.levelUp)
    }
    
    // Play selection sound
    func playSelect() {
        playSound(.select)
    }
    
    // Play notification sound
    func playNotification() {
        playSound(.notification)
    }
    
    // Play celebration sound/music
    func playCelebration() {
        // First try Apple Music if authorized
        if musicKitAuthorized {
            playAppleMusicSong()
        } else {
            // Otherwise use embedded sounds
            playSound(.success)
        }
    }
    
    // Request MusicKit authorization
    func requestMusicAuthorization() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self?.musicKitAuthorized = true
                }
            }
        }
    }
    
    // Play a celebratory song from user's library
    func playAppleMusicSong() {
        guard musicKitAuthorized else {
            // Fallback to victory sound if not authorized
            playVictorySound()
            return
        }
        
        // Query for upbeat songs
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: MPMediaType.music.rawValue,
            forProperty: MPMediaItemPropertyMediaType
        ))
        
        // Get random song
        if let songs = query.items, !songs.isEmpty, 
           let randomSong = songs.randomElement() {
            let playerItem = MPMusicPlayerController.applicationMusicPlayer
            playerItem.setQueue(with: MPMediaItemCollection(items: [randomSong]))
            playerItem.play()
            isPlaying = true
            
            // Stop after a reasonable duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                self?.stopMusicPlayer()
            }
        } else {
            // Fallback to victory sound if no songs available
            playVictorySound()
        }
    }
    
    // Stop any playing sound
    func stopSound() {
        audioPlayers.values.forEach { $0.stop() }
        isPlaying = false
    }
    
    // Stop music player
    func stopMusicPlayer() {
        MPMusicPlayerController.applicationMusicPlayer.stop()
        isPlaying = false
    }
    
    // Initialize - request authorization on startup
    init() {
        requestMusicAuthorization()
    }
    
    // Reset music manager
    func reset() {
        stopSound()
        stopMusicPlayer()
    }
} 