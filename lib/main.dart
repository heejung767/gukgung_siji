import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';

void main() {
  runApp(const GukgungSijiApp());
}

class GukgungSijiApp extends StatelessWidget {
  const GukgungSijiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '국궁 시지',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D9E75)),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      home: const MainScreen(),
    );
  }
}

// ══════════════════════════════════════════
// 효과음 재생 (전역 헬퍼)
// ══════════════════════════════════════════
final AudioPlayer _arrowPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

Future<void> playArrowSound() async {
  try {
    await _arrowPlayer.stop();
    await _arrowPlayer.play(AssetSource('sounds/arrow_impact.mp3'));
  } catch (_) {
    // 소리 재생 실패해도 앱은 계속 동작
  }
}

// ══════════════════════════════════════════
// 데이터 모델
// ══════════════════════════════════════════
class SijiRecord {
  final String key;
  final String date;
  final String round;
  final List<List<int>> st;
  final String diary;
  final int total;
  // 승단 기록 여부 및 관련 정보 (일반 기록은 기본값 유지, 기존 저장 기록과 호환됨)
  final bool isSeungdan;
  final String? targetGrade;
  final bool? isElderly;
  final bool? passed;

  SijiRecord({
    required this.key,
    required this.date,
    required this.round,
    required this.st,
    required this.diary,
    required this.total,
    this.isSeungdan = false,
    this.targetGrade,
    this.isElderly,
    this.passed,
  });

  Map<String, dynamic> toJson() => {
        'key': key, 'date': date, 'round': round,
        'st': st, 'diary': diary, 'total': total,
        'isSeungdan': isSeungdan,
        'targetGrade': targetGrade,
        'isElderly': isElderly,
        'passed': passed,
      };

  factory SijiRecord.fromJson(Map<String, dynamic> json) => SijiRecord(
        key: json['key'], date: json['date'], round: json['round'],
        st: (json['st'] as List)
            .map((row) => (row as List).map((v) => v as int).toList())
            .toList(),
        diary: json['diary'] ?? '',
        total: json['total'],
        isSeungdan: json['isSeungdan'] ?? false,
        targetGrade: json['targetGrade'],
        isElderly: json['isElderly'],
        passed: json['passed'],
      );
}

