# Online Exams Platform — Functional Requirements and Use Cases

| | |
| --- | --- |
| Issue | BAC-6 |
| Version | v1.1 draft, 26 Oct 2026 (v1: 25 Oct 2026) |
| Owner | Khushboo |
| Covers | POC (Phase 1) and MVP (Phase 2); later items listed for completeness |
| Builds on | BAC-5: vision, scope, personas and user journeys |
| Feeds | BAC-7 (NFRs), BAC-9 (domain model), API design (BAC-18), tests in every phase |

### Changes in v1.1

- **Release settings per quiz (FR-23):** the teacher chooses whether students see their score, the correct answers, and their rank and percentile. Defaults: score on, the other two off. The settings can change at any time (BR-17).
- **Rank and percentile (new FR-58):** computed within each assignment after quiz close. This moved from Later to MVP. Cross-class rankings stay Later (FR-57).
- **Negative marking per quiz (new FR-59):** moved from Later to MVP. FR-44, FR-45 and FR-46 changed to match.
- **Defaults confirmed:** one attempt per assignment, all-or-nothing scoring for multi-correct questions, shuffling in the MVP, and rejecting a CSV file that has any bad row (section 7).
- New IDs are added at the end of the numbering and placed in their capability section, so existing IDs never change.

## 1. How to read this document

- **Functional requirements (FR-n)** say what the system does. Each one is small enough to become one or a few API operations and at least one test. The "Done when" column is the acceptance criterion; write the test from it.
- **Phase tags:** `POC` is built in Phase 1, `MVP` in Phase 2, `Later` in Phase 3 or after. A `POC` requirement may be extended by an `MVP` one; both IDs are listed.
- **Business rules (BR-n)** are the invariants the domain must never break, whichever endpoint is called. They live in the domain model, not in controllers.
- **Use cases (UC-n)** describe the main flows with their alternate and error paths, and reference the FRs and BRs they exercise.
- Non-functional targets (latency, availability, the grace period in seconds, data retention) belong to BAC-7 and are deliberately not fixed here.
- Terms in *italics* on first use are defined in the glossary (section 6).

## 2. Actors

| Actor | Description |
| --- | --- |
| Platform operator | Runs the platform. Creates schools and their first admin. In the POC and MVP this is you. |
| School admin | Manages one school: users, classes, access. Can see all quizzes and results in the school. |
| Teacher | Authors questions and quizzes, schedules them for classes, reviews results. Sees only their own quizzes. |
| Student | Takes quizzes assigned to their class and sees their own results. Usually under 18; may have no email address. |
| System | Scheduled jobs and event consumers: auto-submit, scoring, emails. |

## 3. Functional requirements

### 3.1 Identity (Identity service)

| ID | Requirement | Phase | Done when |
| --- | --- | --- | --- |
| FR-1 | The platform operator creates a *school* with a name and a unique *school code*, plus its first admin account. | POC | The school and admin exist; the admin can log in; a duplicate school code is rejected. |
| FR-2 | An admin creates teacher and student accounts one at a time, with name, *username* and an optional email. | POC | The user can log in; a username already used in the same school is rejected; the same username in another school is allowed. |
| FR-3 | An admin imports students from a CSV file (name, username, class, optional email). The whole file is validated first; if any row is invalid, nothing is imported and every error is reported with its row number. | MVP | A valid 40-row file creates 40 students in their classes; a file with one bad row creates none and reports that row. |
| FR-4 | A user logs in with school code, username and password, and receives a signed access token carrying user ID, school ID and role. | POC | Correct credentials return a token; wrong credentials return a generic error that does not reveal which part was wrong. |
| FR-5 | Access tokens expire after a configured lifetime; an expired token is rejected and the user logs in again. | POC | A request with an expired token is rejected as unauthenticated. |
| FR-6 | An admin resets a user's password to a temporary one. The user must change it at next login before doing anything else. | MVP | After reset, the old password fails; the temporary one only allows changing the password. |
| FR-7 | A user changes their own password by giving the current one. | MVP | The new password works; the old one fails. |
| FR-8 | An admin deactivates or reactivates a user. A deactivated user cannot log in; their attempts and results are kept. | MVP | A deactivated user's login fails; their past results still appear to teachers. |
| FR-9 | Every operation is restricted by *role* (admin, teacher, student) as listed in section 3.7. | POC | Each role-restricted endpoint rejects the other roles. |
| FR-10 | Every operation is restricted to the caller's school. No user can read or change another school's data, even with a valid ID from that school. | MVP | Automated isolation tests with two schools pass for every endpoint. |
| FR-11 | An admin creates *classes* (for example "10-B") and assigns students and teachers to them. A student belongs to one class. | MVP | Students appear in their class roster; a teacher assigned to a class can schedule quizzes for it. |
| FR-12 | Schools sign up themselves; users verify email, reset passwords by email and can sign in with Google. | Later | Phase 3. |

