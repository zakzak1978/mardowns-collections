# Kafka Dashboard Metrics Guide for Developers

## Purpose
This guide explains each Kafka dashboard metric in first-time developer language for Strimzi Kafka on AKS.

## Core Kafka Terms (Read This First)

### Topic
A **topic** is a named stream of messages (for example: `orders`, `payments`, `notifications`).

- Producers write messages to a topic.
- Consumers read messages from a topic.
- A topic is not one single queue; it is split into partitions for scale and parallel processing.

How topics are partitioned:
1. A topic is created with `N` partitions.
2. Each message is assigned to one partition.
3. If a message has a key, Kafka hashes the key and routes messages with the same key to the same partition.
4. Ordering is guaranteed **within a partition**, not across the whole topic.
5. Consumer groups process partitions in parallel (up to one active consumer per partition).

Example (topic partitioning):
- Topic: `orders`
- Partitions: `orders-0`, `orders-1`, `orders-2`, `orders-3`
- Message key `customer-42` is consistently mapped to one partition (for example `orders-2`).
- All events for `customer-42` stay ordered inside `orders-2`.
- Another key like `customer-99` may map to `orders-1` and be processed in parallel.

### Partition
A **partition** is one ordered log segment of a topic.

- Each partition has one leader and zero or more follower replicas.
- Kafka ordering is guaranteed per partition.
- More partitions usually means more consumer parallelism and higher throughput potential.

### In-Sync Replica (ISR)
**ISR (In-Sync Replicas)** is the set of replicas (leader + followers) that are sufficiently caught up with the leader.

- If ISR drops, write safety is reduced.
- If ISR drops below `min.insync.replicas`, producers using stronger acknowledgement settings may fail writes.

Example:
- Replication factor = `3` (1 leader + 2 followers), `min.insync.replicas = 2`.
- Healthy: all 3 replicas are in-sync.
- Unhealthy: only 1 replica remains in-sync -> partition is under min ISR.

### Fenced Broker
A **fenced broker** is a broker Kafka has marked as unsafe/stale for leadership participation.

- Kafka fences it to protect cluster consistency and avoid split-brain behavior.
- Fenced brokers should be treated as control-plane health issues, not just application issues.

### Message Ingress per Second by Broker
**Message ingress per second by broker** is how many messages per second each broker receives from producers.

- In dashboards, this corresponds to `Messages In/s by Broker`.
- Use it to detect broker hotspots and load imbalance.

Example:
- 3-broker cluster receives about 30k msg/s total.
- Healthy distribution: ~9k / 10k / 11k msg/s.
- Unhealthy distribution: ~24k / 3k / 3k msg/s for long periods, usually indicating partition leadership skew.

## Standard 7-Part Pattern (Used for Every Metric)
Each metric entry below follows this exact order:
1. **Metric name**
2. **Metrics used**
3. **What is that metric**
4. **Why it is used**
5. **Why it matters**
6. **Quick rule**
7. **What should be ideal (with examples)**

## Dashboard Flow (L1 to L2)
1. **Kafka Platform Overview (`kafka-fresh-overview.json`)**: cluster health, safety, and saturation.
2. **Kafka Topics Deep Dive (`kafka-topics-deep-dive.json`)**: topic and consumer-group behavior.
3. **Kafka Cruise Control Ops (`kafka-cruise-control-ops.json`)**: rebalance readiness and execution risk.

## Shared Variables (Filter Strategy)
- `namespace`: Focus one environment (dev/test/prod).
- `broker_pod`: Isolate one broker for hotspot analysis.
- `exporter_instance`: Remove duplicate scrape targets.
- `topic`: Focus one workload stream.
- `consumergroup`: Isolate one service backlog.
- `cc_pod`: Focus one Cruise Control instance.

---

## 1) Kafka Platform Overview (L1)
**Operational question:** Is the cluster healthy and safe to serve traffic?

