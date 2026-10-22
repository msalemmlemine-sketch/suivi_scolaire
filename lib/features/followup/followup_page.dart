import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../repositories/followup_repository.dart';

/// Behaviour log, assessment creation, mark entry and weighted subject averages.
class FollowupPage extends StatefulWidget {
  const FollowupPage({super.key, required this.db, required this.s});
  final Database db;
  final S s;
  @override
  State<FollowupPage> createState() => _FollowupPageState();
}

class _FollowupPageState extends State<FollowupPage> with SingleTickerProviderStateMixin {
  late final FollowupRepository _repo = FollowupRepository(widget.db);
  late final TabController _tabs = TabController(length: 4, vsync: this);
  List<Map<String,Object?>> _classes=[];
  int? _classId;
  bool _loading=true;
  String? _error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){_tabs.dispose();super.dispose();}

  Future<void> _load() async {
    try {
      final rows=await _repo.activeClasses();
      if(!mounted)return;
      setState((){_classes=rows;if(_classId==null||!rows.any((r)=>r['id']==_classId)){_classId=rows.isEmpty?null:rows.first['id'] as int;}_loading=false;_error=null;});
    } catch (_) {if(mounted)setState((){_loading=false;_error=widget.s.t('load_failed');});}
  }
  String _name(Map<String,Object?> r,String ar,String fr){final a=r[widget.s.isAr?ar:fr] as String?;final b=r[widget.s.isAr?fr:ar] as String?;if(a?.trim().isNotEmpty==true)return a!.trim();return b?.trim()??'';}
  String _studentName(Map<String,Object?> r){final fr=[r['family_name_fr'],r['given_name_fr']].whereType<String>().where((v)=>v.trim().isNotEmpty).join(' ');final ar=(r['full_name_ar'] as String?)?.trim()??'';final original=(r['full_name_original'] as String?)?.trim()??'';return widget.s.isAr?(ar.isNotEmpty?ar:(original.isNotEmpty?original:fr)):(fr.isNotEmpty?fr:(original.isNotEmpty?original:ar));}
  String _className(Map<String,Object?> r)=>'${_name(r,'institution_name_ar','institution_name_fr')} • ${_name(r,'name_ar','name_fr')} • ${r['year_name']??''}';
  void _toast(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> _changed() async {if(!mounted)return;setState((){});}

  @override Widget build(BuildContext context){
    if(_loading)return const Center(child:CircularProgressIndicator());
    if(_error!=null)return Center(child:Text(_error!));
    if(_classes.isEmpty)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(widget.s.t('followup_no_classes'),textAlign:TextAlign.center)));
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,10,12,4),child:DropdownButtonFormField<int>(value:_classId,isExpanded:true,decoration:InputDecoration(labelText:widget.s.t('class'),prefixIcon:const Icon(Icons.school_outlined)),items:_classes.map((r)=>DropdownMenuItem<int>(value:r['id'] as int,child:Text(_className(r),maxLines:2,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>_classId=v))),
      TabBar(controller:_tabs,isScrollable:true,tabs:[Tab(icon:const Icon(Icons.psychology_outlined),text:widget.s.t('behavior')),Tab(icon:const Icon(Icons.assignment_outlined),text:widget.s.t('assessments')),Tab(icon:const Icon(Icons.grading_outlined),text:widget.s.t('marks_averages')),Tab(icon:const Icon(Icons.calculate_outlined),text:widget.s.t('averages'))]),
      Expanded(child:TabBarView(controller:_tabs,children:[_behaviorTab(),_assessmentsTab(),_marksTab(),_averagesTab()])),
    ]);
  }

  Widget _behaviorTab(){
    return FutureBuilder<List<Map<String,Object?>>>(future:_repo.behaviorRecords(_classId!),builder:(context,snap){
      if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(snap.hasError)return Center(child:Text(widget.s.t('load_failed')));
      final rows=snap.data??[];
      return Column(children:[Padding(padding:const EdgeInsets.all(12),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_addBehavior,icon:const Icon(Icons.add),label:Text(widget.s.t('behavior_add'))))),Expanded(child:rows.isEmpty?Center(child:Text(widget.s.t('behavior_empty'))):ListView.builder(itemCount:rows.length,itemBuilder:(context,i){final r=rows[i];final positive=r['polarity']=='positive';return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:ListTile(leading:CircleAvatar(child:Icon(positive?Icons.thumb_up_alt_outlined:Icons.warning_amber_outlined)),title:Text(_studentName(r)),subtitle:Text('${_name(r,'category_ar','category_fr')} • ${r['record_date']}\n${r['description']??''}',maxLines:3,overflow:TextOverflow.ellipsis),isThreeLine:true,trailing:Text('${r['severity']}/5')));})),]);
    });
  }

  Future<void> _addBehavior() async {
    final students=await _repo.studentsForClass(_classId!);final cats=await _repo.behaviorCategories();
    if(!mounted)return;if(students.isEmpty||cats.isEmpty){_toast(widget.s.t('behavior_needs_students'));return;}
    int studentId=students.first['enrollment_id'] as int;int categoryId=cats.first['id'] as int;int severity=1;
    final date=TextEditingController(text:DateTime.now().toIso8601String().substring(0,10));final description=TextEditingController();final action=TextEditingController();final notes=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:Text(widget.s.t('behavior_add')),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,spacing:12,children:[
      DropdownButtonFormField<int>(value:studentId,isExpanded:true,decoration:InputDecoration(labelText:widget.s.t('student')),items:students.map((r)=>DropdownMenuItem(value:r['enrollment_id'] as int,child:Text(_studentName(r),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)setDialog(()=>studentId=v);}),
      DropdownButtonFormField<int>(value:categoryId,isExpanded:true,decoration:InputDecoration(labelText:widget.s.t('behavior_category')),items:cats.map((r)=>DropdownMenuItem(value:r['id'] as int,child:Text(_name(r,'name_ar','name_fr'),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)setDialog(()=>categoryId=v);}),
      TextField(controller:date,decoration:InputDecoration(labelText:widget.s.t('date_iso'))),TextField(controller:description,decoration:InputDecoration(labelText:widget.s.t('behavior_description'))),
      DropdownButtonFormField<int>(value:severity,decoration:InputDecoration(labelText:widget.s.t('severity')),items:List.generate(5,(i)=>DropdownMenuItem(value:i+1,child:Text('${i+1}/5'))),onChanged:(v){if(v!=null)setDialog(()=>severity=v);}),
      TextField(controller:action,decoration:InputDecoration(labelText:widget.s.t('action_taken'))),TextField(controller:notes,decoration:InputDecoration(labelText:widget.s.t('teacher_notes'))),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(widget.s.t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(widget.s.t('save')))])));
    if(ok!=true)return;
    try{await _repo.addBehavior(enrollmentId:studentId,categoryId:categoryId,date:date.text.trim(),severity:severity,description:description.text,actionTaken:action.text,teacherNotes:notes.text);await _changed();}
    catch(_){_toast(widget.s.t('followup_save_error'));}
  }

  Widget _assessmentsTab(){
    return FutureBuilder<List<Map<String,Object?>>>(future:_repo.assessments(_classId!),builder:(context,snap){
      if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snap.hasError)return Center(child:Text(widget.s.t('load_failed')));final rows=snap.data??[];
      return Column(children:[Padding(padding:const EdgeInsets.all(12),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_addAssessment,icon:const Icon(Icons.add),label:Text(widget.s.t('assessment_add'))))),Expanded(child:rows.isEmpty?Center(child:Text(widget.s.t('assessment_empty'))):ListView.builder(itemCount:rows.length,itemBuilder:(context,i){final r=rows[i];return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:ListTile(leading:const CircleAvatar(child:Icon(Icons.assignment_outlined)),title:Text(r['title'] as String),subtitle:Text('${_name(r,'subject_ar','subject_fr')} • ${_name(r,'type_ar','type_fr')}\n${r['assessment_date']} • ${widget.s.t('max_score')}: ${r['max_score']} • ${widget.s.t('coefficient')}: ${r['coefficient']}',maxLines:2,overflow:TextOverflow.ellipsis),isThreeLine:true));}))]);
    });
  }

  Future<bool> _askNewSubject() async {
    final ar=TextEditingController();final fr=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(widget.s.t('subject')),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(widget.s.t('subject_create_hint')),const SizedBox(height:12),
      TextField(controller:fr,decoration:InputDecoration(labelText:widget.s.t('subject_name_fr'))),const SizedBox(height:10),
      TextField(controller:ar,decoration:InputDecoration(labelText:widget.s.t('subject_name_ar'))),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(widget.s.t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(widget.s.t('save')))]));
    if(ok!=true)return false;
    try{await _repo.addSubject(nameAr:ar.text,nameFr:fr.text);return true;}
    catch(_){_toast(widget.s.t('followup_save_error'));return false;}
  }

  Future<void> _addAssessment() async {
    var subjects=await _repo.subjects();final types=await _repo.assessmentTypes();if(!mounted)return;if(types.isEmpty){_toast(widget.s.t('assessment_needs_subjects'));return;}
    if(subjects.isEmpty){final created=await _askNewSubject();if(!created||!mounted)return;subjects=await _repo.subjects();if(subjects.isEmpty)return;}
    int subjectId=subjects.first['id'] as int;int typeId=types.first['id'] as int;final title=TextEditingController();final date=TextEditingController(text:DateTime.now().toIso8601String().substring(0,10));final max=TextEditingController(text:'20');final coefficient=TextEditingController(text:'1');final period=TextEditingController();final description=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:Text(widget.s.t('assessment_add')),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,spacing:12,children:[
      DropdownButtonFormField<int>(value:subjectId,isExpanded:true,decoration:InputDecoration(labelText:widget.s.t('subject')),items:subjects.map((r)=>DropdownMenuItem(value:r['id'] as int,child:Text(_name(r,'name_ar','name_fr'),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)setDialog(()=>subjectId=v);}),
      DropdownButtonFormField<int>(value:typeId,isExpanded:true,decoration:InputDecoration(labelText:widget.s.t('assessment_type')),items:types.map((r)=>DropdownMenuItem(value:r['id'] as int,child:Text(_name(r,'label_ar','label_fr')))).toList(),onChanged:(v){if(v!=null)setDialog(()=>typeId=v);}),
      TextField(controller:title,decoration:InputDecoration(labelText:widget.s.t('assessment_title'))),TextField(controller:date,decoration:InputDecoration(labelText:widget.s.t('date_iso'))),
      TextField(controller:max,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:widget.s.t('max_score'))),TextField(controller:coefficient,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:widget.s.t('coefficient'))),TextField(controller:period,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:widget.s.t('period_optional'))),TextField(controller:description,decoration:InputDecoration(labelText:widget.s.t('notes_optional'))),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(widget.s.t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(widget.s.t('save')))])));
    if(ok!=true)return;
    try{await _repo.addAssessment(classId:_classId!,subjectId:subjectId,typeId:typeId,title:title.text,date:date.text.trim(),maxScore:double.parse(max.text.replaceAll(',','.')),coefficient:double.parse(coefficient.text.replaceAll(',','.')),period:period.text.trim().isEmpty?null:int.parse(period.text.trim()),description:description.text);await _changed();}
    catch(_){_toast(widget.s.t('followup_save_error'));}
  }

  Widget _averagesTab(){
    return FutureBuilder<List<Map<String,Object?>>>(future:_repo.studentSubjectAverages(_classId!),builder:(context,snap){
      if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(snap.hasError)return Center(child:Text(widget.s.t('load_failed')));
      final rows=snap.data??[];
      if(rows.isEmpty)return Center(child:Text(widget.s.t('averages_empty')));
      return ListView.builder(itemCount:rows.length,itemBuilder:(context,i){final r=rows[i];final avg=(r['average20'] as num).toDouble();return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:ListTile(leading:CircleAvatar(child:Text(avg.toStringAsFixed(1))),title:Text(_studentName(r)),subtitle:Text('${_name(r,'subject_ar','subject_fr')} • ${r['graded_count']} ${widget.s.t('graded_assessments')}'),trailing:Text('${avg.toStringAsFixed(2)}/20')));});
    });
  }

  Widget _marksTab(){
    return FutureBuilder<List<Map<String,Object?>>>(future:_repo.assessments(_classId!),builder:(context,snap){
      if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snap.hasError)return Center(child:Text(widget.s.t('load_failed')));final assessments=snap.data??[];
      if(assessments.isEmpty)return Center(child:Text(widget.s.t('assessment_empty')));
      return _MarksContent(key:ValueKey('${_classId}_${assessments.map((a)=>a['id']).join(',')}'),s:widget.s,repo:_repo,assessments:assessments,studentName:_studentName,onSaved:_changed,onMessage:_toast,classId:_classId!);
    });
  }
}