### 3.2 Authoring (Assessment service)

| ID | Requirement | Phase | Done when |
| --- | --- | --- | --- |
| FR-13 | Teachers and admins create and rename *subjects* within their school. | POC | Subjects are listed per school; duplicate names in one school are rejected. |
| FR-14 | A teacher creates a multiple-choice *question*: text, 2 to 6 options, single-correct or multi-correct, at least one correct option, a subject and marks (default 1). | POC | Valid questions are saved to the teacher's *question bank*; a single-correct question with two correct options, or any question with no correct option, is rejected. |
| FR-15 | A teacher edits or archives a question in their bank. Changes never affect quizzes already published. | POC | After editing a question, a published quiz that used it still shows the original text and key. |
| FR-16 | A teacher lists their question bank, filtered by subject, with pagination. | POC | Results are paginated and filtered; another teacher's questions never appear. |
| FR-17 | A teacher creates a *quiz* in Draft: title, subject, instructions, *duration* in minutes and an ordered list of questions from their bank. | POC | The draft is saved and editable; questions can be added, removed and reordered. |
| FR-18 | A teacher previews a quiz exactly as a student would see it, without answer keys and without creating an attempt. | MVP | The preview matches the student paper; no attempt is recorded. |
| FR-19 | A teacher *publishes* a draft. Publishing validates it (at least one question, duration above zero, every question valid) and creates an immutable *snapshot*. | POC | A valid draft becomes Published with snapshot version 1; an invalid one stays Draft with every problem listed. |
| FR-20 | A teacher edits a published quiz. This creates a new draft *quiz version*; publishing it creates a new snapshot. Attempts already started keep the version they started on. | MVP | A student mid-attempt sees no change; a student starting after the new publish gets the new version. |
| FR-21 | A teacher archives a quiz. An archived quiz cannot be started; its results remain available. | MVP | Starting an archived quiz is refused; its results still load. |
| FR-22 | A teacher sets *proctoring flags*: camera required and microphone required. The backend stores them and returns them with the paper; the browser enforces them. | MVP | The flags are saved with the snapshot and present in the paper response. |
| FR-23 | A teacher sets *release settings* per quiz, each on or off: (a) show score, (b) show correct answers, (c) show rank and percentile. Defaults: score on, correct answers off, rank and percentile off. The teacher can change them at any time, including after the quiz closes (BR-17). | MVP | Each setting alone controls what students see. Correct answers and rank appear only after *quiz close*. Turning a setting on after close releases it immediately; turning it off hides it again in the app. |
| FR-24 | A teacher enables shuffling of question order and option order. Each student gets a stable order for their whole attempt. | MVP | Two students see different orders; one student sees the same order after resuming. |
| FR-25 | True/false, numeric and short-text questions; tags and search in the question bank. | Later | Phase 3. |
| FR-26 | Questions from images, and AI-generated questions from a topic description, both reviewed by the teacher before use. | Later | Phase 5. |
| FR-59 | A teacher sets *negative marking* per quiz: off (default), or a penalty per wrong answer of 1/4, 1/2 or all of that question's marks. Unanswered questions are never penalised. The setting is part of the snapshot, so it cannot change once published (BR-3). | MVP | A quiz published with 1/4 penalty deducts 1 mark for a wrong answer on a 4-mark question and nothing for an unanswered one; editing the penalty after publishing creates a new version. |

### 3.3 Scheduling (Assessment service)