### 1.1 Active Controllers
- **Metric name:** Active Controllers
- **Metrics used:** `kafka_controller_kafkacontroller_activecontrollercount`
- **What is that metric:** Number of currently active KRaft controllers.
- **Why it is used:** Kafka should have one active controller in steady state.
- **Why it matters:** Controller instability causes metadata and leadership instability.
- **Quick rule:** If value is not `1` for more than a brief transition, pause risky changes and investigate control plane.
- **What should be ideal (with examples):**
  - Ideal: exactly `1`.
  - Example: 3-node KRaft quorum in normal operation.
  - Healthy: value stays at `1` continuously.
  - Unhealthy: value flips `0 -> 1 -> 0` or becomes `2`; treat as control-plane incident.

### 1.2 Online Brokers
- **Metric name:** Online Brokers
- **Metrics used:** `kafka_server_replicamanager_partitioncount` (count by pod)
- **What is that metric:** Number of brokers currently reporting partition activity.
- **Why it is used:** Confirms expected broker availability.
- **Why it matters:** Missing brokers reduce fault tolerance and can trigger replication stress.
- **Quick rule:** If online count is below expected broker replicas, investigate broker pod/node state before app tuning.
- **What should be ideal (with examples):**
  - Ideal: matches expected broker count.
  - Example: cluster has 3 broker pods.
  - Healthy: panel shows `3` consistently.
  - Unhealthy: panel drops to `2`; check crashed pod, node pressure, or scheduling issues.

### 1.3 Under-Replicated Partitions
- **Metric name:** Under-Replicated Partitions
- **Metrics used:** `kafka_server_replicamanager_underreplicatedpartitions`
- **What is that metric:** Number of partitions where replicas are not fully in sync.
- **Why it is used:** Direct durability and fault-tolerance risk indicator.
- **Why it matters:** While this is non-zero, Kafka has reduced fault tolerance; another broker failure can increase downtime and data-loss risk.
- **Quick rule:** If this is `>0` and not dropping quickly, treat it as a platform health issue first (broker/network/disk), not an application code issue.
- **What should be ideal (with examples):**
  - Ideal: `0`.
  - Example: replication factor = `3` (1 leader + 2 followers).
  - Healthy: all 3 are caught up -> not under-replicated.
  - Unhealthy: only 2 are caught up, 1 is lagging/offline -> that partition is counted as under-replicated.

### 1.4 Offline Partitions
- **Metric name:** Offline Partitions
- **Metrics used:** `kafka_controller_kafkacontroller_offlinepartitionscount`
- **What is that metric:** Number of partitions with no active leader.
- **Why it is used:** Shows immediate read/write availability failure risk.
- **Why it matters:** Any offline partition can directly break producer/consumer flows.
- **Quick rule:** Any value `>0` is incident-level; prioritize broker/leadership recovery over feature debugging.
- **What should be ideal (with examples):**
  - Ideal: `0`.
  - Example: topic has 12 partitions.
  - Healthy: all 12 partitions have active leaders.
  - Unhealthy: partition 7 has no leader -> writes/reads to that partition fail until recovered.

### 1.5 Under Min ISR
- **Metric name:** Under Min ISR
- **Metrics used:** `kafka_server_replicamanager_underminisrpartitioncount`
- **What is that metric:** Partitions currently below configured `min.insync.replicas`.
- **Why it is used:** Indicates reduced write safety.
- **Why it matters:** If acks require ISR guarantees, writes may fail or become unsafe depending on client settings.
- **Quick rule:** If value rises above `0`, reduce producer pressure and investigate broker/network health.
- **What should be ideal (with examples):**
  - Ideal: `0`.
  - Example: replication factor = `3`, `min.insync.replicas = 2`.
  - Healthy: each partition has at least 2 in-sync replicas.
  - Unhealthy: a partition drops to ISR = 1 -> counted as under-min-ISR.

### 1.6 Fenced Brokers
- **Metric name:** Fenced Brokers
- **Metrics used:** `kafka_controller_kafkacontroller_fencedbrokercount`
- **What is that metric:** Brokers fenced from leadership participation.
- **Why it is used:** Detects control-plane and broker state safety violations.
- **Why it matters:** Fenced brokers reduce cluster flexibility and can indicate severe coordination issues.
- **Quick rule:** Non-zero fenced brokers should trigger immediate platform checks before load increases or releases.
- **What should be ideal (with examples):**
  - Ideal: `0`.
  - Example: broker restarts with stale epoch handling.
  - Healthy: broker rejoins without being fenced.
  - Unhealthy: fenced count stays at `1` -> investigate broker identity/state mismatch.

