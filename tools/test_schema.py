"""Executable check of assets/sql/001_initial.sql constraints (real SQLite, no mocks)."""
import sqlite3, pathlib, sys
SQL = pathlib.Path(__file__).resolve().parent.parent / "assets/sql/001_initial.sql"
def new_db():
    db = sqlite3.connect(":memory:", isolation_level=None); db.execute("PRAGMA foreign_keys=ON")
    for stmt in SQL.read_text(encoding="utf-8").split("\n-- @@\n"):
        db.executescript(stmt)
    return db
def x(db, sql, *a): return db.execute(sql, a).lastrowid
results = []
def check(name):
    def deco(fn):
        try: fn(); results.append((name, True, ""))
        except Exception as e: results.append((name, False, repr(e)))
    return deco
def must_fail(db, sql, *a, contains=None):
    try: db.execute(sql, a)
    except sqlite3.DatabaseError as e:
        if contains and contains not in str(e): raise AssertionError(f"wrong error: {e}")
        return
    raise AssertionError("statement should have failed: " + sql[:60])
def base():
    db = new_db()
    i1 = x(db,"INSERT INTO institutions(name_fr) VALUES('Lycée A')")
    i2 = x(db,"INSERT INTO institutions(name_fr) VALUES('Lycée B')")
    y1 = x(db,"INSERT INTO academic_years(name,start_date,end_date) VALUES('2025-2026','2025-10-01','2026-07-01')")
    y2 = x(db,"INSERT INTO academic_years(name,start_date,end_date) VALUES('2026-2027','2026-10-01','2027-07-01')")
    c = {}
    for k,(i,y,n) in {'a1':(i1,y1,'5SN1'),'a2':(i1,y1,'5SN2'),'b1':(i2,y1,'5SN1'),'a1n':(i1,y2,'6SN1'),'b1n':(i2,y2,'6SN1')}.items():
        c[k] = x(db,"INSERT INTO classes(institution_id,academic_year_id,name_fr) VALUES(?,?,?)",i,y,n)
    s = x(db,"INSERT INTO students(full_name_original) VALUES('Aissata Adama Ba')")
    return db,i1,i2,y1,y2,c,s
def enroll(db,s,i,y,c,status='active',end=None):
    return x(db,"INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date,end_date) VALUES(?,?,?,?,?,'2025-10-05',?)",s,i,y,c,status,end)

@check("same name twice creates two students (no auto-merge)")
def _():
    db=new_db()
    x(db,"INSERT INTO students(full_name_original) VALUES('Aissata Adama Ba')")
    x(db,"INSERT INTO students(full_name_original) VALUES('Aissata Adama Ba')")
    assert db.execute("SELECT count(*) FROM students").fetchone()[0]==2
@check("student without any name rejected")
def _(): must_fail(new_db(),"INSERT INTO students(matricule) VALUES('123')")
@check("two active enrollments, different institutions, same year -> rejected")
def _():
    db,i1,i2,y1,y2,c,s=base(); enroll(db,s,i1,y1,c['a1'])
    must_fail(db,"INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date) VALUES(?,?,?,?, 'active','2025-10-06')",s,i2,y1,c['b1'],contains="UNIQUE")
@check("two active enrollments, same institution, same year -> rejected")
def _():
    db,i1,i2,y1,y2,c,s=base(); enroll(db,s,i1,y1,c['a1'])
    must_fail(db,"INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date) VALUES(?,?,?,?, 'active','2025-10-06')",s,i1,y1,c['a2'],contains="UNIQUE")
@check("enrollment in class of another institution -> rejected (FK)")
def _():
    db,i1,i2,y1,y2,c,s=base()
    must_fail(db,"INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date) VALUES(?,?,?,?, 'active','2025-10-06')",s,i1,y1,c['b1'],contains="FOREIGN KEY")
@check("enrollment in class of another year -> rejected (FK)")
def _():
    db,i1,i2,y1,y2,c,s=base()
    must_fail(db,"INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date) VALUES(?,?,?,?, 'active','2025-10-06')",s,i1,y1,c['a1n'],contains="FOREIGN KEY")