| ID | Requirement | Phase | Done when |
| --- | --- | --- | --- |
| FR-27 | A teacher *assigns* a published quiz to one or more of their classes. | MVP | Only students in those classes see and can start it. In the POC, any student in the school can start any published quiz. |
| FR-28 | A teacher sets a *start window* for each assignment: opens-at and last-start-at, in IST in the interface and stored in UTC. | MVP | Starts before opens-at or after last-start-at are refused. |
| FR-29 | A teacher changes or cancels an assignment until its window opens. | MVP | Changes before opens-at succeed; changes after are refused (BR-12). |
| FR-30 | A student sees their quizzes grouped as Upcoming, Open now and Completed, with times in IST. | MVP | Each assigned quiz appears in exactly one group, matching the server's clock. |
| FR-31 | Students who have an email address get a reminder before the window opens. | MVP | The reminder is sent once per student per assignment. |

### 3.4 Exam delivery (Exam Delivery service)

| ID | Requirement | Phase | Done when |
| --- | --- | --- | --- |
| FR-32 | A student starts an *attempt* on a quiz open to them. The server records the start time, computes the *deadline* and returns the *paper*: questions and options without answer keys. | POC | The response has no correct-answer data; the deadline equals start time plus duration. |
| FR-33 | Starting again while an attempt is active returns the same attempt instead of creating a new one. | POC | Two start calls, including concurrent ones, produce one attempt (BR-5). |
| FR-34 | A student saves an answer for a question. A later save for the same question replaces the earlier one. | POC | The latest saved answer is the one scored. |
| FR-35 | *Autosave* is safe to retry: a repeated or out-of-order save request never overwrites a newer answer or creates a duplicate. | MVP | Replaying the same save, or an older save arriving late, leaves the newest answer in place. |
| FR-36 | A student resumes an active attempt from any device after a disconnect: the paper, their saved answers and the remaining time come from the server. | MVP | After a simulated drop, resume returns all saved answers and a remaining time that kept running during the drop. |
| FR-37 | Every paper, save and resume response includes the server's remaining time, so the client timer can resynchronise. | MVP | Remaining time in responses matches the deadline minus server time. |
| FR-38 | A student submits the attempt. Submission is final. | POC | After submit, further saves are refused and the attempt is scored. |
| FR-39 | Duplicate or concurrent submit requests result in exactly one submission and return the same result. | MVP | Two simultaneous submits with the same *idempotency key*, or retried after a timeout, give one submission and one score. |
| FR-40 | The server refuses saves and submits that arrive after the deadline plus the *grace period*. | POC | A save after deadline plus grace is refused with a clear "deadline passed" error; one within grace is accepted. |
| FR-41 | The system *auto-submits* every attempt still active at its deadline, using the answers saved so far. | MVP | An abandoned attempt is submitted and scored shortly after its deadline without any client action. |
| FR-42 | The server refuses to start an attempt when the quiz is not published, is archived, is not assigned to the student's class, or its start window is not open; each case has its own error. | POC (not published), MVP (other cases) | Each refusal returns its distinct error type. |

### 3.5 Scoring (Exam Delivery service)

| ID | Requirement | Phase | Done when |
| --- | --- | --- | --- |
| FR-43 | The system scores an attempt as soon as it is submitted, manually or automatically, using the answer key of the snapshot version the attempt started on. | POC | The score exists immediately after submit and matches a hand-calculated score. |
| FR-44 | Single-correct question: full marks if the chosen option is correct; otherwise the answer is wrong. Multi-correct question: full marks only if the chosen set equals the correct set exactly; any other non-empty choice is wrong. A wrong answer scores zero, or minus the penalty when negative marking is on (FR-59, MVP). Unanswered: zero, never penalised. | POC (penalty: MVP) | Parameterised tests cover each case, with and without a penalty, including a partly correct multi-correct answer counting as wrong. |
| FR-45 | The *score* stores total marks obtained, total marks possible and a percentage, using exact decimal types. With negative marking, marks obtained can be below zero. | POC | No rounding drift in totals; percentage is rounded to two decimals only for display; a negative total is stored and shown as negative. |
| FR-46 | Partial credit for multi-correct questions, and rescoring all attempts after a teacher corrects an answer key. | Later | Phase 3 or later. |

### 3.6 Results and notifications (Exam Delivery and Notification services)