### 1.7 Cluster Throughput (Bytes/s)
- **Metric name:** Cluster Throughput (Bytes/s)
- **Metrics used:** `kafka_server_brokertopicmetrics_bytesin_total`, `kafka_server_brokertopicmetrics_bytesout_total`
- **What is that metric:** Aggregate inbound/outbound traffic volume trend.
- **Why it is used:** Validates traffic shape and release impact.
- **Why it matters:** Unexpected spikes/drops often reveal producer bugs, consumer stalls, or routing errors.
- **Quick rule:** Compare current throughput with known baseline for same hour/day before concluding incident.
- **What should be ideal (with examples):**
  - Ideal: predictable pattern aligned with business traffic.
  - Example: daytime load higher than nighttime load.
  - Healthy: smooth recurring curve across weekdays.
  - Unhealthy: sudden 3x byte-in spike after deployment with no business event.

### 1.8 Messages In/s by Broker
- **Metric name:** Messages In/s by Broker
- **Metrics used:** `kafka_server_brokertopicmetrics_messagesin_total` (rate by pod)
- **What is that metric:** Producer message ingress rate per broker.
- **Why it is used:** Detects broker-level load imbalance.
- **Why it matters:** Persistent imbalance increases hotspot latency and error risk.
- **Quick rule:** If one broker dominates traffic for long periods, inspect leader distribution and partition assignment.
- **What should be ideal (with examples):**
  - Ideal: reasonably balanced rates across brokers for balanced workloads.
  - Example: 3 brokers receiving order traffic.
  - Healthy: roughly 9k/10k/11k msg/s.
  - Unhealthy: 25k/2k/3k msg/s for 20+ minutes -> likely leadership skew.

### 1.9 Request Rate by Type
- **Metric name:** Request Rate by Type
- **Metrics used:** `kafka_network_requestmetrics_requests_total` (rate by request)
- **What is that metric:** Kafka API request mix (Produce, Fetch, Metadata, etc.).
- **Why it is used:** Verifies expected client behavior.
- **Why it matters:** Abnormal request composition can indicate reconnect storms or client misconfiguration.
- **Quick rule:** If Metadata/ApiVersions requests spike unexpectedly, check client churn and network stability first.
- **What should be ideal (with examples):**
  - Ideal: stable request mix matching workload pattern.
  - Example: producer-heavy service in peak hours.
  - Healthy: Produce and Fetch dominate; metadata remains low.
  - Unhealthy: metadata requests surge 10x without traffic increase.

### 1.10 Request Latency p99 by Broker
- **Metric name:** Request Latency p99 by Broker
- **Metrics used:** `kafka_network_requestmetrics_totaltimems` (quantile `0.99`)
- **What is that metric:** Tail latency for slowest 1% requests.
- **Why it is used:** Captures user-impacting delays better than average latency.
- **Why it matters:** p99 growth is an early sign of saturation before broad failure.
- **Quick rule:** Sustained p99 increase on one broker -> investigate that broker first (CPU, GC, disk, network).
- **What should be ideal (with examples):**
  - Ideal: stable around known baseline with only brief spikes.
  - Example: baseline Produce p99 around 40 ms.
  - Healthy: fluctuates 30-50 ms under normal peak.
  - Unhealthy: rises above 200 ms for 15+ minutes on broker-2.

### 1.11 Leader and Partition Count by Broker
- **Metric name:** Leader and Partition Count by Broker
- **Metrics used:** `kafka_server_replicamanager_leadercount`, `kafka_server_replicamanager_partitioncount`
- **What is that metric:** Distribution of leaders and partitions across brokers.
- **Why it is used:** Reveals workload ownership skew.
- **Why it matters:** Uneven leaders usually means uneven network/disk/request load.
- **Quick rule:** If leader skew persists, plan controlled rebalance rather than scaling blindly.
- **What should be ideal (with examples):**
  - Ideal: no sustained heavy skew between brokers.
  - Example: three brokers hosting 3000 leaders total.
  - Healthy: ~950/1020/1030 leaders.
  - Unhealthy: ~1700/650/650 leaders for prolonged period.