@check("transfer in same year: close old, open new in one transaction, history kept")
def _():
    db,i1,i2,y1,y2,c,s=base(); old=enroll(db,s,i1,y1,c['a1'])
    db.execute("BEGIN")
    db.execute("UPDATE enrollments SET status='transferred',end_date='2025-12-01',end_reason='transfer' WHERE id=?",(old,))
    enroll(db,s,i2,y1,c['b1'])
    db.execute("COMMIT")
    rows=db.execute("SELECT status,institution_id FROM enrollments WHERE student_id=? ORDER BY id",(s,)).fetchall()
    assert rows==[('transferred',i1),('active',i2)],rows
@check("failed transfer rolls back, old enrollment stays active")
def _():
    db,i1,i2,y1,y2,c,s=base(); old=enroll(db,s,i1,y1,c['a1']); db.commit()
    try:
        db.execute("BEGIN")
        db.execute("UPDATE enrollments SET status='transferred',end_date='2025-12-01' WHERE id=?",(old,))
        db.execute("INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date) VALUES(?,?,?,?, 'active','2025-12-01')",(s,i1,y1,c['b1']))  # bad class -> FK error
        db.execute("COMMIT"); raise AssertionError("should fail")
    except sqlite3.IntegrityError: db.execute("ROLLBACK")

    assert db.execute("SELECT status FROM enrollments WHERE id=?",(old,)).fetchone()[0]=='active'
@check("different institution in a later year allowed, history kept")
def _():
    db,i1,i2,y1,y2,c,s=base(); enroll(db,s,i1,y1,c['a1'],'ended','2026-06-30'); enroll(db,s,i2,y2,c['b1n'])
    assert db.execute("SELECT count(*) FROM enrollments WHERE student_id=?",(s,)).fetchone()[0]==2
@check("active enrollment must have no end_date; closed must have one")
def _():
    db,i1,i2,y1,y2,c,s=base()
    must_fail(db,"INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date,end_date) VALUES(?,?,?,?, 'active','2025-10-06','2025-11-01')",s,i1,y1,c['a1'])
    must_fail(db,"INSERT INTO enrollments(student_id,institution_id,academic_year_id,class_id,status,start_date) VALUES(?,?,?,?, 'ended','2025-10-06')",s,i1,y1,c['a1'])
@check("deleting a class/student/institution with history is blocked")
def _():
    db,i1,i2,y1,y2,c,s=base(); enroll(db,s,i1,y1,c['a1'])
    must_fail(db,"DELETE FROM classes WHERE id=?",c['a1'],contains="FOREIGN KEY")
    must_fail(db,"DELETE FROM students WHERE id=?",s,contains="FOREIGN KEY")
    must_fail(db,"DELETE FROM institutions WHERE id=?",i1,contains="FOREIGN KEY")
@check("duplicate class name in same institution+year rejected; same name in other institution ok")
def _():
    db,i1,i2,y1,y2,c,s=base()
    must_fail(db,"INSERT INTO classes(institution_id,academic_year_id,name_fr) VALUES(?,?,'5SN1')",i1,y1,contains="UNIQUE")
@check("duplicate academic year name rejected")
def _():
    db=new_db(); x(db,"INSERT INTO academic_years(name,start_date,end_date) VALUES('2025-2026','2025-10-01','2026-07-01')")
    must_fail(db,"INSERT INTO academic_years(name,start_date,end_date) VALUES('2025-2026','2025-10-01','2026-07-01')",contains="UNIQUE")
@check("only one active year per institution")
def _():
    db,i1,i2,y1,y2,c,s=base()
    x(db,"INSERT INTO institution_academic_years VALUES(?,?,1)",i1,y1)
    must_fail(db,"INSERT INTO institution_academic_years VALUES(?,?,1)",i1,y2,contains="UNIQUE")
    x(db,"INSERT INTO institution_academic_years VALUES(?,?,1)",i2,y1)
