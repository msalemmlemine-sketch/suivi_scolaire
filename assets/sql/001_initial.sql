-- Suivi Scolaire - schema v1
-- Statements are separated by a line containing only "-- @@" (triggers contain ';').
-- Dates: ISO 'YYYY-MM-DD'. Times: 'HH:MM'. Timestamps: ISO 8601 UTC text.

CREATE TABLE institutions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name_ar TEXT, name_fr TEXT, short_name TEXT, address TEXT, phone TEXT, email TEXT,
  logo_path TEXT, notes TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (length(trim(coalesce(name_ar,''))) > 0 OR length(trim(coalesce(name_fr,''))) > 0)
);
-- @@
CREATE TABLE academic_years (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  start_date TEXT NOT NULL, end_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'current' CHECK (status IN ('current','archived')),
  CHECK (end_date > start_date)
);
-- @@
-- Active year per institution (years may differ between institutions).
CREATE TABLE institution_academic_years (
  institution_id INTEGER NOT NULL REFERENCES institutions(id) ON DELETE RESTRICT,
  academic_year_id INTEGER NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
  is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0,1)),
  PRIMARY KEY (institution_id, academic_year_id)
);
-- @@
CREATE UNIQUE INDEX ux_inst_year_one_active ON institution_academic_years(institution_id) WHERE is_active = 1;
-- @@
CREATE TABLE classes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  institution_id INTEGER NOT NULL REFERENCES institutions(id) ON DELETE RESTRICT,
  academic_year_id INTEGER NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
  name_fr TEXT NOT NULL CHECK (length(trim(name_fr)) > 0),
  name_ar TEXT, level TEXT, track TEXT, notes TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
  UNIQUE (institution_id, academic_year_id, name_fr),
  UNIQUE (id, institution_id, academic_year_id),
  UNIQUE (id, institution_id)
);
-- @@
CREATE TABLE students (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  matricule TEXT,
  family_name_fr TEXT, given_name_fr TEXT, full_name_ar TEXT,
  full_name_original TEXT,            -- name exactly as imported/typed, never rewritten
  gender TEXT CHECK (gender IS NULL OR gender IN ('M','F')),
  birth_date TEXT, guardian_name TEXT, guardian_phone TEXT, notes TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (length(trim(coalesce(family_name_fr,'')||coalesce(given_name_fr,'')||coalesce(full_name_ar,'')||coalesce(full_name_original,''))) > 0)
);
-- @@
CREATE INDEX ix_students_matricule ON students(matricule) WHERE matricule IS NOT NULL;
-- @@
CREATE INDEX ix_students_names ON students(family_name_fr, given_name_fr);
-- @@
CREATE TABLE enrollments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  institution_id INTEGER NOT NULL,
  academic_year_id INTEGER NOT NULL,
  class_id INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','transferred','ended','archived')),
  start_date TEXT NOT NULL, end_date TEXT, end_reason TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (class_id, institution_id, academic_year_id) REFERENCES classes(id, institution_id, academic_year_id) ON DELETE RESTRICT,
  UNIQUE (id, class_id),
  CHECK (end_date IS NULL OR end_date >= start_date),
  CHECK ((status = 'active') = (end_date IS NULL))
);
-- @@
-- Core rule: at most ONE active enrollment per student per academic year (hence never two institutions).
CREATE UNIQUE INDEX ux_one_active_enrollment ON enrollments(student_id, academic_year_id) WHERE status = 'active';
-- @@
CREATE INDEX ix_enroll_class ON enrollments(class_id, status);
-- @@
CREATE INDEX ix_enroll_inst_year ON enrollments(institution_id, academic_year_id);
-- @@
CREATE TABLE subjects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name_ar TEXT, name_fr TEXT, code TEXT, description TEXT,
  CHECK (length(trim(coalesce(name_ar,''))) > 0 OR length(trim(coalesce(name_fr,''))) > 0)
);
-- @@
CREATE TABLE teaching_assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  institution_id INTEGER NOT NULL, academic_year_id INTEGER NOT NULL, class_id INTEGER NOT NULL,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  weekly_sessions INTEGER CHECK (weekly_sessions IS NULL OR weekly_sessions >= 0),
  FOREIGN KEY (class_id, institution_id, academic_year_id) REFERENCES classes(id, institution_id, academic_year_id) ON DELETE RESTRICT,
  UNIQUE (class_id, subject_id)
);
-- @@
CREATE TABLE timetable_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  institution_id INTEGER NOT NULL, academic_year_id INTEGER NOT NULL, class_id INTEGER NOT NULL,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),   -- 1=Mon .. 7=Sun
  start_time TEXT NOT NULL CHECK (start_time GLOB '[0-2][0-9]:[0-5][0-9]'),
  end_time TEXT NOT NULL CHECK (end_time GLOB '[0-2][0-9]:[0-5][0-9]'),
  room TEXT, notes TEXT,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  FOREIGN KEY (class_id, institution_id, academic_year_id) REFERENCES classes(id, institution_id, academic_year_id) ON DELETE RESTRICT,
  UNIQUE (id, class_id),
  CHECK (end_time > start_time)
);
-- @@
CREATE INDEX ix_tt_day ON timetable_entries(academic_year_id, day_of_week, start_time);
-- @@
-- The teacher is one person: active slots must not overlap on the same day of the same year.
CREATE TRIGGER trg_tt_no_overlap_ins BEFORE INSERT ON timetable_entries
WHEN NEW.is_active = 1 AND EXISTS (
  SELECT 1 FROM timetable_entries e WHERE e.is_active = 1 AND e.academic_year_id = NEW.academic_year_id
    AND e.day_of_week = NEW.day_of_week AND NEW.start_time < e.end_time AND NEW.end_time > e.start_time)