| ID | Requirement | Phase | Done when |
| --- | --- | --- | --- |
| FR-47 | A student sees their own score after submitting, if score release is on (FR-23). In the POC the score is always shown. | POC (setting: MVP) | The student can read their score only when released; never another student's. |
| FR-48 | A student sees their answers beside the correct answers after the quiz closes, if correct-answer release is on (FR-23). | MVP | Answers are hidden before quiz close or when the setting is off. |
| FR-49 | A teacher lists the attempts and scores for their own quiz, with pagination. | POC | Only the owning teacher (and admins) can list them. |
| FR-50 | Per assignment, a teacher sees each student's status (submitted, auto-submitted, in progress, not attempted), score, rank and percentile, and the class average. | MVP | Students who never started appear as not attempted; the average and ranks exclude them. Teachers see ranks whatever the release settings. |
| FR-51 | A teacher opens one student's attempt and sees each answer against the snapshot's key. | MVP | The view shows the exact version the student took. |
| FR-52 | A teacher exports an assignment's results as a CSV file, including score, rank and percentile. | MVP | The CSV has one row per student, including not attempted, and opens correctly in Excel. |
| FR-53 | When a quiz closes, the teacher receives an email with the class average and a link to the results. | MVP | One email per assignment, sent after quiz close. |
| FR-54 | Students with an email address receive a result email after the quiz closes. It contains only what the release settings allow when it is sent. | MVP | No email for students without an address, none before quiz close, and none when nothing is released. |
| FR-55 | Failed emails are retried and eventually parked for inspection. Email failures never affect exams or results. | MVP | With the email provider down, exams complete and results load; emails go out once it recovers. |
| FR-56 | An admin views results for any quiz in their school. | MVP | Admin sees every teacher's results in the school; none from other schools. |
| FR-57 | Rankings across classes and quizzes, top N per section, question difficulty and large exports delivered by link. | Later | Phase 3. |
| FR-58 | When a quiz closes, the system computes each submitted attempt's *rank* and *percentile* within its assignment (BR-18). A student sees only their own rank and percentile, and only if rank release is on (FR-23). | MVP | Ties share a rank (scores 9, 8, 8, 6 rank 1, 2, 2, 4); the top score has percentile 100; no response to a student ever contains another student's name, score or rank. |

### 3.7 Access summary

| Capability | Operator | Admin | Teacher | Student |
| --- | --- | --- | --- | --- |
| Create school | Yes | No | No | No |
| Manage users and classes | No | Own school | No | No |
| Manage subjects | No | Own school | Own school | No |
| Questions and quizzes | No | Read, own school | Own only | No |
| Assign and schedule | No | No | Own quizzes, own classes | No |
| Change release settings | No | No | Own quizzes | No |
| Take quiz | No | No | No | Assigned only |
| View results | No | Own school | Own quizzes | Own attempts |

## 4. Business rules

| ID | Rule |
| --- | --- |
| BR-1 | Every record belongs to exactly one school. Data never crosses schools. |
| BR-2 | A user belongs to exactly one school and has exactly one role. A username is unique within its school. |
| BR-3 | A published quiz version is immutable. Any change creates a new version. |
| BR-4 | An attempt is bound to the snapshot version it started on, for its paper and for scoring. |
| BR-5 | A student has at most one active attempt per quiz. |
| BR-6 | In the POC and MVP, a student gets one attempt per quiz assignment. A submitted attempt cannot be reopened. |
| BR-7 | The server owns time. The deadline is start time plus duration, computed and stored by the server. The client timer is display only. |
| BR-8 | An answer counts only if the server received it by the deadline plus the grace period. The grace period's value is set in BAC-7. |
| BR-9 | For each question, the most recent answer received before the cut-off counts. |
| BR-10 | Submission is final and happens exactly once per attempt, whether by the student or by auto-submit. |
| BR-11 | Scores are computed by the server from the snapshot's answer key and negative-marking setting only. The client never receives the key unless the quiz has closed and correct-answer release is on. |
| BR-12 | An assignment's classes and start window can change only before the window opens. |
| BR-13 | A quiz closes at the last-start-at time plus the duration (plus grace). No attempt on that assignment can be active after it. Correct answers, ranks, percentiles and result emails are released only after close, and only as the release settings allow. |
| BR-14 | A question used in a published quiz can be archived but not deleted. A quiz with attempts can be archived but not deleted. |
| BR-15 | Deactivating a user never deletes their attempts or results. |
| BR-16 | Every write that a client may retry (start, save, submit) is idempotent. |
| BR-17 | Release settings are not part of the snapshot, because they never change a score; the teacher can change them at any time. Negative marking is part of the snapshot, because it does change scores. |
| BR-18 | Rank and percentile are computed among the submitted attempts of one assignment; students who did not attempt are excluded. Equal scores share a rank and the next rank is skipped (1, 2, 2, 4). Percentile = 100 × (attempts with a score less than or equal to this one) ÷ (all submitted attempts), to two decimals, so the top score is always 100. |
| BR-19 | A student only ever sees their own result. No student-facing response contains another student's name, score, rank or answers. |

