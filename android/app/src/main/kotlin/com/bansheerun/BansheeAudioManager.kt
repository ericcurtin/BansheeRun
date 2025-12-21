package com.bansheerun

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.SoundPool
import android.os.Build
import android.os.Handler
import android.os.Looper

/**
 * Manages scary audio effects synchronized with visual banshee weather overlay.
 * Plays ambient music and triggered sound effects when the runner falls behind.
 */
class BansheeAudioManager(private val context: Context) {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var mediaPlayer: MediaPlayer? = null
    private var soundPool: SoundPool? = null
    private val handler = Handler(Looper.getMainLooper())

    // Sound IDs for SoundPool
    private var bansheeWailId = 0
    private var whispersId = 0
    private var heartbeatId = 0

    // Current state
    private var currentIntensity = 0f
    private var isPlaying = false
    private var hasAudioFocus = false

    // Cooldowns for sound effects (prevent spam)
    private var lastWailTime = 0L
    private var lastWhisperTime = 0L
    private var lastHeartbeatTime = 0L

    // Stream IDs for stopping sounds
    private var heartbeatStreamId = 0

    private val focusRequest: AudioFocusRequest by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setOnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS,
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            hasAudioFocus = false
                            pauseAudio()
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            hasAudioFocus = true
                            if (isPlaying) resumeAudio()
                        }
                    }
                }
                .build()
        } else {
            throw IllegalStateException("AudioFocusRequest requires API 26+")
        }
    }

    init {
        initializeSoundPool()
    }

    private fun initializeSoundPool() {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        soundPool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(attributes)
            .build()

        soundPool?.let { pool ->
            bansheeWailId = pool.load(context, R.raw.banshee_wail, 1)
            whispersId = pool.load(context, R.raw.whispers, 1)
            heartbeatId = pool.load(context, R.raw.heartbeat, 1)
        }
    }

    /**
     * Set the audio intensity (0.0 to 1.0) synchronized with visual effects.
     * This controls volume and triggers sound effects based on intensity level.
     */
    fun setIntensity(intensity: Float) {
        val clampedIntensity = intensity.coerceIn(0f, 1f)

        if (clampedIntensity > 0f && !isPlaying) {
            startAmbientMusic()
        } else if (clampedIntensity <= 0f && isPlaying) {
            stopScaryAudio()
            return
        }

        currentIntensity = clampedIntensity

        // Adjust ambient music volume
        mediaPlayer?.setVolume(clampedIntensity * 0.7f, clampedIntensity * 0.7f)

        // Trigger sound effects based on intensity thresholds
        val currentTime = System.currentTimeMillis()

        // Whispers at medium intensity (0.4+), cooldown 8 seconds
        if (clampedIntensity >= 0.4f && currentTime - lastWhisperTime > 8000) {
            playWhispers()
            lastWhisperTime = currentTime
        }

        // Heartbeat at higher intensity (0.6+), cooldown 5 seconds
        if (clampedIntensity >= 0.6f && currentTime - lastHeartbeatTime > 5000) {
            playHeartbeat()
            lastHeartbeatTime = currentTime
        }
    }

    /**
     * Play the banshee wail sound effect (for when significantly behind).
     * Has a 10-second cooldown to prevent spam.
     */
    fun playBansheeWail() {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastWailTime < 10000) return // 10 second cooldown

        lastWailTime = currentTime
        soundPool?.play(
            bansheeWailId,
            currentIntensity.coerceAtLeast(0.5f),
            currentIntensity.coerceAtLeast(0.5f),
            1,
            0,
            1.0f
        )
    }

    private fun playWhispers() {
        soundPool?.play(
            whispersId,
            currentIntensity * 0.6f,
            currentIntensity * 0.6f,
            1,
            0,
            1.0f
        )
    }

    private fun playHeartbeat() {
        // Stop previous heartbeat if still playing
        if (heartbeatStreamId != 0) {
            soundPool?.stop(heartbeatStreamId)
        }

        heartbeatStreamId = soundPool?.play(
            heartbeatId,
            currentIntensity * 0.8f,
            currentIntensity * 0.8f,
            1,
            0,  // no loop
            1.0f + (currentIntensity * 0.3f)  // speed up slightly with intensity
        ) ?: 0
    }

    private fun startAmbientMusic() {
        if (!requestAudioFocus()) return

        if (mediaPlayer == null) {
            mediaPlayer = MediaPlayer.create(context, R.raw.ambient_scary)?.apply {
                isLooping = true
                setVolume(0f, 0f)
            }
        }

        mediaPlayer?.let { player ->
            if (!player.isPlaying) {
                player.start()
                isPlaying = true
                // Fade in
                fadeVolume(0f, currentIntensity * 0.7f, 1000)
            }
        }
    }

    /**
     * Stop all scary audio with a fade out effect.
     */
    fun stopScaryAudio() {
        if (!isPlaying) return

        // Fade out then stop
        fadeVolume(currentIntensity * 0.7f, 0f, 500) {
            mediaPlayer?.pause()
            mediaPlayer?.seekTo(0)
            isPlaying = false
            currentIntensity = 0f
            abandonAudioFocus()

            // Stop any playing heartbeat
            if (heartbeatStreamId != 0) {
                soundPool?.stop(heartbeatStreamId)
                heartbeatStreamId = 0
            }
        }
    }

    private fun pauseAudio() {
        mediaPlayer?.pause()
    }

    private fun resumeAudio() {
        mediaPlayer?.start()
    }

    private fun fadeVolume(from: Float, to: Float, durationMs: Long, onComplete: (() -> Unit)? = null) {
        val steps = 20
        val stepDuration = durationMs / steps
        val volumeStep = (to - from) / steps

        var currentStep = 0
        var currentVolume = from

        val runnable = object : Runnable {
            override fun run() {
                if (currentStep < steps) {
                    currentVolume += volumeStep
                    mediaPlayer?.setVolume(currentVolume, currentVolume)
                    currentStep++
                    handler.postDelayed(this, stepDuration)
                } else {
                    mediaPlayer?.setVolume(to, to)
                    onComplete?.invoke()
                }
            }
        }
        handler.post(runnable)
    }

    private fun requestAudioFocus(): Boolean {
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.requestAudioFocus(focusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                { /* legacy callback */ },
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
        }
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return hasAudioFocus
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.abandonAudioFocusRequest(focusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus { /* legacy callback */ }
        }
        hasAudioFocus = false
    }

    /**
     * Release all resources. Call this when the activity/service is destroyed.
     */
    fun release() {
        stopScaryAudio()
        handler.removeCallbacksAndMessages(null)
        mediaPlayer?.release()
        mediaPlayer = null
        soundPool?.release()
        soundPool = null
    }
}
