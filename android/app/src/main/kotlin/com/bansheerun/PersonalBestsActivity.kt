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

class PersonalBestsActivity : AppCompatActivity() {

    private lateinit var activityRepository: ActivityRepository
    private lateinit var adapter: PBAdapter
    private lateinit var recyclerView: RecyclerView
    private lateinit var emptyState: LinearLayout
    private lateinit var filterGroup: RadioGroup

    private var selectedType: BansheeLib.ActivityType = BansheeLib.ActivityType.RUN

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_personal_bests)

        supportActionBar?.title = "Personal Bests"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        activityRepository = ActivityRepository.getInstance(this)

        recyclerView = findViewById(R.id.pbRecyclerView)
        emptyState = findViewById(R.id.emptyState)
        filterGroup = findViewById(R.id.filterGroup)

        adapter = PBAdapter()
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        filterGroup.setOnCheckedChangeListener { _, checkedId ->
            selectedType = when (checkedId) {
                R.id.filterRun -> BansheeLib.ActivityType.RUN
                R.id.filterWalk -> BansheeLib.ActivityType.WALK
                R.id.filterCycle -> BansheeLib.ActivityType.CYCLE
                R.id.filterSkate -> BansheeLib.ActivityType.ROLLER_SKATE
                else -> BansheeLib.ActivityType.RUN
            }
            loadPBs()
        }

        loadPBs()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    private fun loadPBs() {
        val pbs = activityRepository.getPersonalBestsForType(selectedType)
        adapter.submitList(pbs)

        if (pbs.isEmpty()) {
            emptyState.visibility = View.VISIBLE
            recyclerView.visibility = View.GONE
        } else {
            emptyState.visibility = View.GONE
            recyclerView.visibility = View.VISIBLE
        }
    }

    inner class PBAdapter : RecyclerView.Adapter<PBAdapter.ViewHolder>() {
        private var pbs: List<PersonalBest> = emptyList()

        fun submitList(list: List<PersonalBest>) {
            pbs = list
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.pb_list_item, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(pbs[position])
        }

        override fun getItemCount(): Int = pbs.size

        inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val distanceBadge: TextView = itemView.findViewById(R.id.distanceBadge)
            private val time: TextView = itemView.findViewById(R.id.pbTime)
            private val pace: TextView = itemView.findViewById(R.id.pbPace)
            private val date: TextView = itemView.findViewById(R.id.pbDate)

            fun bind(pb: PersonalBest) {
                distanceBadge.text = pb.getDistanceName()
                time.text = pb.getFormattedTime()
                pace.text = pb.getFormattedPace()
                date.text = formatDate(pb.achievedAt)
            }

            private fun formatDate(epochMs: Long): String {
                val date = Date(epochMs)
                val formatter = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
                return formatter.format(date)
            }
        }
    }
}
