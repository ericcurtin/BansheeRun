import AVFoundation
import Foundation

/// Manages scary audio effects synchronized with visual banshee weather overlay.
/// Plays ambient music and triggered sound effects when the runner falls behind.
class BansheeAudioManager: ObservableObject {

    private var ambientPlayer: AVAudioPlayer?
    private var bansheeWailPlayer: AVAudioPlayer?
    private var whispersPlayer: AVAudioPlayer?
    private var heartbeatPlayer: AVAudioPlayer?

    @Published private(set) var isPlaying = false
    private var currentIntensity: Float = 0

    // Cooldowns for sound effects (prevent spam)
    private var lastWailTime: Date = .distantPast
    private var lastWhisperTime: Date = .distantPast
    private var lastHeartbeatTime: Date = .distantPast

    private var fadeTimer: Timer?

    init() {
        setupAudioSession()
        loadSounds()
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
        // macOS doesn't need explicit audio session setup
    }

    private func loadSounds() {
        // Load ambient scary music
        if let url = Bundle.main.url(forResource: "ambient_scary", withExtension: "mp3") {
            ambientPlayer = try? AVAudioPlayer(contentsOf: url)
            ambientPlayer?.numberOfLoops = -1  // Loop indefinitely
            ambientPlayer?.prepareToPlay()
        }

        // Load banshee wail
        if let url = Bundle.main.url(forResource: "banshee_wail", withExtension: "mp3") {
            bansheeWailPlayer = try? AVAudioPlayer(contentsOf: url)
            bansheeWailPlayer?.prepareToPlay()
        }

        // Load whispers
        if let url = Bundle.main.url(forResource: "whispers", withExtension: "mp3") {
            whispersPlayer = try? AVAudioPlayer(contentsOf: url)
            whispersPlayer?.prepareToPlay()
        }

        // Load heartbeat
        if let url = Bundle.main.url(forResource: "heartbeat", withExtension: "mp3") {
            heartbeatPlayer = try? AVAudioPlayer(contentsOf: url)
            heartbeatPlayer?.prepareToPlay()
        }
    }

    /// Set the audio intensity (0.0 to 1.0) synchronized with visual effects.
    /// This controls volume and triggers sound effects based on intensity level.
    func setIntensity(_ intensity: Float) {
        let clampedIntensity = min(max(intensity, 0), 1)

        if clampedIntensity > 0 && !isPlaying {
            startAmbientMusic()
        } else if clampedIntensity <= 0 && isPlaying {
            stopScaryAudio()
            return
        }

        currentIntensity = clampedIntensity

        // Adjust ambient music volume
        ambientPlayer?.volume = clampedIntensity * 0.7

        // Trigger sound effects based on intensity thresholds
        let now = Date()

        // Whispers at medium intensity (0.4+), cooldown 8 seconds
        if clampedIntensity >= 0.4 && now.timeIntervalSince(lastWhisperTime) > 8 {
            playWhispers()
            lastWhisperTime = now
        }

        // Heartbeat at higher intensity (0.6+), cooldown 5 seconds
        if clampedIntensity >= 0.6 && now.timeIntervalSince(lastHeartbeatTime) > 5 {
            playHeartbeat()
            lastHeartbeatTime = now
        }
    }

    /// Play the banshee wail sound effect (for when significantly behind).
    /// Has a 10-second cooldown to prevent spam.
    func playBansheeWail() {
        let now = Date()
        guard now.timeIntervalSince(lastWailTime) >= 10 else { return }

        lastWailTime = now
        bansheeWailPlayer?.volume = max(currentIntensity, 0.5)
        bansheeWailPlayer?.currentTime = 0
        bansheeWailPlayer?.play()
    }

    private func playWhispers() {
        whispersPlayer?.volume = currentIntensity * 0.6
        whispersPlayer?.currentTime = 0
        whispersPlayer?.play()
    }

    private func playHeartbeat() {
        heartbeatPlayer?.volume = currentIntensity * 0.8
        heartbeatPlayer?.enableRate = true
        heartbeatPlayer?.rate = 1.0 + (currentIntensity * 0.3)
        heartbeatPlayer?.currentTime = 0
        heartbeatPlayer?.play()
    }

    private func startAmbientMusic() {
        guard let player = ambientPlayer else { return }

        player.volume = 0
        player.play()
        isPlaying = true

        // Fade in
        fadeVolume(from: 0, to: currentIntensity * 0.7, duration: 1.0)
    }

    /// Stop all scary audio with a fade out effect.
    func stopScaryAudio() {
        guard isPlaying else { return }

        fadeVolume(from: ambientPlayer?.volume ?? 0, to: 0, duration: 0.5) { [weak self] in
            self?.ambientPlayer?.pause()
            self?.ambientPlayer?.currentTime = 0
            self?.isPlaying = false
            self?.currentIntensity = 0

            // Stop other sounds
            self?.heartbeatPlayer?.stop()
            self?.whispersPlayer?.stop()
            self?.bansheeWailPlayer?.stop()
        }
    }

    private func fadeVolume(from: Float, to: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()

        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = (to - from) / Float(steps)

        var currentStep = 0
        var currentVolume = from

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            currentStep += 1
            currentVolume += volumeStep
            self?.ambientPlayer?.volume = currentVolume

            if currentStep >= steps {
                timer.invalidate()
                self?.ambientPlayer?.volume = to
                completion?()
            }
        }
    }

    deinit {
        fadeTimer?.invalidate()
        ambientPlayer?.stop()
        bansheeWailPlayer?.stop()
        whispersPlayer?.stop()
        heartbeatPlayer?.stop()
    }
}