### 1.12 ISR Shrinks/Expands
- **Metric name:** ISR Shrinks/Expands
- **Metrics used:** `kafka_server_replicamanager_isrshrinks_total`, `kafka_server_replicamanager_isrexpands_total` (rate)
- **What is that metric:** Frequency of replicas leaving/joining ISR.
- **Why it is used:** Tracks replication stability over time.
- **Why it matters:** Frequent shrinks mean unstable replicas and potential durability degradation.
- **Quick rule:** Repeated shrink spikes (not tied to planned restarts) should be treated as reliability warning.
- **What should be ideal (with examples):**
  - Ideal: shrink rate near zero; occasional expands during recovery.
  - Example: one planned broker restart window.
  - Healthy: brief shrink spike then expand as replicas catch up.
  - Unhealthy: shrink spikes every few minutes across normal operation.

### 1.13 Leader Elections (5m)
- **Metric name:** Leader Elections (5m)
- **Metrics used:** `kafka_controller_controllerstats_leaderelectionrateandtimems_count`, `kafka_controller_controllerstats_uncleanleaderelectionspersec`
- **What is that metric:** Election churn and unsafe (unclean) elections.
- **Why it is used:** Measures cluster leadership stability and data safety posture.
- **Why it matters:** Frequent or unclean elections often correlate with client errors/timeouts.
- **Quick rule:** Election spikes outside maintenance windows require immediate stability checks; unclean elections should be zero.
- **What should be ideal (with examples):**
  - Ideal: election rate near zero; unclean elections = `0`.
  - Example: rolling restart during maintenance.
  - Healthy: small temporary election activity, then returns to near zero.
  - Unhealthy: recurring elections every 5 minutes or any unclean election > 0.

### 1.14 Cluster PVC Used vs Free (GB)
- **Metric name:** Cluster PVC Used vs Free (GB)
- **Metrics used:** PVC usage metrics with `kafka_log_log_size` fallback
- **What is that metric:** Broker disk consumption and remaining free headroom.
- **Why it is used:** Prevents disk-full events and supports retention/capacity planning.
- **Why it matters:** Disk saturation can cause replication lag, broker instability, and write failures.
- **Quick rule:** If free capacity is trending down fast or near critical levels, act before incidents (retention cleanup or scale storage).
- **What should be ideal (with examples):**
  - Ideal: sustained safety buffer (commonly >20% free as baseline target).
  - Example: 2 Ti per broker volume.
  - Healthy: used 1.2 Ti, free 0.8 Ti with predictable growth.
  - Unhealthy: free drops below 10% and continues down daily.

### 1.15 JVM Heap Used vs Max (GB)
- **Metric name:** JVM Heap Used vs Max (GB)
- **Metrics used:** `jvm_heap_memory_used/max` or `jvm_memory_*` fallback
- **What is that metric:** Broker JVM heap pressure relative to configured heap maximum.
- **Why it is used:** Detects memory stress that can trigger GC and latency degradation.
- **Why it matters:** Sustained high heap reduces performance headroom and can cause instability.
- **Quick rule:** If heap remains near max for long periods, tune producer/consumer behavior or scale out.
- **What should be ideal (with examples):**
  - Ideal: below sustained high-pressure zone (often <70-80%).
  - Example: broker heap max = 8 GB.
  - Healthy: oscillates 4-6 GB with regular GC recovery.
  - Unhealthy: pinned around 7.8-8 GB for extended time.

### 1.16 GC Collection Time Rate (s/s)
- **Metric name:** GC Collection Time Rate (s/s)
- **Metrics used:** `jvm_gc_collection_time_ms`, `jvm_gc_collection_seconds_sum`, `kafka_jmx_gc_collection_seconds_sum`
- **What is that metric:** Rate of time JVM spends in garbage collection.
- **Why it is used:** Highlights JVM overhead contribution to latency.
- **Why it matters:** Rising GC often explains p99 regressions under load.
- **Quick rule:** If GC rate rises together with latency and heap pressure, prioritize memory tuning/scaling.
- **What should be ideal (with examples):**
  - Ideal: low and stable around baseline.
  - Example: baseline around 0.02 s/s.
  - Healthy: stays near baseline as load increases gradually.
  - Unhealthy: jumps to 0.20 s/s with concurrent p99 latency rise.

