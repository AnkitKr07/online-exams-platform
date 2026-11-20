# Online Exams Platform — Capacity Estimate

| | |
| --- | --- |
| Issue | BAC-8 |
| Version | v1.1 draft, 20 Nov 2026 (v1.1 adds section 12, the scale-up ladder, and resolves the two conflicts in section 11 with the free-first rule) |
| Owner | Khushboo and Ankit |
| Covers | v1 launch year (Phase 3) in detail; the Phase 2 pilot and the Phase 4 scale target for comparison |
| Builds on | BAC-6 (functional requirements), BAC-7 (load levels, limits, free-VM constraints) |
| Feeds | BAC-9 (domain model), BAC-10 (ADR-003, database per service), BAC-31 (answers schema), Phase 4 load tests |

## 1. How to read this document

- **Brute force first, then refine.** Each estimate starts with the worst plausible case in round numbers, then refines it with realistic behaviour. Decisions use the refined number; safety margins use the brute-force one.
- **Precision is ±2×.** The goal is the order of magnitude, and which resource runs out first. A number that is off by 30% changes nothing here.
- **Per-request CPU costs are educated guesses** until they are measured (section 10). They are marked "guess" where used.
- **Units:** 1 GB = 10⁹ bytes; rps = requests per second; the free VM's 2 OCPUs are treated as 2 cores.
- The free-VM figures come from Oracle's documentation; row-size figures come from the PostgreSQL documentation. Sources are at the end.

## 2. The answer on one page

| Question | v1 launch estimate |
| --- | --- |
| Peak exam starts per second | 200 (brute force: 1,000) |
| Autosaves per second during a 1,000-student exam | about 19 (brute force: 500; NFR-2 budget: 50) |
| Logins per second before a big exam | about 4 (brute force: 1,000 at the same moment) |
| Attempts per year | 1.9 million |
| Answer rows per year | 51 million, about 83% of the database |
| Database growth | about 15 GB per year; about 31 GB steady state with 2-year retention |
| Read:write ratio on the exam path | about 1:10, so the exam path is write-heavy |
| Does it fit the free Oracle VM? | Memory and disk, yes. CPU only just, in the peak second of an exam start |
| What breaks first | CPU for password hashing at about 14 logins per second, then CPU for exam starts at about 140 per second |
| Free-tier limits hit before the VM's | Backup storage (35-day retention does not fit) and the free email quota. Both are resolved in section 11 by the free-first rule. |
| What happens when a client outgrows the free VM | Section 12: four rungs, each with a trigger. The system is built scale-ready, so each rung is a configuration change. CPU is the first thing to buy. |

## 3. Assumptions

| Assumption | Value | Why |
| --- | --- | --- |
| Schools at the end of the v1 launch year | 50 | A realistic first year for a self-serve product; confirm in section 11 |
| Students per school on the platform | 500 | Mix of schools and coaching institutes |
| Students in total | 25,000 | 50 × 500 |
| Students per class | 40 | BAC-5 persona (sections of about 40) |
| Classes | 625 | 25,000 ÷ 40 |
| Teachers | 1,250 | About 25 per school |
| Exams per student per week | 2 | Weekly tests in two subjects |
| Academic weeks per year | 40 | School year without holidays |
| Share of assigned students who attempt | 95% | Absences |
| Questions per exam | 30 on average | The limit is 200 (BAC-7) |
| Questions actually answered | 90% | Some are skipped |
| Saves per answered question | 1.5 | Students change answers; includes client retries |
| Exam duration | 40 minutes on average | The limit is 180 minutes (BAC-7) |
| School days, and hours with exams | 200 days, 6 hours a day | Exams run in school hours |
| Largest single exam burst | 1,000 students | BAC-7 v1 load level |
| Share of a burst that starts in the peak second | 20% | BAC-7 assumption |
| Logins before a big exam | 1,000 in the 10 minutes before it opens | BAC-7 assumption |
| Students with an email address | 30% | Many under-18 students have none (BAC-5) |
| Password hash time on the VM | 100 ms | BAC-7 NFR-30 tuning target |
| Teacher and admin traffic | +10% on top of student traffic | Authoring and results are low volume |

## 4. Traffic

### 4.1 One attempt, request by request