## 5. Use cases

### UC-1 Set up a school and its roster

- **Actors:** platform operator, school admin
- **Precondition:** none
- **Main flow:**
    1. The operator creates the school with a school code and its first admin (FR-1).
    2. The admin logs in (FR-4) and creates classes (FR-11).
    3. The admin creates teachers (FR-2) and imports students from a CSV (FR-3).
    4. The admin shares each user's school code, username and temporary password.
- **Alternate and error paths:**
    - 3a. The CSV has invalid rows (missing class, duplicate username): nothing is imported and every bad row is listed (FR-3).
    - 3b. A student leaves the school: the admin deactivates them; their results stay (FR-8, BR-15).
- **Postcondition:** every teacher and student can log in and belongs to the right class.

### UC-2 Log in

- **Actor:** any user
- **Main flow:**
    1. The user enters school code, username and password (FR-4).
    2. The system returns a token scoped to the user's school and role.
- **Alternate and error paths:**
    - 1a. Wrong credentials: generic error, no hint about which part was wrong.
    - 1b. Temporary password: the user must set a new password first (FR-6).
    - 1c. Deactivated user: login is refused (FR-8).
    - 2a. Token expired mid-session: the next request is refused and the user logs in again (FR-5). During an exam the attempt is unaffected, because its state is on the server (FR-36).

### UC-3 Author and publish a quiz

- **Actor:** teacher
- **Precondition:** the teacher is logged in; the subject exists.
- **Main flow:**
    1. The teacher adds questions to their bank (FR-14).
    2. The teacher creates a draft quiz and adds questions in order (FR-17).
    3. The teacher sets proctoring flags, release settings, shuffling and negative marking (FR-22 to FR-24, FR-59).
    4. The teacher previews the quiz (FR-18).
    5. The teacher publishes it; a snapshot is created (FR-19, BR-3).
- **Alternate and error paths:**
    - 5a. Validation fails (no questions, invalid question): the quiz stays Draft and every problem is listed.
    - 6a. The teacher finds a typo after publishing: editing creates a new version; students who already started keep theirs (FR-20, BR-4).
    - 6b. A question in the quiz is later edited in the bank: the published quiz is unchanged (FR-15).
- **Postcondition:** the quiz is Published with an immutable snapshot.

### UC-4 Schedule a quiz for a class

- **Actor:** teacher
- **Precondition:** the quiz is published; the teacher teaches the class.
- **Main flow:**
    1. The teacher assigns the quiz to one or more classes (FR-27).
    2. The teacher sets opens-at and last-start-at (FR-28).
    3. Students in those classes see it under Upcoming (FR-30); those with email get a reminder (FR-31).
- **Alternate and error paths:**
    - 2a. last-start-at is before opens-at, or opens-at is in the past: rejected.
    - 4a. The teacher changes the window before it opens: allowed (FR-29).
    - 4b. The teacher tries to change it after it opens: refused (BR-12).

### UC-5 Take a timed quiz

- **Actor:** student; System for auto-submit
- **Precondition:** the quiz is assigned to the student's class and its window is open.
- **Main flow:**
    1. The student opens the quiz and starts the attempt (FR-32).
    2. The server records the deadline and returns the paper, flags and remaining time.
    3. The student answers; each answer is saved as they go (FR-34, FR-35).
    4. The student submits (FR-38).
    5. The system scores the attempt (FR-43) and the student sees their score, if score release is on (FR-47).