### 1.17 Network Processor Utilization (%)
- **Metric name:** Network Processor Utilization (%)
- **Metrics used:** `kafka_network_socketserver_networkprocessoravgidlepercent` (utilization derived from idle%)
- **What is that metric:** Utilization level of broker network processor threads.
- **Why it is used:** Detects network request handling saturation.
- **Why it matters:** Saturated network processors increase queueing, latency, and timeout risk.
- **Quick rule:** Watch idle%: sustained near-zero idle means near-maximum utilization and bottleneck risk.
- **What should be ideal (with examples):**
  - Ideal: maintain healthy idle headroom.
  - Example: broker handling stable mixed produce/fetch traffic.
  - Healthy: idle% roughly 20-50% in steady state.
  - Unhealthy: idle% sits at 0-3% for long durations.

---

## 2) Kafka Topics Deep Dive (L2)
**Operational question:** Which topic or consumer group is causing the symptom?

### 2.1 Topic Count (Non-Internal)
- **Metric name:** Topic Count (Non-Internal)
- **Metrics used:** `kafka_topic_partitions` (distinct topic count excluding internal topics)
- **What is that metric:** Number of user/business topics currently present.
- **Why it is used:** Tracks topic sprawl and governance drift.
- **Why it matters:** Uncontrolled topic growth increases operational complexity and storage overhead.
- **Quick rule:** Unexpected topic-count jumps should trigger ownership and auto-creation checks.
- **What should be ideal (with examples):**
  - Ideal: controlled growth aligned with planned onboarding.
  - Example: team onboards two new services this sprint.
  - Healthy: topic count rises only during planned changes.
  - Unhealthy: topic count jumps by 50 overnight with no release.

### 2.2 Top Partitions per Topic
- **Metric name:** Top Partitions per Topic
- **Metrics used:** `kafka_topic_partitions` (topk by topic)
- **What is that metric:** Topics with the highest partition counts.
- **Why it is used:** Validates partition strategy versus workload.
- **Why it matters:** Over-partitioning can increase metadata overhead and balancing complexity.
- **Quick rule:** High partition count is good only when justified by throughput/parallelism.
- **What should be ideal (with examples):**
  - Ideal: partition counts match throughput and consumer parallelism needs.
  - Example: hot `orders` topic intentionally set to many partitions.
  - Healthy: high-throughput topics appear at top.
  - Unhealthy: low-traffic `audit` topic has very high partition count.

### 2.3 Under-Replicated Partitions by Topic
- **Metric name:** Under-Replicated Partitions by Topic
- **Metrics used:** `kafka_topic_partition_under_replicated_partition`
- **What is that metric:** Topic-level count of under-replicated partitions.
- **Why it is used:** Pinpoints which business topics are at durability risk.
- **Why it matters:** Helps prioritize impact by domain/team rather than only cluster totals.
- **Quick rule:** If critical topic shows non-zero value, escalate immediately even if cluster total looks small.
- **What should be ideal (with examples):**
  - Ideal: `0` for all topics.
  - Example: payment and checkout topics are business critical.
  - Healthy: both stay at `0` under peak traffic.
  - Unhealthy: `payments` topic shows `3` under-replicated partitions.

### 2.4 Top Producer Throughput by Topic (msg/s)
- **Metric name:** Top Producer Throughput by Topic (msg/s)
- **Metrics used:** `kafka_server_brokertopicmetrics_messagesin_total` (rate by topic)
- **What is that metric:** Highest message-producing topics at this moment.
- **Why it is used:** Identifies noisy producers and release impact.
- **Why it matters:** Unexpected top talkers can hide routing bugs or bad batching.
- **Quick rule:** If unknown topic becomes top producer abruptly, validate producer config and destination mapping.
- **What should be ideal (with examples):**
  - Ideal: top topics match known business activity.
  - Example: marketing campaign expected to increase `notifications` topic.
  - Healthy: `notifications` rises during campaign window.
  - Unhealthy: unknown temporary topic dominates msg/s after deploy.