| Request | Per attempt | Read or write |
| --- | --- | --- |
| Log in | 1 | Read (CPU-heavy: password hash) |
| List my quizzes | 2 | Read |
| Start attempt and receive paper | 1 | Write (inserts the attempt) |
| Save an answer | 45 (30 questions × 90% × 1.5, rounded) | Write |
| Resume after a drop | 0.2 | Read |
| Submit | 1 | Write |
| View result | 2 | Read |
| **Total** | **about 52, rounded to 50** | **47 writes, about 5 reads** |

### 4.2 Exam-start burst

- **Brute force:** all 1,000 students press Start in the same second → **1,000 rps**.
- **Refined:** the peak second carries 20% of the burst (BAC-7) → 1,000 × 0.2 = **200 rps**, the same as NFR-1's v1 level.
- Each start inserts an attempt, reads the quiz snapshot and serialises the paper. That makes it the most expensive request after login (section 7.4).

### 4.3 Autosave

- **Brute force:** the client saves the whole answer sheet on a timer every 2 seconds. 1,000 students ÷ 2 s = **500 rps**, each rewriting 30 rows = **15,000 row writes per second**.
- **Refined:** the client saves only when an answer changes, one question per request. That is 45 saves in a 2,400-second exam, or one every 53 seconds per student. 1,000 × 45 ÷ 2,400 = **about 19 rps**, one row each.
- Saving on change is 26 times fewer requests and 800 times fewer row writes than the timer, and still meets NFR-14 (a change is sent within 2 s).
- NFR-2's budget of 50 rps leaves 2.7× headroom for retries and the rush of last-minute changes.

### 4.4 Logins

- **Brute force:** 1,000 students log in at the same moment. 1,000 × 100 ms = 100 seconds of CPU. On 1.4 usable cores (section 7.4) the last student waits about **71 seconds**.
- **Refined:** spread over the 10 minutes before the window opens = 1,000 ÷ 600 s = **1.7 per second**. If half arrive in the last 2 minutes: 500 ÷ 120 s = **4.2 per second**.

### 4.5 Submit and auto-submit

- **NFR-3 load:** all 1,000 students submit in the last 60 seconds → 1,000 ÷ 60 = **17 rps**.
- **Brute force:** everyone started in the same second and runs out the clock, so 1,000 attempts reach their deadline together. These are not HTTP requests; the auto-submit job (FR-41) handles them. Processing them in batches of about 100 per transaction keeps the database busy for a second or two, not a minute.
- Scoring 30 answers in memory takes microseconds. The cost is the database work: read 30 answer rows and write one score.

### 4.6 Averages versus peaks

- Requests per year: 1.9 million attempts × 50 × 1.1 = **about 105 million**.
- Average during school hours: 105 million ÷ (200 days × 6 h × 3,600 s) = **24 rps**.
- Average over the whole year: 105 million ÷ 31.5 million s = **3.3 rps**.
- Peak second: 200 starts + 19 saves ≈ **220 rps**, which is 9 times the school-hours average and 65 times the yearly average.

The averages say a very small server would do. The peaks decide the design, so every target in this document is sized for the peak.

### 4.7 Bandwidth

- Average paper: 30 questions × about 720 bytes = 22 KB raw, about 6 KB compressed (guess: 3.5× gzip).
- Peak: 200 starts × 6 KB = 1.2 MB/s ≈ **10 Mbps**. Brute force with NFR-11's 200 KB cap: 200 × 200 KB = 40 MB/s = **320 Mbps**.
- Monthly outbound traffic: 105 million ÷ 12 requests × about 2 KB ≈ **17 GB a month**, against the free 10 TB a month.

Bandwidth is not a constraint.

## 5. Storage

### 5.1 Size of one answer row

| Part | Bytes | Note |
| --- | --- | --- |
| `attempt_id` (UUID) | 16 | |
| `question_id` (UUID) | 16 | |
| `school_id` (UUID) | 16 | Tenant on every row (BR-1) |
| Selected option IDs (`uuid[]`, about 1.2 options) | 43 | 24-byte array header + 1.2 × 16 |
| `saved_at` (`timestamptz`) | 8 | |
| `client_seq` (`bigint`) | 8 | Rejects out-of-order saves (FR-35) |
| **Column data** | **107** | |
| Tuple header | 24 | 23 bytes, padded |
| Row aligned to 8 bytes | 136 | |
| Item identifier (line pointer) | 4 | One per row on the page |
| Page fill at 90% | ÷ 0.9 → 156 | |
| Dead versions between vacuums | × 1.3 → 203 | Every autosave update leaves an old version until VACUUM clears it |
| Primary-key index on (`attempt_id`, `question_id`) | 49 | 8-byte index tuple header + 32 + 4, at 90% fill |
| **Total per answer** | **about 250** | Brute force: 1 KB |