BEGIN SELECT RAISE(ABORT, 'timetable_overlap'); END;
-- @@
CREATE TRIGGER trg_tt_no_overlap_upd BEFORE UPDATE ON timetable_entries
WHEN NEW.is_active = 1 AND EXISTS (
  SELECT 1 FROM timetable_entries e WHERE e.id <> NEW.id AND e.is_active = 1 AND e.academic_year_id = NEW.academic_year_id
    AND e.day_of_week = NEW.day_of_week AND NEW.start_time < e.end_time AND NEW.end_time > e.start_time)
BEGIN SELECT RAISE(ABORT, 'timetable_overlap'); END;
-- @@
CREATE TABLE lesson_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timetable_entry_id INTEGER,
  institution_id INTEGER NOT NULL, academic_year_id INTEGER NOT NULL, class_id INTEGER NOT NULL,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  session_date TEXT NOT NULL,
  actual_start TEXT, actual_end TEXT,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','done','cancelled','made_up')),
  topic TEXT, notes TEXT,
  FOREIGN KEY (class_id, institution_id, academic_year_id) REFERENCES classes(id, institution_id, academic_year_id) ON DELETE RESTRICT,
  FOREIGN KEY (timetable_entry_id, class_id) REFERENCES timetable_entries(id, class_id) ON DELETE RESTRICT,
  UNIQUE (id, class_id)
);
-- @@
CREATE UNIQUE INDEX ux_session_entry_date ON lesson_sessions(timetable_entry_id, session_date) WHERE timetable_entry_id IS NOT NULL;
-- @@
CREATE INDEX ix_sessions_class_date ON lesson_sessions(class_id, session_date);
-- @@
CREATE TABLE attendance_statuses (      -- editable list; 'kind' drives the statistics
  code TEXT PRIMARY KEY,
  label_ar TEXT NOT NULL, label_fr TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('present','absent','late','left_early','unresolved')),
  excused INTEGER CHECK (excused IS NULL OR excused IN (0,1)),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  sort_order INTEGER NOT NULL DEFAULT 0
);
-- @@
CREATE TABLE attendance_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  lesson_session_id INTEGER NOT NULL, enrollment_id INTEGER NOT NULL, class_id INTEGER NOT NULL,
  status_code TEXT NOT NULL REFERENCES attendance_statuses(code) ON DELETE RESTRICT,
  late_minutes INTEGER CHECK (late_minutes IS NULL OR late_minutes >= 0),
  note TEXT,
  recorded_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (lesson_session_id, class_id) REFERENCES lesson_sessions(id, class_id) ON DELETE RESTRICT,
  FOREIGN KEY (enrollment_id, class_id) REFERENCES enrollments(id, class_id) ON DELETE RESTRICT,
  UNIQUE (lesson_session_id, enrollment_id)
);
-- @@
CREATE INDEX ix_att_enrollment ON attendance_records(enrollment_id);
-- @@
CREATE TRIGGER trg_att_session_not_cancelled BEFORE INSERT ON attendance_records
WHEN (SELECT status FROM lesson_sessions WHERE id = NEW.lesson_session_id) = 'cancelled'
BEGIN SELECT RAISE(ABORT, 'session_cancelled'); END;
-- @@
CREATE TABLE behavior_categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name_ar TEXT NOT NULL, name_fr TEXT NOT NULL,
  polarity TEXT NOT NULL CHECK (polarity IN ('positive','negative')),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  UNIQUE (name_fr, polarity)
);
-- @@
CREATE TABLE behavior_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  enrollment_id INTEGER NOT NULL REFERENCES enrollments(id) ON DELETE RESTRICT,
  category_id INTEGER NOT NULL REFERENCES behavior_categories(id) ON DELETE RESTRICT,
  record_date TEXT NOT NULL,
  severity INTEGER NOT NULL DEFAULT 1 CHECK (severity BETWEEN 1 AND 5),
  description TEXT, action_taken TEXT, teacher_notes TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