### 2.5 Topic Size by Broker/Topic (GB)
- **Metric name:** Topic Size by Broker/Topic (GB)
- **Metrics used:** `kafka_log_log_size` (by pod and topic)
- **What is that metric:** Data footprint for each topic across brokers.
- **Why it is used:** Detects retention drift, replay impact, and storage skew.
- **Why it matters:** Runaway topic growth can exhaust disk and destabilize brokers.
- **Quick rule:** If topic size slope keeps increasing beyond retention expectations, inspect retention/compaction and producer behavior.
- **What should be ideal (with examples):**
  - Ideal: growth slope aligns with retention policy and business volume.
  - Example: retention = 7 days for event topic.
  - Healthy: size rises with traffic and plateaus according to retention.
  - Unhealthy: size grows continuously for days without plateau.

### 2.6 Consumer Lag by Group/Topic (Top N)
- **Metric name:** Consumer Lag by Group/Topic (Top N)
- **Metrics used:** `kafka_consumergroup_lag` (group/topic)
- **What is that metric:** Top current backlog offenders across groups/topics.
- **Why it is used:** Quickly identifies where consumers are falling behind.
- **Why it matters:** Persistent lag impacts freshness and downstream SLAs.
- **Quick rule:** Rising lag with stable producer rate usually means consumer capacity or dependency bottleneck.
- **What should be ideal (with examples):**
  - Ideal: low lag that recovers quickly after bursts.
  - Example: checkout consumer receives temporary burst.
  - Healthy: lag spikes briefly, then returns to baseline.
  - Unhealthy: lag grows continuously for 30+ minutes.

### 2.7 Consumer Lag Trend by Group
- **Metric name:** Consumer Lag Trend by Group
- **Metrics used:** `kafka_consumergroup_lag` (by group)
- **What is that metric:** Time trend of lag per consumer group.
- **Why it is used:** Distinguishes temporary spikes from persistent under-capacity.
- **Why it matters:** Trend direction is often more useful than one-time lag value.
- **Quick rule:** Upward lag slope over long intervals means scale/tune consumers before backlog becomes critical.
- **What should be ideal (with examples):**
  - Ideal: mostly flat or downward trend after traffic bursts.
  - Example: analytics group processes periodic batch spikes.
  - Healthy: saw-tooth pattern with regular recovery.
  - Unhealthy: continuous upward trend for hours.

---

## 3) Kafka Cruise Control Ops (L2)
**Operational question:** Is rebalance safe, progressing, and effective?

### 3.1 Cruise Control Pods Up
- **Metric name:** Cruise Control Pods Up
- **Metrics used:** `up{pod=~".*cruise-control.*"}`
- **What is that metric:** Availability status of Cruise Control pods.
- **Why it is used:** Confirms rebalance service readiness.
- **Why it matters:** Running rebalance without stable Cruise Control increases operation failure risk.
- **Quick rule:** Start rebalance only when all expected Cruise Control pods are consistently up.
- **What should be ideal (with examples):**
  - Ideal: all expected pods report up continuously.
  - Example: deployment expects 1 Cruise Control pod.
  - Healthy: `up = 1` for the pod.
  - Unhealthy: intermittent `up = 0` during planned rebalance window.

### 3.2 Cruise Control Endpoint Health
- **Metric name:** Cruise Control Endpoint Health
- **Metrics used:** `max_over_time(up[5m])` (by pod)
- **What is that metric:** 5-minute health stability of scrape endpoints.
- **Why it is used:** Validates observability continuity before interpreting operation metrics.
- **Why it matters:** Intermittent scrape failures can mislead rebalance diagnosis.
- **Quick rule:** If endpoint health is unstable, fix telemetry/service path before making optimization decisions.
- **What should be ideal (with examples):**
  - Ideal: stable healthy endpoint across the window.
  - Example: 5-minute rolling check for each cc pod.
  - Healthy: max-over-time stays at `1`.
  - Unhealthy: repeated dips indicate endpoint or network instability.