Storing option positions as `smallint[]` instead of UUIDs would save about 30 bytes a row (12%). It is not worth the extra mapping now; it is noted for Phase 4.

### 5.2 Growth per year

| Data | Rows per year | Size per row | GB per year (refined) | GB per year (brute force) |
| --- | --- | --- | --- | --- |
| Answers | 51 million (brute force: 60 million) | 250 B (1 KB) | 12.8 | 60 |
| Attempts | 1.9 million | 500 B including 4 indexes | 0.95 | 1.0 |
| Quiz snapshots, two copies (Assessment and Exam Delivery) | 50,000 assignments from about 25,000 quizzes | 11 KB compressed (30 KB) | 0.55 | 3.0 |
| Questions and options | 375,000 (1,250 teachers × 300) | 1 KB | 0.4 | 0.4 |
| Notification log | 1.2 million emails | 500 B | 0.6 | 0.6 |
| Schools, users, classes | About 26,000 | 500 B | under 0.1 | under 0.1 |
| **Database total** | | | **about 15** | **about 65** |

With 2-year retention (NFR-44), the database levels off at about **31 GB**.

The arithmetic behind the rows:
- Attempts: 25,000 × 2 a week × 40 weeks × 95% = 1.9 million.
- Answers: 1.9 million × 30 × 90% = 51 million.
- Assignments: 625 classes × 2 × 40 = 50,000.
- Emails: 50,000 teacher result emails + 1.9 million × 30% × 2 (reminder and result) = 1.2 million.

### 5.3 Logs and backups

- **Access logs:** 105 million requests × 2 log lines (gateway and service) × about 400 bytes = **84 GB a year raw**, about 8 GB compressed (guess: 10× gzip). NFR-47 keeps them for a year. Raw, the logs are more than five times the size of the database.
- **Backups:** a compressed `pg_dump` is about a quarter of the database (guess), so about **3.8 GB** at the end of year 1.
    - 35 daily dumps (NFR-19): 35 × 3.8 = **135 GB**.
    - 5 weekly dumps: **19 GB**.
    - The free object storage holds **20 GB**.

## 6. Read/write ratio and the fastest-growing table

- **Exam path:** 47 writes to about 5 reads per attempt, so **about 1:10, write-heavy**. Including teacher and admin traffic, about 80% of all requests are writes. Most web applications are the other way round.
- **Consequence:** caches and read replicas help the results pages and the paper read at start, but not the bulk of exam traffic. The lever for the exam path is making each write cheap: one row per save, an upsert, no read before the write, and batching later (Phase 4).
- **Fastest-growing table:** `answers`, with 27 rows per attempt and about 83% of the database's bytes. It is the table that gets the partitioning plan (BAC-31 note, Phase 4).

## 7. What fits on the free Oracle VM

### 7.1 What the VM gives

| Resource | Always Free allowance |
| --- | --- |
| Compute (Ampere A1 Arm) | 2 OCPUs and 12 GB of memory |
| Block storage | 200 GB, boot and block volumes combined (default boot volume 50 GB) |
| Volume backups | 5 |
| Object storage | 20 GB |
| Outbound data | 10 TB a month |

### 7.2 Memory

| Component | Memory |
| --- | --- |
| 5 Spring Boot services (gateway, Identity, Assessment, Exam Delivery, Notification) at 512 MB each (NFR-68) | 2.5 GB |
| PostgreSQL: 2 GB shared buffers, about 60 connections and maintenance | 3.0 GB |
| Kafka, single KRaft broker | 1.0 GB |
| Redis | 0.25 GB |
| Prometheus, Grafana and Loki | 1.3 GB |
| k3s and containerd (Phase 3) | 0.8 GB |
| Operating system | 0.5 GB |
| **Total** | **about 9.4 GB** |