- **Alternate and error paths:**
    - **1a. Late join:** the student tries to start after last-start-at. Refused with "start window closed" (FR-42). No attempt is created.
    - **1b. Early:** the student tries before opens-at. Refused with "not open yet".
    - **1c. Start tapped twice, or a second device:** the same active attempt is returned (FR-33, BR-5).
    - **3a. Network drop:** saves fail on the client. When the connection returns, the student resumes and gets all answers the server received and the remaining time, which kept running (FR-36, FR-37). Answers the server never received must be re-entered; the client should retry unsent saves first.
    - **3b. Save retried or delivered out of order:** the newest answer wins; no duplicates (FR-35, BR-9).
    - **4a. Duplicate submit:** the student taps Submit twice, or the client retries after a timeout. Exactly one submission and one score; both calls return the same result (FR-39, BR-10).
    - **4b. Deadline passed:** the student never submits (phone died, walked away). At the deadline the system auto-submits with saved answers and scores it (FR-41).
    - **4c. Answer after deadline:** a save or submit arrives after deadline plus grace. Refused with "deadline passed"; the attempt is auto-submitted with what was saved before (FR-40, BR-8).
    - **4d. Quiz edited mid-attempt:** the student continues on the version they started (BR-4).
- **Postcondition:** exactly one submitted, scored attempt exists for the student.

### UC-6 Review results

- **Actors:** teacher, admin, student
- **Precondition:** at least one attempt is submitted.
- **Main flow:**
    1. When the quiz closes, the teacher gets an email with the class average and a link (FR-53).
    2. The system computes ranks and percentiles (FR-58). The teacher sees each student's status, score, rank and percentile, and the class average (FR-50).
    3. The teacher opens one student's attempt (FR-51).
    4. The teacher exports the results as CSV (FR-52).
    5. Students see what the release settings allow: score (FR-47), correct answers (FR-48), rank and percentile (FR-58). Those with an email address get a result email (FR-54).
- **Alternate and error paths:**
    - 1a. The email provider is down: the email is retried later; results are already available in the app (FR-55).
    - 2a. A student never started: shown as not attempted and excluded from the average.
    - 3a. A student disputes a score: the teacher compares the answers with the key of the exact version taken (FR-51, BR-4).
    - 5a. A release setting is off, or the quiz has not closed: that item is hidden from students.
    - 5b. The teacher releases correct answers a day after the quiz: students see them from that moment; scores and ranks do not change (BR-17).
    - 5c. A student scored below zero with negative marking: the negative total is shown as it is, and ranks still order correctly.

## 6. Glossary

| Term | Meaning |
| --- | --- |
| School (tenant) | An organisation using the platform, either a school or a coaching institute. All its data is isolated from other schools. |
| School code | A short unique code identifying a school at login, because usernames are unique only within a school. |
| Username | A user's login name, unique within the school. Used because many students have no email. |
| Role | Admin, teacher or student. Decides what a user may do. |
| Class | A group of students taught together, such as "10-B". Quizzes are assigned to classes. |
| Subject | A subject area such as Mathematics, used to organise questions and quizzes. |
| Question | A multiple-choice item with text, options, the correct option or options, and marks. |
| Question bank | A teacher's collection of reusable questions. |
| Quiz | A titled, ordered set of questions with a duration and settings. Moves from Draft to Published to Archived. |
| Quiz version | One numbered revision of a quiz. Editing a published quiz creates a new version. |
| Snapshot | The frozen copy of a quiz version made at publish time: questions, options, keys, marks and settings. Exams and scoring use only snapshots. |
| Assignment | A published quiz given to one or more classes with a start window. |
| Start window | The period in which students may start: from opens-at to last-start-at. |
| Duration | The time a student has once they start. |
| Deadline | Start time plus duration for one attempt, set by the server. |
| Grace period | A few seconds after the deadline during which late-arriving answers are still accepted, to absorb network delay. Value set in BAC-7. |
| Quiz close | Last-start-at plus duration plus grace. After it, no attempt on the assignment can be active, and results are released. |
| Attempt | One student's sitting of one quiz version, from start to submission. |
| Paper | The questions and options sent to a student for an attempt, without answer keys. |
| Answer | A student's selected option or options for one question in an attempt. |
| Autosave | Saving each answer to the server as the student goes, so nothing is lost if the device or network fails. |
| Submission | Ending an attempt, by the student or by auto-submit. Final and exactly once. |
| Auto-submit | The system submitting an attempt still active at its deadline, with the answers saved so far. |
| Score | Marks obtained, marks possible and percentage for one submitted attempt. Can be negative when negative marking is on. |
| Negative marking | A per-quiz penalty for a wrong answer: 1/4, 1/2 or all of the question's marks. Unanswered questions are never penalised. |
| Release settings | Three per-quiz switches the teacher controls: show score, show correct answers, show rank and percentile. |
| Rank | A student's position among the submitted attempts of an assignment; equal scores share a rank. |
| Percentile | The share of submitted attempts in an assignment that scored less than or equal to this one, as a number from 0 to 100. |
| Proctoring flags | Camera required and microphone required. Stored by the backend, enforced by the browser. |
| Idempotency key | A client-generated ID sent with a retryable request, so a repeat is recognised and not applied twice. |