### 3.3 Execution Start/Stop Events
- **Metric name:** Execution Start/Stop Events
- **Metrics used:** `cruise_control_executor_execution_*` deltas
- **What is that metric:** Lifecycle event counters for execution start/stop.
- **Why it is used:** Confirms whether requested rebalances actually started and ended.
- **Why it matters:** Avoids false assumptions that operations are running when they are not.
- **Quick rule:** Every start should have matching completion/stop behavior in expected window.
- **What should be ideal (with examples):**
  - Ideal: events align one-to-one with planned operations.
  - Example: one manual rebalance at 10:00.
  - Healthy: start event appears, then completion/stop appears by expected finish time.
  - Unhealthy: repeated starts without clear stop/completion.

### 3.4 Action State Indicators
- **Metric name:** Action State Indicators
- **Metrics used:** `*_action_in_progress` family
- **What is that metric:** Whether each action type is currently executing.
- **Why it is used:** Detects stalled action phases.
- **Why it matters:** Long-running stuck actions can prolong risk exposure during rebalances.
- **Quick rule:** In-progress flags should clear after reasonable duration; investigate stuck states quickly.
- **What should be ideal (with examples):**
  - Ideal: in-progress appears during work, then returns to idle.
  - Example: partition move action during rebalance.
  - Healthy: flag toggles on, then off at completion.
  - Unhealthy: flag remains on for 30+ minutes with no progress.

### 3.5 Execution In-Progress/Completed/Aborted
- **Metric name:** Execution In-Progress/Completed/Aborted
- **Metrics used:** `cruise_control_executor_ongoing_execution_*`
- **What is that metric:** Current execution state and outcomes.
- **Why it is used:** Tracks whether operations are progressing, succeeding, or failing.
- **Why it matters:** Rising aborts indicate unsafe tuning or unstable cluster conditions.
- **Quick rule:** Completed should rise after planned runs; aborted should remain near zero.
- **What should be ideal (with examples):**
  - Ideal: normal transition from in-progress to completed.
  - Example: one rebalance execution request.
  - Healthy: ongoing starts, completed increments, aborted unchanged.
  - Unhealthy: aborted increments repeatedly.

### 3.6 Partition Movement Throughput
- **Metric name:** Partition Movement Throughput
- **Metrics used:** `partition_movement_count_per_second`, `partition_movement_mb_per_second`
- **What is that metric:** Speed and volume of movement during rebalance.
- **Why it is used:** Estimates completion time and operational impact.
- **Why it matters:** Too aggressive movement can destabilize brokers and increase latency.
- **Quick rule:** Increase movement only while safety and p99 metrics remain stable.
- **What should be ideal (with examples):**
  - Ideal: steady movement with stable platform health.
  - Example: rebalance with controlled movement throttle.
  - Healthy: throughput remains stable and URP stays zero.
  - Unhealthy: higher throughput coincides with URP/latency spikes.

### 3.7 Load Health Risk Indicators
- **Metric name:** Load Health Risk Indicators
- **Metrics used:** `brokers_with_offline_replicas`, `dead_brokers_with_replicas`, `num_partitions_with_extrapolations`
- **What is that metric:** Risk signals used by Cruise Control optimization logic.
- **Why it is used:** Prevents unsafe optimization decisions during degraded states.
- **Why it matters:** Rebalancing during high risk can worsen outages.
- **Quick rule:** Postpone aggressive optimization if any risk indicator is elevated.
- **What should be ideal (with examples):**
  - Ideal: near-zero risk indicators.
  - Example: stable cluster before rebalance.
  - Healthy: all three metrics near zero.
  - Unhealthy: `dead_brokers_with_replicas = 1`.

### 3.8 Load Monitor Coverage Signals
- **Metric name:** Load Monitor Coverage Signals
- **Metrics used:** `cruise_control_load_monitor_monitored_partitions_percentage`
- **What is that metric:** Percentage of partitions with sufficient monitored data.
- **Why it is used:** Indicates confidence level of optimization recommendations.
- **Why it matters:** Low coverage means decisions are based on incomplete model input.
- **Quick rule:** Do not trust aggressive optimization plans when monitored coverage is low.
- **What should be ideal (with examples):**
  - Ideal: high and stable coverage (close to full coverage).
  - Example: model trained with complete recent windows.
  - Healthy: monitored partitions remain around 95-100%.
  - Unhealthy: coverage drops to 60%, reducing decision reliability.