That is within NFR-67's 10 GB ceiling, and leaves about 2.6 GB for the operating system to cache database pages.

### 7.3 Disk

Year 1 uses about 25 GB of the roughly 150 GB left after the boot volume:
- database: 15 GB;
- local logs (30 days in Loki): about 2 GB;
- Prometheus: about 2 GB;
- container images: about 5 GB;
- Kafka: under 1 GB.

Disk is not a constraint at v1 scale.

### 7.4 CPU (the tight one)

Usable CPU: 70% of 2 cores = 1.4 cores, or 1,400 ms of CPU per second. The rest is left for garbage collection, PostgreSQL maintenance, Kafka and monitoring.

| Request | CPU per request (guess) | Ceiling on the VM | v1 load | Share of usable CPU |
| --- | --- | --- | --- | --- |
| Login | 100 ms (NFR-30) | 14 per second | 4.2 per second | 30% |
| Start attempt and receive paper | 10 ms | 140 per second | 200 in the peak second | 143%: over capacity for that second |
| Start, with the paper pre-serialised | 3 ms | 467 per second | 200 in the peak second | 43% |
| Autosave | 5 ms | 280 per second | 19 per second (50 budget) | 7% (18% at budget) |

The start cost covers the gateway proxy, two token checks, an insert, a snapshot read and serialising 30 questions.

The peak second of 200 starts needs 2 seconds of CPU, which takes about 1.4 seconds to clear. That puts NFR-1's 500 ms p95 at risk. If each snapshot's paper is serialised once and reused, a start is an insert plus a copy, and the same second clears in about 0.4 seconds.

### 7.5 Database connections

Little's law gives the number of connections busy at once: requests per second × time each one holds a connection.
- Starts: 200 per second × 5 ms of database time = **1 busy connection**.
- Autosaves: 19 per second × 3 ms = **0.06**.

HikariCP's default pool of 10 per service is plenty: 4 services that use the database × 10 = 40 connections, within PostgreSQL's default limit of 100. A bigger pool would only add contention on 2 cores.

### 7.6 What breaks first

| Order | Resource | Breaks at | v1 load | Fix | When |
| --- | --- | --- | --- | --- | --- |
| 1 | CPU: password hashing | About 14 logins per second | 4.2 per second typical; 1,000 at once in the worst case | Prompt students to log in early; 4-hour tokens (NFR-32) so one login covers the exam; at scale, scale Identity on its own | Phase 2, then Phase 4 |
| 2 | CPU: exam start | About 140 starts per second | 200 in the peak second | Serialise each snapshot's paper once and reuse it; jittered starts and an admission queue in Phase 4 | Phase 2, then Phase 4 |
| 3 | Backup storage | 20 GB of object storage: 5 weekly dumps fill it around month 12; 35 daily dumps never fit | NFR-19's 35-day retention | Weekly base backup plus WAL archiving (already needed for NFR-15's 5-minute RPO); a paid bucket only when a client needs 35 days | Decided 20 Nov 2026 (section 11) |
| 4 | Email quota | The free tier was sized for about 100 emails a day (NFR-69) | About 6,000 a day | Teacher emails first; student emails use the rest of the day's quota; result emails queue for the next day and reminders expire at window open; a paid tier only when a client wants every student email the same day | Decided 20 Nov 2026 (section 11) |
| 5 | Memory | About 10 GB usable | 9.4 GB | Fine until Phase 5 adds MongoDB and Kafka Streams | Phase 5 |
| 6 | Disk | About 150 GB usable | About 25 GB in year 1 | Fine at v1; at Phase 4 scale, partition `answers`, archive old partitions and add paid storage | Phase 4 |

## 8. Pilot, v1 and Phase 4 side by side

| Measure | Phase 2 pilot | v1 launch | Phase 4 scale |
| --- | --- | --- | --- |
| Students in one burst | 200 (BAC-7 level; the real class is 40) | 1,000 | 10,000 |
| Starts in the peak second | 40 | 200 | 2,000 |
| Cores needed for that second at 70% use (10 ms per start) | 0.6 | 2.9 | 29 (9 with pre-serialised papers) |
| Logins per second before an exam | Under 1 | 1.7 to 4.2 | 17 to 42 |
| Attempts | About 320 over a 4-week pilot | 1.9 million a year | 19 million a year |
| Answer rows | About 8,600 | 51 million a year | 510 million a year |
| Database growth | Under 0.1 GB | 15 GB a year | About 150 GB a year |
| Fits the free VM? | Easily | Just, with the Phase 2 fixes in section 7.6 | No |