// ══════════════════════════════════════════
// 메인 화면
// ══════════════════════════════════════════
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;
  List<SijiRecord> records = [];
  SijiRecord? _recordToLoad;
  int _loadCounter = 0;
  SijiRecord? _seungdanRecordToLoad;
  int _seungdanLoadCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('records');
    if (data != null) {
      final list = jsonDecode(data) as List;
      setState(() {
        records = list.map((e) => SijiRecord.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'records', jsonEncode(records.map((e) => e.toJson()).toList()));
  }

  void _addOrUpdateRecord(SijiRecord record) {
    setState(() {
      final idx = records.indexWhere((r) => r.key == record.key);
      if (idx >= 0) records[idx] = record; else records.add(record);
    });
    _saveRecords();
  }

  void _deleteRecord(String key) {
    setState(() => records.removeWhere((r) => r.key == key));
    _saveRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          InputTab(
            key: ValueKey('input_$_loadCounter'),
            onSave: _addOrUpdateRecord,
            loadRecord: _recordToLoad,
          ),
          RecordsTab(
            records: records,
            onDelete: _deleteRecord,
            onLoad: (record) => setState(() {
              if (record.isSeungdan) {
                _seungdanRecordToLoad = record;
                _seungdanLoadCounter++;
                _tabIndex = 3;
              } else {
                _recordToLoad = record;
                _loadCounter++;
                _tabIndex = 0;
              }
            }),
          ),
          StatsTab(records: records),
          SeungdanTab(
            key: ValueKey('seungdan_$_seungdanLoadCounter'),
            onSave: _addOrUpdateRecord,
            loadRecord: _seungdanRecordToLoad,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: const Color(0xFF1D9E75),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: '입력'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.list),
                if (records.isNotEmpty)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Color(0xFF1D9E75), shape: BoxShape.circle),
                      child: Text('${records.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
              ],
            ),
            label: '저장기록',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '통계'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: '승단'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 전체화면 영상 재생 (자동 재생 → 자동 복귀)
// 몰기/불, 승단 합격/탈락 공용
// ══════════════════════════════════════════
class FullScreenVideoScreen extends StatefulWidget {
  final String assetPath;
  const FullScreenVideoScreen({super.key, required this.assetPath});

  @override
  State<FullScreenVideoScreen> createState() => _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen> {
  VideoPlayerController? _vc;
  bool _ready = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _vc = VideoPlayerController.asset(widget.assetPath);
    try {
      await _vc!.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      _vc!.addListener(_checkFinished);
      await _vc!.play();
      // 안전장치: 영상 길이 + 0.5초 후에는 무조건 복귀
      final dur = _vc!.value.duration;
      if (dur > Duration.zero) {
        Future.delayed(dur + const Duration(milliseconds: 500), _safePop);
      } else {
        Future.delayed(const Duration(seconds: 5), _safePop);
      }
    } catch (_) {
      // 영상 로드 실패 시에도 앱이 멈추지 않도록 자동 복귀
      Future.delayed(const Duration(milliseconds: 1200), _safePop);
    }
  }

  void _checkFinished() {
    if (_popped || _vc == null) return;
    final v = _vc!.value;
    if (v.isInitialized && v.duration > Duration.zero &&
        v.position >= v.duration) {
      _safePop();
    }
  }

  void _safePop() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _vc?.removeListener(_checkFinished);
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _ready && _vc != null
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _vc!.value.size.width,
                      height: _vc!.value.size.height,
                      child: VideoPlayer(_vc!),
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: _safePop,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 입력 탭
// ══════════════════════════════════════════
class InputTab extends StatefulWidget {
  final Function(SijiRecord) onSave;
  final SijiRecord? loadRecord;
  const InputTab({super.key, required this.onSave, this.loadRecord});

  @override
  State<InputTab> createState() => _InputTabState();
}

class _InputTabState extends State<InputTab> {
  DateTime _selectedDate = DateTime.now();
  int _round = 1;
  List<List<int>> _st = List.generate(9, (_) => List.filled(5, 0));
  final _diaryController = TextEditingController();
  bool _videoBusy = false;

  static const sunNames = ['一巡','二巡','三巡','四巡','五巡','六巡','七巡','八巡','九巡'];

  @override
  void initState() {
    super.initState();
    if (widget.loadRecord != null) {
      final r = widget.loadRecord!;
      _selectedDate = DateTime.tryParse(r.date) ?? DateTime.now();
      _round = int.tryParse(r.round) ?? 1;
      _st = r.st.map((row) => List<int>.from(row)).toList();
      _diaryController.text = r.diary;
    }
  }

  int _rowScore(int r) => _st[r].where((v) => v == 1).length;
  bool _rowHasAny(int r) => _st[r].any((v) => v != 0);
  int _cumTotal(int r) { int t=0; for(int i=0;i<=r;i++) t+=_rowScore(i); return t; }
  int _grandTotal() { int t=0; for(int i=0;i<9;i++) t+=_rowScore(i); return t; }
  bool _anyFilled() => _st.any((row) => row.any((v) => v != 0));
  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  void _resetInput() {
    setState(() {
      _selectedDate = DateTime.now(); _round = 1;
      _st = List.generate(9, (_) => List.filled(5, 0));
      _diaryController.clear();
    });
  }

  void _saveRecord() {
    final dateStr = _formatDate(_selectedDate);
    final key = '${dateStr}_$_round';
    widget.onSave(SijiRecord(
      key: key, date: dateStr, round: _round.toString(),
      st: _st.map((row) => List<int>.from(row)).toList(),
      diary: _diaryController.text, total: _grandTotal(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다'), backgroundColor: Color(0xFF1D9E75)),
    );
  }

  // 한 순(5발)이 전부 관중/전부 불발이면 축하/위로 영상 재생
  void _checkRowCelebration(int r) {
    if (_videoBusy) return;
    final row = _st[r];
    String? asset;
    if (row.every((v) => v == 1)) {
      asset = 'assets/videos/molki.mp4';
    } else if (row.every((v) => v == 2)) {
      asset = 'assets/videos/fire.mp4';
    }
    if (asset != null) {
      _videoBusy = true;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FullScreenVideoScreen(assetPath: asset!)),
      ).then((_) {
        _videoBusy = false;
      });
    }
  }

  // 각 순의 5번째 칸: 평소엔 다른 칸과 똑같이 보이다가,
  // 터치하면 관중/불발을 고르는 작은 팝업이 뜨고, 선택하면 팝업이 닫히며
  // 그 결과가 칸에 표시된 다음 몰기/전불 이벤트가 실행됨
  Future<void> _pickLastShot(int r) async {
    final result = await showDialog<int>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('마지막 발 결과 선택',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 1),
                    child: Container(
                      width: 74, height: 74,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomPaint(size: const Size(26,26), painter: HitPainter()),
                          const SizedBox(height: 4),
                          const Text('관중', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 2),
                    child: Container(
                      width: 74, height: 74,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomPaint(size: const Size(26,26), painter: MissPainter()),
                          const SizedBox(height: 4),
                          const Text('불발', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_st[r][4] != 0) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 0),
                  child: const Text('선택 취소(초기화)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() => _st[r][4] = result);
      playArrowSound();
      _checkRowCelebration(r);
    }
  }

  Widget _buildLastCell(int r) {
    final v = _st[r][4];
    return GestureDetector(
      onTap: () => _pickLastShot(r),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: r % 2 == 0 ? Colors.white : const Color(0xFFF7FDFB),
          border: Border.all(color: const Color(0xFF999999), width: 0.5),
        ),
        child: Center(
          child: v == 1 ? CustomPaint(size: const Size(28,28), painter: HitPainter())
               : v == 2 ? CustomPaint(size: const Size(28,28), painter: MissPainter())
               : const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildCell(int r, int c) {
    final v = _st[r][c];
    return GestureDetector(
      onTap: () {
        setState(() => _st[r][c] = (_st[r][c] + 1) % 3);
        playArrowSound();
        _checkRowCelebration(r);
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: r % 2 == 0 ? Colors.white : const Color(0xFFF7FDFB),
          border: Border.all(color: const Color(0xFF999999), width: 0.5),
        ),
        child: Center(
          child: v == 1 ? CustomPaint(size: const Size(28,28), painter: HitPainter())
               : v == 2 ? CustomPaint(size: const Size(28,28), painter: MissPainter())
               : const SizedBox(),
        ),

      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF5C842),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Center(child: Text('국궁 시지',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF4A3800)))),
            ),
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(              children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(context: context,
                            initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white,
                            border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(_formatDate(_selectedDate), style: const TextStyle(fontSize: 14)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _round,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true, fillColor: Colors.white,
                      ),
                      items: List.generate(10, (i) => DropdownMenuItem(value: i+1, child: Text('제 ${i+1}회'))),
                      onChanged: (v) => setState(() => _round = v!),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(child: ElevatedButton(
                    onPressed: _saveRecord,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5DCAA5), foregroundColor: const Color(0xFF04342C)),
                    child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: _resetInput, child: const Text('새 기록'))),
                ],
              ),
            ),
            Row(children: [
              _headerCell('순', width: 44), _headerCell('1시'), _headerCell('2시'),
              _headerCell('3시'), _headerCell('4시'), _headerCell('5시'),
              _headerCell('순시', width: 40), _headerCell('합시', width: 40),
            ]),
            for (int r = 0; r < 9; r++)
              Row(children: [
                _sunCell(sunNames[r]),
                for (int c = 0; c < 4; c++) Expanded(child: _buildCell(r, c)),
                Expanded(child: _buildLastCell(r)),
                _scoreCell(_rowHasAny(r) ? '${_rowScore(r)}' : ''),
                _totalCell(_rowHasAny(r) ? '${_cumTotal(r)}' : ''),
              ]),
            Container(
              color: const Color(0xFF5DCAA5),
              child: Row(children: [
                Expanded(child: Container(
                  height: 38, alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  child: const Text('총 합계',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C))),
                )),
                SizedBox(width: 80, height: 38, child: Center(
                  child: Text(_anyFilled() ? '${_grandTotal()}시' : '',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF04342C))),
                )),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('습사일기', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _diaryController, maxLines: 4,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: '오늘의 습사 기록을 자유롭게 남겨보세요...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true, fillColor: const Color(0xFFF9F9F9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => FocusScope.of(context).unfocus(),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('완료'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5DCAA5),
                        foregroundColor: const Color(0xFF04342C),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('셀 클릭: 첫 클릭 관중, 두 번째 불발, 세 번째 초기화',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {double? width}) {
    final cell = Container(height: 36, color: const Color(0xFF5DCAA5),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C), fontSize: 13))));
    return width != null ? SizedBox(width: width, child: cell) : Expanded(child: cell);
  }
  Widget _sunCell(String text) => SizedBox(width: 44, height: 48,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFA8E6CE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5)),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF085041), fontSize: 12)))));
  Widget _scoreCell(String text) => SizedBox(width: 40, height: 48,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFE1F5EE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5)),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F6E56), fontSize: 14)))));
  Widget _totalCell(String text) => SizedBox(width: 40, height: 48,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFC8EDDE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5)),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F6E56), fontSize: 14)))));
}

class HitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCC2200)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(size.center(Offset.zero), size.width/2-1, paint);
    final tp = TextPainter(
      text: const TextSpan(text: '中',
          style: TextStyle(color: Color(0xFFCC2200), fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset((size.width-tp.width)/2, (size.height-tp.height)/2));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MissPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF222222)..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width*0.75, size.height*0.15), Offset(size.width*0.25, size.height*0.85), paint);
    paint.strokeWidth = 1.8;
    canvas.drawLine(Offset(size.width*0.34, size.height*0.41), Offset(size.width*0.66, size.height*0.59), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════
// 저장기록 탭
// ══════════════════════════════════════════
class RecordsTab extends StatefulWidget {
  final List<SijiRecord> records;
  final Function(String) onDelete;
  final Function(SijiRecord) onLoad;
  const RecordsTab({super.key, required this.records, required this.onDelete, required this.onLoad});

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  DateTime? _fromDate, _toDate;
  String? _deleteKey;

  List<SijiRecord> get _filtered {
    return widget.records.where((r) {
      final d = DateTime.parse(r.date);
      if (_fromDate != null && d.isBefore(_fromDate!)) return false;
      if (_toDate != null && d.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList()..sort((a, b) {
      final dc = b.date.compareTo(a.date);
      return dc != 0 ? dc : b.round.compareTo(a.round);
    });
  }

  static const sunNames = ['一巡','二巡','三巡','四巡','五巡','六巡','七巡','八巡','九巡'];

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // ⚠️ 삭제 다이얼로그는 반드시 Stack 내부의 Positioned로 배치해야 함.
    // (Column 자식으로 Positioned를 넣으면 화면이 멈추는 버그가 발생했었음 — 수정 완료)
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                color: const Color(0xFFF5C842), padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Center(child: Text('저장된 기록',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF4A3800)))),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: _dateButton(_fromDate, '시작일', (d) => setState(() => _fromDate = d))),
                  const SizedBox(width: 6),
                  Expanded(child: _dateButton(_toDate, '종료일', (d) => setState(() => _toDate = d))),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: () => setState(() { _fromDate = null; _toDate = null; }),
                    child: const Text('전체'),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '총 ${widget.records.length}건 저장됨${filtered.length != widget.records.length ? ' · 검색결과 ${filtered.length}건' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('저장된 기록이 없습니다', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildCard(filtered[i]),
                      ),
              ),
            ],
          ),
          if (_deleteKey != null) _buildDeleteDialog(),
        ],
      ),
    );
  }

  Widget _dateButton(DateTime? date, String hint, Function(DateTime) onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(context: context,
            initialDate: date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8)),
        child: Text(
          date != null
              ? '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}'
              : hint,
          style: TextStyle(fontSize: 12, color: date != null ? Colors.black : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCard(SijiRecord rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rec.isSeungdan ? rec.date : '${rec.date}  제${rec.round}회',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                ),
              ),
            ),
            if (rec.isSeungdan) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5C842),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('승단',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A3800))),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${rec.total}시', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF0F6E56))),
            const SizedBox(width: 4),
            TextButton(onPressed: () { widget.onLoad(rec); },
                child: const Text('불러오기', style: TextStyle(color: Color(0xFF0F6E56), fontSize: 12))),
            IconButton(
              onPressed: () => setState(() => _deleteKey = rec.key),
              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFE24B4A)),
              tooltip: '삭제',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: _buildMiniTable(rec)),
          if (rec.diary.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(12,0,12,12),
                child: Text(rec.diary, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildMiniTable(SijiRecord rec) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: FixedColumnWidth(32), 6: FixedColumnWidth(28), 7: FixedColumnWidth(28)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF5DCAA5)),
          children: ['순','1','2','3','4','5','순시','합시'].map((t) => TableCell(
            child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF04342C)))))
          )).toList(),
        ),
        for (int r = 0; r < 9; r++)
          TableRow(children: [
            TableCell(child: Container(color: const Color(0xFFA8E6CE),
                child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(sunNames[r], style: const TextStyle(fontSize: 10, color: Color(0xFF085041))))))),
            for (int c = 0; c < 5; c++)
              TableCell(child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                  child: rec.st[r][c] == 1
                      ? CustomPaint(size: const Size(16,16), painter: HitPainter())
                      : rec.st[r][c] == 2
                          ? CustomPaint(size: const Size(16,16), painter: MissPainter())
                          : const SizedBox(height: 16)))),
            TableCell(child: Container(color: const Color(0xFFE1F5EE),
                child: Center(child: Text(rec.st[r].any((v)=>v!=0) ? '${rec.st[r].where((v)=>v==1).length}' : '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F6E56), fontWeight: FontWeight.w600))))),
            TableCell(child: Container(color: const Color(0xFFC8EDDE),
                child: Center(child: Text(rec.st[r].any((v)=>v!=0)
                    ? '${rec.st.sublist(0,r+1).fold(0,(sum,row)=>sum+row.where((v)=>v==1).length)}' : '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F6E56), fontWeight: FontWeight.w600))))),
          ]),
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF5DCAA5)),
          children: [
            ...List.generate(6, (_) => const TableCell(child: SizedBox(height: 28))),
            TableCell(child: Center(child: Text('${rec.total}시',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF04342C))))),
            const TableCell(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildDeleteDialog() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _deleteKey = null),
        child: Container(
          color: Colors.black45,
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(40),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('이 기록을 삭제할까요?', style: TextStyle(fontSize: 15)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                          onPressed: () => setState(() => _deleteKey = null), child: const Text('취소'))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton(
                        onPressed: () { widget.onDelete(_deleteKey!); setState(() => _deleteKey = null); },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
                        child: const Text('삭제', style: TextStyle(color: Colors.white)),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ══════════════════════════════════════════
// 통계 탭
// ══════════════════════════════════════════
// 통계 차트용 단순 데이터 구조 (Map 키 충돌로 인한 데이터 유실 방지)
class _ChartBar {
  final String label;
  final double value;
  _ChartBar({required this.label, required this.value});
}

class StatsTab extends StatefulWidget {
  final List<SijiRecord> records;
  const StatsTab({super.key, required this.records});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  // 'avg' = 월별 평균, 'daily_avg' = 일별 평균, 'daily' = 일별 합시(선택한 하루)
  String _type = 'avg';
  DateTime _selectedDailyDate = DateTime.now();

  List<SijiRecord> get _filtered =>
      widget.records.where((r) => int.parse(r.date.split('-')[0]) == _year).toList();

  String _fmtDailyDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  // 한 순(5시)당 평균 적중 수 = 해당 기간 총 시수 합 ÷ (9 × 기록 건수)
  // 기록 하나는 항상 9순 기준판이므로, 이렇게 계산하면 "평소 한 순에 몇 중 하는지"가 바로 나옴
  double _avgPerSun(List<SijiRecord> recs) {
    if (recs.isEmpty) return 0.0;
    final sum = recs.fold(0, (s, r) => s + r.total);
    return sum / (9 * recs.length);
  }

  String _fmtAvg(double v) {
    final rounded = (v * 10).round() / 10;
    final isWhole = rounded == rounded.roundToDouble();
    return '평${isWhole ? rounded.toInt() : rounded.toStringAsFixed(1)}중';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF5C842), padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Center(child: Text('성적 통계',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF4A3800)))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12,12,12,0),
              child: Row(
                children: [
                  if (_type != 'daily')
                    DropdownButton<int>(
                      value: _year,
                      items: List.generate(6, (i) => DateTime.now().year - i)
                          .map((y) => DropdownMenuItem(value: y, child: Text('${y}년'))).toList(),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                  if (_type != 'daily') const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'avg', child: Text('월별 평균')),
                      DropdownMenuItem(value: 'daily_avg', child: Text('일별 평균')),
                      DropdownMenuItem(value: 'daily', child: Text('일별 합시')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  if (_type == 'daily_avg') ...[
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _month,
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(value: m, child: Text('${m}월'))).toList(),
                      onChanged: (v) => setState(() => _month = v!),
                    ),
                  ],
                  if (_type == 'daily') ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(context: context,
                            initialDate: _selectedDailyDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) setState(() => _selectedDailyDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white,
                            border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(_fmtDailyDate(_selectedDailyDate), style: const TextStyle(fontSize: 14)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_type == 'daily')
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildDailySingleDayView(),
              )
            else if (filtered.isEmpty)
              const Padding(padding: EdgeInsets.all(40),
                  child: Text('저장된 기록이 없습니다\n먼저 시지를 입력하고 저장해보세요!',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  _statCard('최고', '${filtered.map((r)=>r.total).reduce((a,b)=>a>b?a:b)}시'),
                  _statCard('평균', '${(filtered.fold(0,(s,r)=>s+r.total)/filtered.length).toStringAsFixed(1)}시'),
                  _statCard('최저', '${filtered.map((r)=>r.total).reduce((a,b)=>a<b?a:b)}시'),
                  _statCard('횟수', '${filtered.length}회'),
                ]),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _type == 'avg' ? _buildMonthlyAvgChart(filtered) : _buildDailyAvgChart(filtered),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) => Expanded(
        child: Card(
          color: const Color(0xFFF0FDF8),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F6E56))),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
        ),
      );

  // 월별 평균 (12개월, 스크롤 없이 화면 폭에 맞춰 표시)
  Widget _buildMonthlyAvgChart(List<SijiRecord> filtered) {
    final bars = List.generate(12, (i) {
      final m = i + 1;
      final recs = filtered.where((r) => int.parse(r.date.split('-')[1]) == m).toList();
      return _ChartBar(label: '${m}월', value: _avgPerSun(recs));
    });
    return _avgBarChart('${_year}년 월별 평균 (한 순당 평균 적중)', bars, scrollable: false);
  }

  // 일별 평균 (선택한 월의 날짜 전체, 가로 스크롤)
  Widget _buildDailyAvgChart(List<SijiRecord> filtered) {
    final monthRecs = filtered.where((r) => int.parse(r.date.split('-')[1]) == _month).toList();
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final bars = List.generate(daysInMonth, (i) {
      final d = i + 1;
      final recs = monthRecs.where((r) => int.parse(r.date.split('-')[2]) == d).toList();
      return _ChartBar(label: '${d}일', value: _avgPerSun(recs));
    });
    return _avgBarChart('${_year}년 ${_month}월 일별 평균 (한 순당 평균 적중)', bars, scrollable: true);
  }

  // 평균(순당 적중) 계열 공통 차트 위젯 - 값 범위 0~5중 기준
  Widget _avgBarChart(String title, List<_ChartBar> entries, {required bool scrollable}) {
    Widget bar(_ChartBar e) {
      final height = e.value <= 0 ? 0.0 : (e.value / 5.0).clamp(0.0, 1.0) * 155;
      final content = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 14,
            child: e.value > 0
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_fmtAvg(e.value),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F6E56))),
                  )
                : null,
          ),
          const SizedBox(height: 2),
          Container(
            height: height, margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF5DCAA5).withValues(alpha: 0.8),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3), topRight: Radius.circular(3)),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(e.label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          ),
        ],
      );
      return scrollable ? SizedBox(width: 46, child: content) : Expanded(child: content);
    }

    final row = Row(crossAxisAlignment: CrossAxisAlignment.end, children: entries.map(bar).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: scrollable ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row) : row,
        ),
      ],
    );
  }

  // 일별 합시: 선택한 하루(기본값 오늘)의 기록만 보여줌.
  // 그날 기록이 여러 건(일반+승단 등)이면 전부 합산.
  // "총 소진"은 맞은 것/빗나간 것 다 포함한 화살 수(발수) 기준이며, 5발 단위(한 순)로 묶어서
  // "N순 M발" 형태로 표시함 — 예: 53발이면 10순 3발.
  Widget _buildDailySingleDayView() {
    final dateStr = _fmtDailyDate(_selectedDailyDate);
    final dayRecords = widget.records.where((r) => r.date == dateStr).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (dayRecords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text('이 날짜엔 저장된 기록이 없습니다',
            style: TextStyle(color: Colors.grey))),
      );
    }

    int totalShots = 0;
    int totalHits = 0;
    for (final r in dayRecords) {
      totalShots += r.st.expand((row) => row).where((v) => v != 0).length;
      totalHits += r.total;
    }
    final fullSuns = totalShots ~/ 5;
    final remainder = totalShots % 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in dayRecords)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.isSeungdan ? '승단 기록' : '제${r.round}회',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${r.total}시',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F6E56))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF5DCAA5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 소진 $totalShots발  ·  적중 $totalHits시',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C), fontSize: 12)),
              const SizedBox(height: 3),
              Text('총 $fullSuns순 $remainder발',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C), fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