### 3.9 Concurrency Pressure
- **Metric name:** Concurrency Pressure
- **Metrics used:** `*_max_concurrency` metrics
- **What is that metric:** Allowed/used parallelism for rebalance tasks.
- **Why it is used:** Tunes speed versus stability trade-off.
- **Why it matters:** Excess concurrency can saturate brokers and raise error/latency rates.
- **Quick rule:** Increase concurrency gradually and watch L1 safety + p99 latency in parallel.
- **What should be ideal (with examples):**
  - Ideal: enough concurrency for progress without destabilization.
  - Example: broker movement max set to 10.
  - Healthy: running around 5-6 with stable p99 and URP=0.
  - Unhealthy: maxed concurrency with rising URP and latency.

### 3.10 Aborted/Dead Actions
- **Metric name:** Aborted/Dead Actions
- **Metrics used:** `*_action_aborted`, `*_action_dead` deltas
- **What is that metric:** Failed or terminated action events.
- **Why it is used:** Detects rebalance reliability issues.
- **Why it matters:** Repeated abort/dead events usually mean unresolved constraints or unstable health.
- **Quick rule:** If these counters keep increasing, stop and diagnose constraints/cluster health before retrying.
- **What should be ideal (with examples):**
  - Ideal: near zero increments during routine operations.
  - Example: daily light rebalance schedule.
  - Healthy: no aborted/dead increases.
  - Unhealthy: frequent aborted increments every run.

### 3.11 Load Monitor Signals
- **Metric name:** Load Monitor Signals
- **Metrics used:** `num_topics`, `total_monitored_windows`, `brokers_with_replicas`
- **What is that metric:** Overall model context: topology and historical windows.
- **Why it is used:** Confirms Cruise Control has sufficient context to optimize safely.
- **Why it matters:** Missing windows/context weakens optimization quality.
- **Quick rule:** If monitored windows reset frequently, investigate telemetry pipeline before optimization.
- **What should be ideal (with examples):**
  - Ideal: stable topic/broker visibility and continuously growing monitored windows.
  - Example: normal operations across 3 brokers and steady topic set.
  - Healthy: monitored windows remain continuous across intervals.
  - Unhealthy: monitored windows repeatedly reset to low values.

---

## Developer Triage Playbook (Fast Order)
1. **Safety first:** Under-Replicated Partitions, Offline Partitions, Under Min ISR, Fenced Brokers.
2. **Scope second:** Use `namespace` + `broker_pod` to confirm cluster-wide vs single-broker problem.
3. **Performance third:** Request Latency p99 by Broker, Messages In/s by Broker, Cluster Throughput (Bytes/s).
4. **Backlog fourth:** Consumer Lag by Group/Topic (Top N), Consumer Lag Trend by Group.
5. **Capacity fifth:** Cluster PVC Used vs Free (GB), JVM Heap Used vs Max (GB), GC Collection Time Rate (s/s), Network Processor Utilization (%).
6. **Optimization last:** Use Cruise Control panels only after safety/performance are stable.

## Practical Threshold Guidance (Starting Baseline)
- **Must stay at 0:** Under-Replicated Partitions, Offline Partitions, Under Min ISR, Fenced Brokers, Unclean Leader Elections.
- **Investigate quickly:** Sustained p99 latency increase, recurring ISR shrink spikes, rising aborted/dead Cruise Control actions.
- **Capacity planning trigger:** Persistent upward trends in PVC usage, heap pressure, and network saturation.

> Tune all thresholds per environment SLOs and workload profile.

## Notes for Multi-Node AKS Environments
- Always keep `namespace` + `pod`/`instance` filters in PromQL to avoid mixed-cluster views.
- Use `[5m]` rate windows for smoother operational signals.
- Use Top N panels for actionable outlier focus and lower cardinality pressure.