class _MarksContent extends StatefulWidget {
  const _MarksContent({super.key,required this.s,required this.repo,required this.assessments,required this.studentName,required this.onSaved,required this.onMessage,required this.classId});
  final S s;final FollowupRepository repo;final List<Map<String,Object?>> assessments;final String Function(Map<String,Object?>) studentName;final Future<void> Function() onSaved;final void Function(String) onMessage;final int classId;
  @override State<_MarksContent> createState()=>_MarksContentState();
}
class _MarksContentState extends State<_MarksContent> {
  int? _assessmentId;

  String _name(Map<String, Object?> row, String ar, String fr) {
    final preferred = row[widget.s.isAr ? ar : fr] as String?;
    final fallback = row[widget.s.isAr ? fr : ar] as String?;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    return fallback?.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _assessmentId = widget.assessments.first['id'] as int;
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.assessments
        .where((assessment) => assessment['id'] == _assessmentId)
        .toList();
    final chosen = matches.isEmpty ? widget.assessments.first : matches.first;
    final assessmentId = chosen['id'] as int;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<int>(
            value: assessmentId,
            isExpanded: true,
            decoration: InputDecoration(labelText: widget.s.t('assessment')),
            items: widget.assessments.map((assessment) {
              return DropdownMenuItem<int>(
                value: assessment['id'] as int,
                child: Text(
                  '${assessment['title']} • ${_name(assessment, 'subject_ar', 'subject_fr')}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _assessmentId = value),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: widget.repo.resultsForAssessment(assessmentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(widget.s.t('load_failed')));
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return Center(child: Text(widget.s.t('attendance_empty_roster')));
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final status = (row['result_status'] as String?) ?? 'pending';
                  final score = row['score'];
                  final subtitle = '${widget.s.t('result_status')}: '
                      '${widget.s.t(_resultStatusKey(status))}'
                      '${score == null ? '' : ' • $score/${chosen['max_score']}'}';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: ListTile(
                      title: Text(widget.studentName(row)),
                      subtitle: Text(subtitle),
                      trailing: IconButton(
                        tooltip: widget.s.t('enter_mark'),
                        icon: const Icon(Icons.edit_note),
                        onPressed: () => _editResult(chosen, row),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editResult(
    Map<String, Object?> assessment,
    Map<String, Object?> student,
  ) async {
    var status = (student['result_status'] as String?) ?? 'pending';
    final scoreController = TextEditingController(
      text: student['score'] == null ? '' : (student['score'] as num).toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(widget.s.t('enter_mark')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: InputDecoration(labelText: widget.s.t('result_status')),
                items: ['graded', 'pending', 'absent', 'exempt'].map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(widget.s.t(_resultStatusKey(value))),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setDialog(() => status = value);
                },
              ),
              if (status == 'graded')
                TextField(
                  controller: scoreController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${widget.s.t('score')} / ${assessment['max_score']}',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(widget.s.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(widget.s.t('save')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      await widget.repo.saveResult(
        assessmentId: assessment['id'] as int,
        enrollmentId: student['enrollment_id'] as int,
        classId: widget.classId,
        status: status,
        score: status == 'graded'
            ? double.parse(scoreController.text.replaceAll(',', '.'))
            : null,
      );
      if (mounted) setState(() {});
      await widget.onSaved();
    } catch (error) {
      widget.onMessage(
        error.toString().contains('score_over_max')
            ? widget.s.t('score_over_max_error')
            : widget.s.t('followup_save_error'),
      );
    }
  }
}

String _resultStatusKey(String status) {
  switch (status) {
    case 'graded': return 'result_graded';
    case 'absent': return 'result_absent';
    case 'exempt': return 'result_exempt';
    default: return 'result_pending';
  }
}