Phase 4's target cannot run on the free VM. As the hosting plan already says, it is proven with load tests, extrapolated with this arithmetic, and checked with a few hours of paid capacity if needed. Running it for real needs these, all already in the Phase 4 scope:
- monthly partitions on `answers`;
- read replicas for results;
- pre-warmed papers and an admission queue;
- several Exam Delivery instances.

## 9. Decisions these numbers drive

| Number | Decision | Where it lands |
| --- | --- | --- |
| Timer autosave is 26× more requests (4.3) | Save on change, one question per request | FR-34, FR-35, NFR-14, client spec |
| `answers` is 83% of the database (5.2) | One row per (attempt, question), written with an upsert | BAC-31 schema |
| The exam path is 1:10 read:write (6) | No write-behind cache for answers; cache only the paper | NFR-13, BAC-34 |
| Starts exceed CPU in the peak second (7.4) | Serialise each snapshot's paper once and reuse it, in Phase 2 rather than Phase 4 | BAC-34, Phase 2 |
| Old answers must be deleted after 2 years (5.2) | Partition `answers` by month and drop whole partitions for retention | Phase 4, NFR-44 |
| Everything fits one database server through v1 (7.2, 7.3, 7.5) | Database per service on one shared PostgreSQL instance | ADR-003 (BAC-10) |
| Logs are 84 GB a year raw (5.3) | Don't log each autosave at INFO; sample autosave access logs | BAC-17 conventions, NFR-47 |
| 1,000 attempts can reach their deadline together (4.5) | Auto-submit in batches | FR-41, Phase 2 |
| One busy connection at peak (7.5) | Keep the HikariCP pool small (10) | Phase 2 configuration |
| Logins break first (7.6) | Prompt students to log in early; 4-hour tokens | NFR-5, NFR-32 |
| Everything runs free until a client needs more (user decision, 20 Nov 2026) | Scale-ready design rules plus a four-rung ladder with triggers | Section 12, NFR-78 to NFR-82 |

## 10. How we'll check these numbers

1. **Phase 1:** time the start and save requests on a laptop to replace the CPU guesses in section 7.4.
2. **Phase 2 pilot:** record the real saves per question, login spread, paper size and dump size, and update this document.
3. **Phase 4:** run full load tests against NFR-12.
4. **Any time:** re-run the estimate when an assumption changes by more than 2×. Every number in sections 4 to 8 scales linearly with the number of students.

## 11. Conflicts with BAC-7, and how free-first resolves them

On 20 Nov 2026 you decided that everything runs free first and is scaled up as clients require. That rule picks the free-fitting option for both conflicts below. BAC-7 (NFR-19, NFR-69) is updated to match.

