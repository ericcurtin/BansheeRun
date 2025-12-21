package com.bansheerun

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.RadioGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ActivityListActivity : AppCompatActivity() {

    private lateinit var activityRepository: ActivityRepository
    private lateinit var adapter: ActivityAdapter
    private lateinit var recyclerView: RecyclerView
    private lateinit var emptyState: LinearLayout
    private lateinit var filterGroup: RadioGroup

    private var selectedFilter: BansheeLib.ActivityType? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_list)

        supportActionBar?.title = "Activities"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        activityRepository = ActivityRepository.getInstance(this)

        recyclerView = findViewById(R.id.activityRecyclerView)
        emptyState = findViewById(R.id.emptyState)
        filterGroup = findViewById(R.id.filterGroup)

        adapter = ActivityAdapter()
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        filterGroup.setOnCheckedChangeListener { _, checkedId ->
            selectedFilter = when (checkedId) {
                R.id.filterRun -> BansheeLib.ActivityType.RUN
                R.id.filterWalk -> BansheeLib.ActivityType.WALK
                R.id.filterCycle -> BansheeLib.ActivityType.CYCLE
                R.id.filterSkate -> BansheeLib.ActivityType.ROLLER_SKATE
                else -> null
            }
            loadActivities()
        }

        loadActivities()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    private fun loadActivities() {
        val activities = activityRepository.getActivities(selectedFilter)
        adapter.submitList(activities)

        if (activities.isEmpty()) {
            emptyState.visibility = View.VISIBLE
            recyclerView.visibility = View.GONE
        } else {
            emptyState.visibility = View.GONE
            recyclerView.visibility = View.VISIBLE
        }
    }

    inner class ActivityAdapter : RecyclerView.Adapter<ActivityAdapter.ViewHolder>() {
        private var activities: List<ActivitySummary> = emptyList()

        fun submitList(list: List<ActivitySummary>) {
            activities = list
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.activity_list_item, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(activities[position])
        }

        override fun getItemCount(): Int = activities.size

        inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val typeIcon: TextView = itemView.findViewById(R.id.activityTypeIcon)
            private val name: TextView = itemView.findViewById(R.id.activityName)
            private val distance: TextView = itemView.findViewById(R.id.activityDistance)
            private val duration: TextView = itemView.findViewById(R.id.activityDuration)
            private val pace: TextView = itemView.findViewById(R.id.activityPace)
            private val date: TextView = itemView.findViewById(R.id.activityDate)

            init {
                itemView.setOnClickListener {
                    if (adapterPosition != RecyclerView.NO_POSITION) {
                        val activity = activities[adapterPosition]
                        // Navigate to activity detail
                        val intent = android.content.Intent(this@ActivityListActivity, ActivityDetailActivity::class.java)
                        intent.putExtra("activity_id", activity.id)
                        startActivity(intent)
                    }
                }
            }

            fun bind(activity: ActivitySummary) {
                // Activity type icon
                val activityType = activity.getActivityTypeEnum()
                typeIcon.text = when (activityType) {
                    BansheeLib.ActivityType.RUN -> "\uD83C\uDFC3"
                    BansheeLib.ActivityType.WALK -> "\uD83D\uDEB6"
                    BansheeLib.ActivityType.CYCLE -> "\uD83D\uDEB4"
                    BansheeLib.ActivityType.ROLLER_SKATE -> "\u26F8\uFE0F"
                    else -> "\uD83C\uDFC3"
                }

                name.text = activity.name
                distance.text = BansheeLib.formatDistance(activity.totalDistanceMeters)
                    ?: String.format("%.2f km", activity.totalDistanceMeters / 1000.0)
                duration.text = BansheeLib.formatDuration(activity.durationMs)
                    ?: formatDuration(activity.durationMs)
                pace.text = BansheeLib.formatPace(activity.totalDistanceMeters, activity.durationMs)
                    ?: formatPace(activity.totalDistanceMeters, activity.durationMs)

                date.text = formatDate(activity.recordedAt)
            }

            private fun formatDuration(ms: Long): String {
                val totalSeconds = ms / 1000
                val minutes = totalSeconds / 60
                val seconds = totalSeconds % 60
                return String.format("%d:%02d", minutes, seconds)
            }

            private fun formatPace(distanceMeters: Double, durationMs: Long): String {
                if (distanceMeters <= 0) return "--:-- /km"
                val paceMs = (durationMs / (distanceMeters / 1000.0)).toLong()
                val paceMinutes = paceMs / 60000
                val paceSeconds = (paceMs % 60000) / 1000
                return String.format("%d:%02d /km", paceMinutes, paceSeconds)
            }

            private fun formatDate(epochMs: Long): String {
                val date = Date(epochMs)
                val formatter = SimpleDateFormat("MMM d", Locale.getDefault())
                return formatter.format(date)
            }
        }
    }
}
