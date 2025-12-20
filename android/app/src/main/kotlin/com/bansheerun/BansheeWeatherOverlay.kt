package com.bansheerun

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.sin
import kotlin.random.Random

/**
 * Full-screen overlay that displays eerie banshee-themed weather effects
 * (fog, mist, swirling particles) when the runner is falling behind.
 */
class BansheeWeatherOverlay @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val fogPaint = Paint().apply {
        isAntiAlias = true
    }

    private val particlePaint = Paint().apply {
        isAntiAlias = true
        color = Color.argb(180, 200, 200, 220)
    }

    private val mistPaint = Paint().apply {
        isAntiAlias = true
    }

    private data class FogLayer(
        var yOffset: Float,
        val speed: Float,
        val alpha: Int,
        val height: Float
    )

    private data class Particle(
        var x: Float,
        var y: Float,
        var vx: Float,
        var vy: Float,
        var size: Float,
        var alpha: Int,
        var phase: Float
    )

    private val fogLayers = mutableListOf<FogLayer>()
    private val particles = mutableListOf<Particle>()
    private var animationTime = 0f
    private var intensity = 0f
    private var targetIntensity = 0f

    private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 16L // ~60fps
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            animationTime += 0.016f
            updateAnimation()
            invalidate()
        }
    }

    private val intensityAnimator = ValueAnimator().apply {
        duration = 1000L
        interpolator = LinearInterpolator()
        addUpdateListener { animator ->
            intensity = animator.animatedValue as Float
        }
    }

    init {
        // Start with overlay hidden
        visibility = GONE
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w > 0 && h > 0) {
            initializeFogLayers()
            initializeParticles()
        }
    }

    private fun initializeFogLayers() {
        fogLayers.clear()
        val height = height.toFloat()

        // Create multiple fog layers with different speeds and opacities
        fogLayers.add(FogLayer(0f, 0.3f, 60, height * 0.4f))
        fogLayers.add(FogLayer(height * 0.2f, 0.5f, 45, height * 0.35f))
        fogLayers.add(FogLayer(height * 0.5f, 0.7f, 30, height * 0.3f))
        fogLayers.add(FogLayer(height * 0.7f, 0.4f, 50, height * 0.45f))
    }

    private fun initializeParticles() {
        particles.clear()
        val w = width.toFloat()
        val h = height.toFloat()

        // Create swirling mist particles
        repeat(80) {
            particles.add(
                Particle(
                    x = Random.nextFloat() * w,
                    y = Random.nextFloat() * h,
                    vx = Random.nextFloat() * 2f - 1f,
                    vy = Random.nextFloat() * 1.5f - 0.5f,
                    size = Random.nextFloat() * 20f + 10f,
                    alpha = Random.nextInt(40, 120),
                    phase = Random.nextFloat() * 6.28f
                )
            )
        }
    }

    private fun updateAnimation() {
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0 || h <= 0) return

        // Update fog layers - slow undulating movement
        for (layer in fogLayers) {
            layer.yOffset += layer.speed * intensity
            if (layer.yOffset > h) {
                layer.yOffset = -layer.height
            }
        }

        // Update particles - swirling ghost-like movement
        for (particle in particles) {
            // Add sinusoidal movement for eerie effect
            val swirl = sin(animationTime * 2f + particle.phase) * 1.5f
            particle.x += (particle.vx + swirl) * intensity
            particle.y += particle.vy * intensity

            // Wrap around screen
            if (particle.x < -particle.size) particle.x = w + particle.size
            if (particle.x > w + particle.size) particle.x = -particle.size
            if (particle.y < -particle.size) particle.y = h + particle.size
            if (particle.y > h + particle.size) particle.y = -particle.size
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (intensity <= 0.01f) return

        val w = width.toFloat()
        val h = height.toFloat()

        // Draw base dark overlay
        canvas.drawColor(Color.argb((30 * intensity).toInt(), 20, 30, 40))

        // Draw fog layers
        for (layer in fogLayers) {
            val gradient = LinearGradient(
                0f, layer.yOffset,
                0f, layer.yOffset + layer.height,
                intArrayOf(
                    Color.argb(0, 150, 160, 180),
                    Color.argb((layer.alpha * intensity).toInt(), 150, 160, 180),
                    Color.argb((layer.alpha * intensity).toInt(), 140, 150, 170),
                    Color.argb(0, 140, 150, 170)
                ),
                floatArrayOf(0f, 0.3f, 0.7f, 1f),
                Shader.TileMode.CLAMP
            )
            fogPaint.shader = gradient
            canvas.drawRect(0f, layer.yOffset, w, layer.yOffset + layer.height, fogPaint)
        }

        // Draw mist particles
        for (particle in particles) {
            val alpha = (particle.alpha * intensity).toInt()
            if (alpha > 0) {
                // Create radial gradient for soft particle look
                val gradient = android.graphics.RadialGradient(
                    particle.x, particle.y, particle.size,
                    Color.argb(alpha, 180, 190, 210),
                    Color.argb(0, 180, 190, 210),
                    Shader.TileMode.CLAMP
                )
                mistPaint.shader = gradient
                canvas.drawCircle(particle.x, particle.y, particle.size, mistPaint)
            }
        }

        // Draw edge vignette for more ominous feel
        drawVignette(canvas, w, h)
    }

    private fun drawVignette(canvas: Canvas, w: Float, h: Float) {
        val vignetteAlpha = (80 * intensity).toInt()
        if (vignetteAlpha <= 0) return

        // Top edge
        val topGradient = LinearGradient(
            0f, 0f, 0f, h * 0.3f,
            Color.argb(vignetteAlpha, 30, 40, 50),
            Color.argb(0, 30, 40, 50),
            Shader.TileMode.CLAMP
        )
        fogPaint.shader = topGradient
        canvas.drawRect(0f, 0f, w, h * 0.3f, fogPaint)

        // Bottom edge
        val bottomGradient = LinearGradient(
            0f, h * 0.7f, 0f, h,
            Color.argb(0, 30, 40, 50),
            Color.argb(vignetteAlpha, 30, 40, 50),
            Shader.TileMode.CLAMP
        )
        fogPaint.shader = bottomGradient
        canvas.drawRect(0f, h * 0.7f, w, h, fogPaint)

        // Left edge
        val leftGradient = LinearGradient(
            0f, 0f, w * 0.2f, 0f,
            Color.argb(vignetteAlpha, 30, 40, 50),
            Color.argb(0, 30, 40, 50),
            Shader.TileMode.CLAMP
        )
        fogPaint.shader = leftGradient
        canvas.drawRect(0f, 0f, w * 0.2f, h, fogPaint)

        // Right edge
        val rightGradient = LinearGradient(
            w * 0.8f, 0f, w, 0f,
            Color.argb(0, 30, 40, 50),
            Color.argb(vignetteAlpha, 30, 40, 50),
            Shader.TileMode.CLAMP
        )
        fogPaint.shader = rightGradient
        canvas.drawRect(w * 0.8f, 0f, w, h, fogPaint)
    }

    /**
     * Show the weather effects with a fade-in animation
     */
    fun show() {
        if (visibility != VISIBLE) {
            visibility = VISIBLE
            if (!animator.isRunning) {
                animator.start()
            }
        }
        animateIntensity(1f)
    }

    /**
     * Hide the weather effects with a fade-out animation
     */
    fun hide() {
        animateIntensity(0f)
    }

    private fun animateIntensity(target: Float) {
        if (targetIntensity == target) return
        targetIntensity = target

        intensityAnimator.cancel()
        intensityAnimator.setFloatValues(intensity, target)
        intensityAnimator.addListener(object : android.animation.AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: android.animation.Animator) {
                if (targetIntensity == 0f) {
                    visibility = GONE
                    animator.cancel()
                }
            }
        })
        intensityAnimator.start()
    }

    /**
     * Set the effect intensity directly (0.0 to 1.0)
     * Useful for varying intensity based on how far behind the runner is
     */
    fun setIntensity(value: Float) {
        val clampedValue = value.coerceIn(0f, 1f)
        if (clampedValue > 0f && visibility != VISIBLE) {
            visibility = VISIBLE
            if (!animator.isRunning) {
                animator.start()
            }
        }
        animateIntensity(clampedValue)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        animator.cancel()
        intensityAnimator.cancel()
    }
}