-- @@
CREATE INDEX ix_beh_enrollment_date ON behavior_records(enrollment_id, record_date);
-- @@
CREATE TABLE assessment_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  label_ar TEXT NOT NULL, label_fr TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
);
-- @@
CREATE TABLE assessments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  institution_id INTEGER NOT NULL, academic_year_id INTEGER NOT NULL, class_id INTEGER NOT NULL,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  type_id INTEGER NOT NULL REFERENCES assessment_types(id) ON DELETE RESTRICT,
  title TEXT NOT NULL CHECK (length(trim(title)) > 0),
  assessment_date TEXT NOT NULL,
  period INTEGER CHECK (period IS NULL OR period >= 1),
  max_score REAL NOT NULL CHECK (max_score > 0),
  coefficient REAL NOT NULL DEFAULT 1 CHECK (coefficient > 0),
  description TEXT, notes TEXT,
  FOREIGN KEY (class_id, institution_id, academic_year_id) REFERENCES classes(id, institution_id, academic_year_id) ON DELETE RESTRICT,
  UNIQUE (id, class_id)
);
-- @@
CREATE INDEX ix_assess_class ON assessments(class_id, subject_id, assessment_date);
-- @@
CREATE TABLE assessment_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  assessment_id INTEGER NOT NULL, enrollment_id INTEGER NOT NULL, class_id INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('graded','pending','absent','exempt','not_enrolled')),
  score REAL CHECK (score IS NULL OR score >= 0),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (assessment_id, class_id) REFERENCES assessments(id, class_id) ON DELETE RESTRICT,
  FOREIGN KEY (enrollment_id, class_id) REFERENCES enrollments(id, class_id) ON DELETE RESTRICT,
  UNIQUE (assessment_id, enrollment_id),
  CHECK ((status = 'graded') = (score IS NOT NULL))   -- 0 is a real score; "no score" is NULL, never 0
);
-- @@
CREATE TABLE assessment_result_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  result_id INTEGER NOT NULL, old_status TEXT NOT NULL, old_score REAL,
  changed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
-- @@
CREATE TRIGGER trg_result_history AFTER UPDATE ON assessment_results
WHEN OLD.status IS NOT NEW.status OR OLD.score IS NOT NEW.score
BEGIN INSERT INTO assessment_result_history(result_id, old_status, old_score) VALUES (OLD.id, OLD.status, OLD.score); END;
-- @@
CREATE TRIGGER trg_result_max_ins BEFORE INSERT ON assessment_results
WHEN NEW.score IS NOT NULL
 AND NEW.score > (SELECT max_score FROM assessments WHERE id = NEW.assessment_id)
 AND coalesce((SELECT value FROM app_settings WHERE key = 'allow_score_over_max'), '0') <> '1'
BEGIN SELECT RAISE(ABORT, 'score_over_max'); END;
-- @@
CREATE TRIGGER trg_result_max_upd BEFORE UPDATE ON assessment_results
WHEN NEW.score IS NOT NULL
 AND NEW.score > (SELECT max_score FROM assessments WHERE id = NEW.assessment_id)
 AND coalesce((SELECT value FROM app_settings WHERE key = 'allow_score_over_max'), '0') <> '1'
BEGIN SELECT RAISE(ABORT, 'score_over_max'); END;
-- @@
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY, value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
-- @@
INSERT INTO app_settings(key, value) VALUES
 ('ui_language','ar'), ('report_language','fr'),
 ('allow_score_over_max','0'), ('normalize_scale','20'),
 ('absent_policy','exclude'), ('exempt_policy','exclude'), ('average_mode','weighted');
-- @@
INSERT INTO attendance_statuses(code,label_ar,label_fr,kind,excused,sort_order) VALUES
 ('present','حاضر','Présent','present',NULL,1),
 ('absent','غائب','Absent','absent',NULL,2),
 ('absent_excused','غائب بعذر','Absent justifié','absent',1,3),
 ('absent_unexcused','غائب دون عذر','Absent non justifié','absent',0,4),
 ('late','متأخر','En retard','late',NULL,5),
 ('left_early','مغادر قبل نهاية الحصة','Parti avant la fin','left_early',NULL,6),
 ('unresolved','غير محسومة','Non déterminé','unresolved',NULL,7);
-- @@
INSERT INTO behavior_categories(name_ar,name_fr,polarity) VALUES
 ('المشاركة الفعالة','Participation active','positive'),('الانضباط','Discipline','positive'),
 ('التعاون','Coopération','positive'),('احترام الزملاء','Respect des camarades','positive'),
 ('احترام الأستاذ','Respect de l''enseignant','positive'),('إنجاز الواجبات','Devoirs faits','positive'),
 ('المبادرة','Initiative','positive'),('المحافظة على الممتلكات','Respect du matériel','positive'),
 ('التشويش','Bavardage / perturbation','negative'),('التأخر المتكرر','Retards répétés','negative'),
 ('عدم إنجاز الواجبات','Devoirs non faits','negative'),('مخالفة قواعد القسم','Non-respect du règlement','negative'),
 ('الغياب المتكرر','Absences répétées','negative'),('الاعتداء اللفظي','Violence verbale','negative'),
 ('الاعتداء الجسدي','Violence physique','negative'),('الإضرار بالممتلكات','Dégradation du matériel','negative');
-- @@
INSERT INTO assessment_types(label_ar,label_fr) VALUES
 ('فرض','Devoir'),('اختبار','Examen'),('تقويم قصير','Interrogation'),
 ('واجب','Devoir maison'),('عمل تطبيقي','Travaux pratiques'),('مشاركة','Participation');