def tt(db,i,y,c,subj,day,s,e): return x(db,"INSERT INTO timetable_entries(institution_id,academic_year_id,class_id,subject_id,day_of_week,start_time,end_time) VALUES(?,?,?,?,?,?,?)",i,y,c,subj,day,s,e)
@check("timetable: overlap rejected (even across institutions), adjacent allowed, invalid time rejected")
def _():
    db,i1,i2,y1,y2,c,s=base(); m=x(db,"INSERT INTO subjects(name_fr) VALUES('SVT')")
    tt(db,i1,y1,c['a1'],m,1,'08:00','09:00')
    must_fail(db,"INSERT INTO timetable_entries(institution_id,academic_year_id,class_id,subject_id,day_of_week,start_time,end_time) VALUES(?,?,?,?,1,'08:30','09:30')",i2,y1,c['b1'],m,contains="timetable_overlap")
    tt(db,i2,y1,c['b1'],m,1,'09:00','10:00'); tt(db,i1,y1,c['a2'],m,2,'08:00','09:00')
    must_fail(db,"INSERT INTO timetable_entries(institution_id,academic_year_id,class_id,subject_id,day_of_week,start_time,end_time) VALUES(?,?,?,?,3,'10:00','09:00')",i1,y1,c['a1'],m)
def session(db,i,y,cl,subj,status='done',entry=None,date='2025-11-03'):
    return x(db,"INSERT INTO lesson_sessions(timetable_entry_id,institution_id,academic_year_id,class_id,subject_id,session_date,status) VALUES(?,?,?,?,?,?,?)",entry,i,y,cl,subj,date,status)
@check("attendance: record, no duplicate, no student from another class, no cancelled session")
def _():
    db,i1,i2,y1,y2,c,s=base(); m=x(db,"INSERT INTO subjects(name_fr) VALUES('SVT')")
    e=enroll(db,s,i1,y1,c['a1']); ss=session(db,i1,y1,c['a1'],m); sc=session(db,i1,y1,c['a1'],m,'cancelled',date='2025-11-04'); so=session(db,i1,y1,c['a2'],m,date='2025-11-05'); sb=session(db,i1,y1,c['a1'],m,date='2025-11-06')
    x(db,"INSERT INTO attendance_records(lesson_session_id,enrollment_id,class_id,status_code) VALUES(?,?,?, 'present')",ss,e,c['a1'])
    must_fail(db,"INSERT INTO attendance_records(lesson_session_id,enrollment_id,class_id,status_code) VALUES(?,?,?, 'absent')",ss,e,c['a1'],contains="UNIQUE")
    must_fail(db,"INSERT INTO attendance_records(lesson_session_id,enrollment_id,class_id,status_code) VALUES(?,?,?, 'absent')",so,e,c['a2'],contains="FOREIGN KEY")
    must_fail(db,"INSERT INTO attendance_records(lesson_session_id,enrollment_id,class_id,status_code) VALUES(?,?,?, 'absent')",sc,e,c['a1'],contains="session_cancelled")
    must_fail(db,"INSERT INTO attendance_records(lesson_session_id,enrollment_id,class_id,status_code) VALUES(?,?,?, 'bogus')",sb,e,c['a1'],contains="FOREIGN KEY")
@check("deleting a timetable slot that has sessions is blocked")
def _():
    db,i1,i2,y1,y2,c,s=base(); m=x(db,"INSERT INTO subjects(name_fr) VALUES('SVT')")
    t=tt(db,i1,y1,c['a1'],m,1,'08:00','09:00'); session(db,i1,y1,c['a1'],m,entry=t)
    must_fail(db,"DELETE FROM timetable_entries WHERE id=?",t,contains="FOREIGN KEY")
def assess(db,i,y,cl,m,mx=20,coef=1):
    return x(db,"INSERT INTO assessments(institution_id,academic_year_id,class_id,subject_id,type_id,title,assessment_date,max_score,coefficient) VALUES(?,?,?,?,1,'DS1','2025-11-10',?,?)",i,y,cl,m,mx,coef)