| Item | The conflict | Resolution |
| --- | --- | --- |
| Backup retention (NFR-19, was 35 days) | 35 daily dumps need about 135 GB; the free object storage is 20 GB | **Free tier:** 4 weekly base backups plus continuous WAL archiving (which NFR-15's v1 RPO needs anyway), so any point in the last 28 days is restorable. That is about 18 GB at the end of year 1: 4 × 3.8 GB plus about 3 GB of WAL (guess). **Paid bucket (Rung 1):** 35 daily backups, bought when a client's contract requires them or the free store passes 16 GB. |
| Email volume (NFR-69) | About 6,000 emails a day at v1, against a free tier sized for about 100 | **Free tier:** teacher emails are always sent first; student emails use what is left of the day's quota. Result emails that do not fit queue for the next day. Reminders expire when the exam window opens and are dropped (FR-31, decided 20 Nov 2026), so they never queue. Results are in the app either way. The 6,000 a day is therefore an upper bound. **Paid tier (Rung 1):** bought when a client wants every student email the same day. |
| Paper pre-serialisation | Phase 4 planned pre-warming; v1's peak second already needs it | Do the simple version (reuse serialised bytes per snapshot version) in Phase 2 |
| Launch-year size | 50 schools × 500 students is an assumption | Confirm or change it; all numbers scale linearly |

## 12. Scaling up when a client needs it

The rule (20 Nov 2026): **free first, scale on demand.** Nothing is bought until a client's requirement crosses a trigger below. Two things make that safe:

- **Scale-ready by design.** Adding capacity is a configuration change, not a rewrite (12.1).
- **Scale-up by rung.** Each rung has a trigger, a capacity and a price to be set when the trigger fires (12.2 and 12.3).

We do not build for 10,000 students now. We only avoid building anything that would stop us getting there.

### 12.1 What must be true from day one

| Rule | What it keeps open | Where it lives |
| --- | --- | --- |
| Services keep no attempt state in memory | Add instances at any time | NFR-25 |
| A database per service, all on one server today | Move any database to its own server by changing a connection URL | ADR-003 (BAC-10), section 9 |
| No cross-service joins or foreign keys | Databases can be split without rewriting queries | Architecture principle 5 |
| `school_id` on every row | Partition by school or move a large school without a rewrite; stops one school's burst hurting another | NFR-26, NFR-28 |
| Idempotent start, save and submit; server-owned time | Safe behind a load balancer, with retries and failover | NFR-13, NFR-14 |
| Caches hold copies, never the only copy of an answer | Add Redis or read replicas without risking an answer | Section 6, NFR-13 |
| Slow work goes through the outbox and Kafka | Consumers scale by adding instances; a slow email never blocks an exam | FR-55 |
| Email and object storage sit behind interfaces | Swap a free provider for a paid one by configuration | NFR-80 |
| Configuration comes from the environment; images build for arm64 and amd64 | The same release runs on the free Arm VM and on any paid host | NFR-78, NFR-79 |

### 12.2 The ladder

Capacities are CPU for exam starts only, from the guessed per-request costs in 7.4, so they are ±2×. Prices are not estimated here. Each rung is priced when its trigger fires, and the client whose requirement caused it pays for it (decided 20 Nov 2026). That makes these rungs an input to pricing (BAC-5).

| Rung | Setup | Handles (burst, students starting together) | Move up when | What changes |
| --- | --- | --- | --- | --- |
| 0. Free | One Always Free Arm VM (2 OCPU, 12 GB); free object storage; free email tier | About 700; about 2,300 with pre-serialised papers. The pilot fits as it is. The v1 estimate (largest burst 1,000) needs the pre-serialised papers planned for Phase 2 (section 9). | Any trigger in 12.3 | Nothing |
| 1. Free VM plus paid add-ons | A paid object-storage bucket, a paid email tier, a larger block volume | Same CPU. Removes the storage and email limits. | A compute trigger, or a client needs 35-day backups or same-day student emails | Configuration only (NFR-78, NFR-80) |
| 2. Bigger compute, separate database | A paid VM with 4 to 8 cores for the services; PostgreSQL on its own server | 4 cores: about 1,400, or 4,700 pre-serialised. 8 cores: about 2,800, or 9,300 pre-serialised. | A burst above Rung 1's capacity, CPU above 70% in exam windows, or a client wants a written availability commitment | Configuration only. The database move is a connection-URL change (NFR-78). |
| 3. Redundant | Two or more app nodes behind a load balancer; several Exam Delivery instances; PostgreSQL with a standby and a read replica for results; Redis for papers | The same as Rung 2, but a failed node no longer stops an exam. This is what a 99.9% commitment (NFR-20) needs. | Availability is contractual, or results queries slow exams (NFR-27) | Phase 4 scope: pre-warmed papers, read replicas, an admission queue |
| 4. Scale target | Phase 4 target: 10,000 students starting together needs about 9 cores of start capacity with pre-serialised papers (29 without), plus partitioned `answers`, autoscaling and a Kafka cluster | 10,000 and above (NFR-12) | A client or group of clients needs more than Rung 3's capacity | Phase 4 scope, proven by load tests first |

Capacity is not availability. A bigger single VM still loses everything if it fails, and Oracle's free VM is a single machine. A written 99.9% promise to a client means Rung 3.

### 12.3 Triggers

Each trigger is checked weekly in the MVP and alerted from v1 (NFR-81). The threshold leaves room to buy and test the next rung before the limit is hit.

| Signal | Threshold | Moves to | Where it comes from |
| --- | --- | --- | --- |
| CPU in exam windows | Above 70% for 3 exam windows | Rung 2 | 7.4 |
| Largest burst a client needs | Above 70% of the current rung's burst capacity in 12.2 | The next rung | 12.4 |
| Logins | Above 10 per second sustained | Rung 2 (Identity gets its own instance) | 7.4 |
| Memory | Peak above 10 GB | Rung 2 | NFR-67 |
| Disk (database, logs, Kafka, images) | Above 60% of the roughly 150 GB usable | Rung 1 (larger volume), then partition `answers` | 7.3 |
| Object storage | Above 16 GB of the 20 GB | Rung 1 | 5.3 |
| Email | Over 80% of the daily free quota on 3 days in a week | Rung 1 | 5.2 |
| Contract | A client needs a written availability commitment (NFR-20), or 35-day backups (NFR-19) | Rung 3, or Rung 1 | NFR-19, NFR-20 |
| Exam path latency | p95 above NFR-1 to NFR-3 in 2 windows in a row | Find the cause first, then the next rung | BAC-7 section 3 |

### 12.4 Sizing a client before onboarding (NFR-82)

Re-run the section 3 assumptions with the client's numbers. Every figure scales linearly with students. For compute, work out the peak second, then the cores:

- Peak starts per second = 20% of the largest burst.
- Cores for starts = starts per second × CPU per start ÷ 0.7. The CPU per start is 10 ms, or 3 ms with pre-serialised papers.
- Cores for logins = logins per second × 100 ms ÷ 0.7.

| Cores | Usable (70%) | Starts per second at 10 ms | Burst | Starts per second at 3 ms | Burst | Logins per second |
| --- | --- | --- | --- | --- | --- | --- |
| 2 (free VM) | 1.4 | 140 | 700 | 467 | 2,300 | 14 |
| 4 | 2.8 | 280 | 1,400 | 933 | 4,700 | 28 |
| 8 | 5.6 | 560 | 2,800 | 1,867 | 9,300 | 56 |
| 16 | 11.2 | 1,120 | 5,600 | 3,733 | 18,700 | 112 |

**Worked example.** A coaching institute wants 3,000 students to start a mock together.
- Peak second: 20% × 3,000 = 600 starts.
- Cores: 600 × 10 ms ÷ 0.7 = 8.6 cores without pre-serialised papers; 600 × 3 ms ÷ 0.7 = 2.6 cores with them.
- Logins: 3,000 over 10 minutes is 5 per second, so no problem.
- Autosaves: 57 per second (3 × 19), no problem.
- **Result:** Rung 2 with 4 cores and pre-serialised papers. Our estimates are ±2×, so the first load test on the real machine sets the final size.

## 13. Review questions for you

Answer these before we close BAC-8; I'll push back on each.

- [ ] Estimate QPS and storage for 10,000 students starting an exam at once. Then say which number in your estimate you trust least, and why.
- [ ] Which component becomes the bottleneck first, and why? What is the cheapest fix?
- [ ] Why is the exam path write-heavy, and what does that rule out?
- [ ] Use Little's law to explain why a pool of 10 connections is enough for 200 starts per second, and why a pool of 100 would be worse.
- [ ] Autosave on a timer versus on change: compute both for 1,000 students, and name the NFR each one threatens.
- [ ] The database grows 15 GB a year but the logs grow 84 GB raw. What would you change first, and what would you lose?
- [ ] A client asks for 3,000 students at once, and says it is paying for the capacity. Which rung do you sell them, and which three checks do you run before go-live?
- [ ] Why does a bigger VM not give a 99.9% promise? What is the smallest change that does?

## Sources

- [Oracle Cloud Infrastructure documentation: Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm): 2 OCPUs and 12 GB, 200 GB block storage, 5 volume backups, 20 GB object storage, 10 TB outbound a month
- [Terminal Bytes: Oracle Cloud free tier changes 2026](https://terminalbytes.com/oracle-cloud-free-tier-changes-2026): the compute allowance was halved in June 2026; block storage was unchanged
- [PostgreSQL documentation: Database Page Layout](https://access.crunchydata.com/documentation/postgresql11/11.4/storage-page-layout.html): 23-byte tuple header, 4-byte item identifier, 8 kB pages