## 7. Decisions

### 7.1 Decided (26 Oct 2026)

| Question | Decision | Where it matters |
| --- | --- | --- |
| What do students see after a quiz? | The teacher chooses per quiz: score, correct answers, rank and percentile, each on or off. Defaults: score on, the other two off. | FR-23, FR-47, FR-48, FR-58, BR-13, BR-17 |
| Negative marking | The teacher chooses per quiz, in the MVP. Default off. | FR-44, FR-45, FR-59 |
| Can a teacher allow more than one attempt? | No, one attempt per assignment in POC and MVP. Multiple attempts can come later. | BR-5, BR-6 |
| Multi-correct scoring | All or nothing; partial credit later. | FR-44, FR-46 |
| Shuffling questions and options | In the MVP, to reduce copying in a classroom. | FR-24 |
| CSV import when some rows are bad | Reject the whole file and list every error. | FR-3 |

### 7.2 Details proposed with the new decisions, to confirm

| Question | Proposed | Why |
| --- | --- | --- |
| Penalty sizes | 1/4, 1/2 or all of the question's marks | 1/4 covers the common +4/−1 entrance-exam pattern. 1/3 needs a rounding rule for exact decimals, so it waits. |
| Can a total score be negative? | Yes, stored and shown as negative | Matches how entrance exams report scores; clamping at zero would hide guessing. |
| Rank ties | Equal scores share a rank and the next is skipped (1, 2, 2, 4) | The usual competition ranking students already know. |
| Percentile formula | 100 × (attempts scoring ≤ this one) ÷ (all submitted attempts) | Same idea as NTA percentiles: the top score is always 100. |
| Rank group | Within one assignment, across all classes it was assigned to | Comparable students sat the same paper in the same window. |
| Settings that can change after publishing | Release settings yes; negative marking no | Release settings never change a score; a penalty does (BR-17). |

### 7.3 Still open

| Question | Why it matters |
| --- | --- |
| Is the pilot a school or a coaching institute? | Batch sizes and how much negative marking is used |

## 8. Requirements count

| Capability | POC | MVP | Later |
| --- | --- | --- | --- |
| Identity | 5 | 6 | 1 |
| Authoring | 6 | 7 | 2 |
| Scheduling | 0 | 5 | 0 |
| Exam delivery | 6 | 5 | 0 |
| Scoring | 3 | 0 | 1 |
| Results and notifications | 2 | 9 | 1 |
| **Total** | **22** | **32** | **5** |

FR-42, FR-44 and FR-47 are counted as POC; their MVP extensions (window checks, the penalty, the release setting) are built with the MVP features they depend on.

## 9. Review questions for you

Answer these before we close BAC-6; I'll push back on each.

- [ ] A student's network drops for three minutes in a 30-minute quiz. Walk through exactly what they see when they return, and which FRs and BRs make that happen.
- [ ] Why does the deadline come from the server and not the student's phone? What breaks if it doesn't?
- [ ] Pick FR-39. Write its acceptance criterion in Given/When/Then form, then name the test you would write first.
- [ ] Why is "one active attempt per student per quiz" a business rule and not just a check in the start endpoint?
- [ ] Which FR here would you cut if the MVP had to ship two weeks earlier, and why?
- [ ] Why are release settings kept outside the immutable snapshot, while negative marking is inside it?