@check("assessments: max 10/20/40/100 ok; <=0 rejected; negative or over-max score rejected; 0 is valid")
def _():
    db,i1,i2,y1,y2,c,s=base(); m=x(db,"INSERT INTO subjects(name_fr) VALUES('SVT')"); e=enroll(db,s,i1,y1,c['a1'])
    for mx in (10,20,40,100): assess(db,i1,y1,c['a1'],m,mx)
    must_fail(db,"INSERT INTO assessments(institution_id,academic_year_id,class_id,subject_id,type_id,title,assessment_date,max_score) VALUES(?,?,?,?,1,'x','2025-11-10',0)",i1,y1,c['a1'],m)
    a=assess(db,i1,y1,c['a1'],m,20)
    must_fail(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status,score) VALUES(?,?,?, 'graded',-1)",a,e,c['a1'])
    must_fail(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status,score) VALUES(?,?,?, 'graded',20.5)",a,e,c['a1'],contains="score_over_max")
    r=x(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status,score) VALUES(?,?,?, 'graded',0)",a,e,c['a1'])
    assert db.execute("SELECT score FROM assessment_results WHERE id=?",(r,)).fetchone()[0]==0
@check("result states: absent/pending must have NULL score; graded must have a score")
def _():
    db,i1,i2,y1,y2,c,s=base(); m=x(db,"INSERT INTO subjects(name_fr) VALUES('SVT')"); e=enroll(db,s,i1,y1,c['a1']); a=assess(db,i1,y1,c['a1'],m)
    must_fail(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status,score) VALUES(?,?,?, 'absent',0)",a,e,c['a1'])
    must_fail(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status) VALUES(?,?,?, 'graded')",a,e,c['a1'])
    x(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status) VALUES(?,?,?, 'absent')",a,e,c['a1'])
@check("over-max score allowed when setting allow_score_over_max=1")
def _():
    db,i1,i2,y1,y2,c,s=base(); m=x(db,"INSERT INTO subjects(name_fr) VALUES('SVT')"); e=enroll(db,s,i1,y1,c['a1']); a=assess(db,i1,y1,c['a1'],m)
    db.execute("UPDATE app_settings SET value='1' WHERE key='allow_score_over_max'")
    x(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status,score) VALUES(?,?,?, 'graded',22)",a,e,c['a1'])
@check("result from another class's student rejected; edits are kept in history")
def _():
    db,i1,i2,y1,y2,c,s=base(); m=x(db,"INSERT INTO subjects(name_fr) VALUES('SVT')"); e=enroll(db,s,i1,y1,c['a1']); a=assess(db,i1,y1,c['a1'],m); a2=assess(db,i1,y1,c['a2'],m)
    must_fail(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status,score) VALUES(?,?,?, 'graded',10)",a2,e,c['a2'],contains="FOREIGN KEY")
    r=x(db,"INSERT INTO assessment_results(assessment_id,enrollment_id,class_id,status,score) VALUES(?,?,?, 'graded',10)",a,e,c['a1'])
    db.execute("UPDATE assessment_results SET score=12 WHERE id=?",(r,))
    assert db.execute("SELECT old_score FROM assessment_result_history WHERE result_id=?",(r,)).fetchall()==[(10.0,)]
@check("seeds present: 7 attendance statuses, 16 behaviors, 6 assessment types, settings")
def _():
    db=new_db(); q=lambda t: db.execute(f"SELECT count(*) FROM {t}").fetchone()[0]
    assert (q('attendance_statuses'),q('behavior_categories'),q('assessment_types'))==(7,16,6)
    assert db.execute("SELECT value FROM app_settings WHERE key='ui_language'").fetchone()[0]=='ar'
@check("Arabic + French names round-trip unchanged")
def _():
    db=new_db(); n="رامتلاي  باباكر  انجوك"; x(db,"INSERT INTO students(full_name_ar,full_name_original) VALUES(?,?)",n,n)
    assert db.execute("SELECT full_name_ar FROM students").fetchone()[0]==n
@check("PRAGMA foreign_key_check clean on populated db")
def _():
    db,i1,i2,y1,y2,c,s=base(); enroll(db,s,i1,y1,c['a1']); assert db.execute("PRAGMA foreign_key_check").fetchall()==[]
ok=sum(1 for _,p,_ in results if p)
for n,p,m in results: print(("PASS " if p else "FAIL ")+n+("" if p else "  -> "+m))
print(f"\n{ok}/{len(results)} passed"); sys.exit(0 if ok==len(results) else 1)