// 승단 심사 탭
// ══════════════════════════════════════════
class SeungdanTab extends StatefulWidget {
  final Function(SijiRecord)? onSave;
  final SijiRecord? loadRecord;
  const SeungdanTab({super.key, this.onSave, this.loadRecord});

  @override
  State<SeungdanTab> createState() => _SeungdanTabState();
}

class _SeungdanTabState extends State<SeungdanTab> {
  String _targetGrade = '초단';
  bool _isElderly = false;
  DateTime _selectedDate = DateTime.now();
  List<List<int>> _st = List.generate(9, (_) => List.filled(5, 0));

  static const Map<String,int> _gradeTargets = {
    '1급':22,'초단':24,'2단':26,'3단':28,'4단':30,'5단':31,'6단':33,'7단':35,'8단':37,'9단':39,
  };
  static const Map<String,int> _elderlyTargets = {'1급':16,'초단':18};
  static const List<String> _gradeList = ['1급','초단','2단','3단','4단','5단','6단','7단','8단','9단'];
  static const List<String> _sunNames = ['一巡','二巡','三巡','四巡','五巡','六巡','七巡','八巡','九巡'];

  @override
  void initState() {
    super.initState();
    if (widget.loadRecord != null) {
      final r = widget.loadRecord!;
      _selectedDate = DateTime.tryParse(r.date) ?? DateTime.now();
      _targetGrade = r.targetGrade ?? '초단';
      _isElderly = r.isElderly ?? false;
      _st = r.st.map((row) => List<int>.from(row)).toList();
    } else {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _targetGrade = prefs.getString('seungdan_grade') ?? '초단';
      _isElderly = prefs.getBool('seungdan_elderly') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seungdan_grade', _targetGrade);
    await prefs.setBool('seungdan_elderly', _isElderly);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  void _saveRecord() {
    final dateStr = _formatDate(_selectedDate);
    final key = 'seungdan_${dateStr}_${DateTime.now().millisecondsSinceEpoch}';
    widget.onSave?.call(SijiRecord(
      key: key,
      date: dateStr,
      round: '',
      st: _st.map((row) => List<int>.from(row)).toList(),
      diary: '',
      total: _currentHits,
      isSeungdan: true,
      targetGrade: _targetGrade,
      isElderly: _isElderly,
      passed: _currentHits >= _targetHits,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('승단 기록이 저장되었습니다'), backgroundColor: Color(0xFF1D9E75)),
      );
    }
  }

  int get _targetHits {
    if (_isElderly && _elderlyTargets.containsKey(_targetGrade)) return _elderlyTargets[_targetGrade]!;
    return _gradeTargets[_targetGrade] ?? 24;
  }

  int get _currentHits => _st.fold(0,(s,row)=>s+row.where((v)=>v==1).length);
  int get _totalInputted => _st.fold(0,(s,row)=>s+row.where((v)=>v!=0).length);
  int get _remainingArrows => 45 - _totalInputted;
  int get _neededMore => _targetHits - _currentHits;
  // 탈락까지 추가로 허용되는 불발 횟수 (남은 발수 중 빗나가도 되는 한계)
  int get _allowedMisses {
    final v = _remainingArrows - _neededMore;
    return v < 0 ? 0 : v;
  }

  int _rowScore(int r) => _st[r].where((v)=>v==1).length;
  bool _rowHasAny(int r) => _st[r].any((v)=>v!=0);
  int _cumTotal(int r) { int t=0; for(int i=0;i<=r;i++) t+=_rowScore(i); return t; }

  void _onCellTap(int r, int c) {
    setState(() => _st[r][c] = (_st[r][c]+1)%3);
    playArrowSound();
    final hits = _st.fold(0,(s,row)=>s+row.where((v)=>v==1).length);
    final inputted = _st.fold(0,(s,row)=>s+row.where((v)=>v!=0).length);
    final remaining = 45 - inputted;
    final needed = _targetHits - hits;
    if (hits >= _targetHits) {
      _triggerResult(true);
    } else if (needed > remaining) {
      _triggerResult(false);
    }
  }

  void _triggerResult(bool passed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoScreen(
          assetPath: passed ? 'assets/videos/congrats.mp4' : 'assets/videos/sugo.mp4',
        ),
      ),
    );
    // 영상이 끝나고 돌아와도 시수판은 그대로 유지됩니다.
    // (이전엔 자동 초기화되어 결과를 저장할 수 없었음 - 이제 '저장' 버튼으로 직접 저장하거나
    //  '초기화' 버튼을 눌러야만 지워집니다.)
  }

  void _reset() => setState(() => _st = List.generate(9, (_) => List.filled(5, 0)));

  @override
  Widget build(BuildContext context) {
    final isFailing = _neededMore > 0 && _neededMore > _remainingArrows;
    final isPassing = _currentHits >= _targetHits;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF5C842), padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Center(child: Text('승단 심사',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF4A3800)))),
            ),
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(context: context,
                          initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white,
                          border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(_formatDate(_selectedDate), style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('목표: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  DropdownButton<String>(
                    value: _targetGrade, underline: const SizedBox(), isDense: true,
                    items: _gradeList.map((g) => DropdownMenuItem(value: g,
                        child: Text(g, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)))).toList(),
                    onChanged: (v) { setState(() => _targetGrade = v!); _saveSettings(); },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_targetHits}중 필요',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  const Text('70세 이상', style: TextStyle(fontSize: 12)),
                  Transform.scale(
                    scale: 0.85,
                    child: Checkbox(
                      value: _isElderly,
                      onChanged: (v) { setState(() => _isElderly = v!); _saveSettings(); },
                      activeColor: const Color(0xFF1D9E75),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12,8,12,4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFailing ? Colors.red.shade300 : isPassing ? const Color(0xFF1D9E75) : Colors.grey.shade300,
                  width: isFailing || isPassing ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusItem('${_currentHits}중', '현재 중수', const Color(0xFF0F6E56)),
                      Container(width: 1, height: 32, color: Colors.grey.shade300),
                      _statusItem('${_remainingArrows}발', '남은 발수', Colors.grey.shade700),
                      Container(width: 1, height: 32, color: Colors.grey.shade300),
                      _statusItem(
                        isFailing ? '0발' : '${_allowedMisses}발',
                        '허용 불발',
                        isFailing
                            ? Colors.red
                            : _allowedMisses <= 2
                                ? Colors.red.shade400
                                : _allowedMisses <= 5
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Text(
                    isFailing ? '탈락 확정' : _neededMore <= 0 ? '목표 달성!' : '${_neededMore}중 더 필요',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isFailing ? Colors.red : _neededMore <= 0 ? const Color(0xFF1D9E75) : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12,4,12,4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveRecord,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5DCAA5), foregroundColor: const Color(0xFF04342C),
                          minimumSize: const Size(double.infinity, 36)),
                      child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
                      child: const Text('초기화'),
                    ),
                  ),
                ],
              ),
            ),
            Row(children: [
              _headerCell('순', width: 44), _headerCell('1시'), _headerCell('2시'),
              _headerCell('3시'), _headerCell('4시'), _headerCell('5시'),
              _headerCell('순시', width: 40), _headerCell('합시', width: 40),
            ]),
            for (int r = 0; r < 9; r++)
              Row(children: [
                _sunCell(_sunNames[r]),
                for (int c = 0; c < 5; c++) Expanded(child: _buildCell(r, c)),
                _scoreCell(_rowHasAny(r) ? '${_rowScore(r)}' : ''),
                _totalCell(_rowHasAny(r) ? '${_cumTotal(r)}' : ''),
              ]),
            Container(
              color: const Color(0xFF5DCAA5),
              child: Row(children: [
                Expanded(child: Container(
                  height: 38, alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('목표: ${_targetHits}중  /  현재: ${_currentHits}중',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C), fontSize: 13)),
                )),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statusItem(String value, String label, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ],
  );

  Widget _buildCell(int r, int c) {
    final v = _st[r][c];
    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: r%2==0 ? Colors.white : const Color(0xFFF7FDFB),
          border: Border.all(color: const Color(0xFF999999), width: 0.5),
        ),
        child: Center(
          child: v==1 ? CustomPaint(size: const Size(28,28), painter: HitPainter())
               : v==2 ? CustomPaint(size: const Size(28,28), painter: MissPainter())
               : const SizedBox(),
        ),
      ),
    );
  }

  Widget _headerCell(String text, {double? width}) {
    final cell = Container(height: 36, color: const Color(0xFF5DCAA5),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C), fontSize: 13))));
    return width != null ? SizedBox(width: width, child: cell) : Expanded(child: cell);
  }
  Widget _sunCell(String text) => SizedBox(width: 44, height: 48,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFA8E6CE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5)),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF085041), fontSize: 12)))));
  Widget _scoreCell(String text) => SizedBox(width: 40, height: 48,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFE1F5EE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5)),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F6E56), fontSize: 14)))));
  Widget _totalCell(String text) => SizedBox(width: 40, height: 48,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFC8EDDE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5)),
        child: Center(child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F6E56), fontSize: 14)))));
}
