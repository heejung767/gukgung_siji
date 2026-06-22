import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// 데이터 모델
class SijiRecord {
  final String key;
  final String date;
  final String round;
  final List<List<int>> st;
  final String diary;
  final int total;

  SijiRecord({
    required this.key,
    required this.date,
    required this.round,
    required this.st,
    required this.diary,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'date': date,
        'round': round,
        'st': st,
        'diary': diary,
        'total': total,
      };

  factory SijiRecord.fromJson(Map<String, dynamic> json) => SijiRecord(
        key: json['key'],
        date: json['date'],
        round: json['round'],
        st: (json['st'] as List)
            .map((row) => (row as List).map((v) => v as int).toList())
            .toList(),
        diary: json['diary'] ?? '',
        total: json['total'],
      );
}

// 메인 화면
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;
  List<SijiRecord> records = [];
  SijiRecord? _loadedRecord; // 불러오기로 전달할 레코드

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
    await prefs.setString('records', jsonEncode(records.map((e) => e.toJson()).toList()));
  }

  void _addOrUpdateRecord(SijiRecord record) {
    setState(() {
      final idx = records.indexWhere((r) => r.key == record.key);
      if (idx >= 0) {
        records[idx] = record;
      } else {
        records.add(record);
      }
    });
    _saveRecords();
  }

  void _deleteRecord(String key) {
    setState(() {
      records.removeWhere((r) => r.key == key);
    });
    _saveRecords();
  }

  // 불러오기: 레코드 전달 후 입력 탭으로 이동
  void _loadRecord(SijiRecord record) {
    setState(() {
      _loadedRecord = record;
      _tabIndex = 0;
    });
  }

  void _clearLoadedRecord() {
    setState(() {
      _loadedRecord = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          InputTab(
            onSave: _addOrUpdateRecord,
            loadedRecord: _loadedRecord,
            onLoadConsumed: _clearLoadedRecord,
          ),
          RecordsTab(
            records: records,
            onDelete: _deleteRecord,
            onLoad: _loadRecord,
          ),
          StatsTab(records: records),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: const Color(0xFF1D9E75),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.edit), label: '입력'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.list),
                if (records.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1D9E75),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${records.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
            label: '저장기록',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '통계'),
        ],
      ),
    );
  }
}

// 입력 탭
class InputTab extends StatefulWidget {
  final Function(SijiRecord) onSave;
  final SijiRecord? loadedRecord;
  final VoidCallback onLoadConsumed;

  const InputTab({
    super.key,
    required this.onSave,
    this.loadedRecord,
    required this.onLoadConsumed,
  });

  @override
  State<InputTab> createState() => _InputTabState();
}

class _InputTabState extends State<InputTab> {
  DateTime _selectedDate = DateTime.now();
  int _round = 1;
  List<List<int>> _st = List.generate(9, (_) => List.filled(5, 0));
  final _diaryController = TextEditingController();

  static const sunNames = ['一巡', '二巡', '三巡', '四巡', '五巡', '六巡', '七巡', '八巡', '九巡'];

  @override
  void didUpdateWidget(InputTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 불러오기 레코드가 새로 들어오면 폼에 채움
    if (widget.loadedRecord != null && widget.loadedRecord != oldWidget.loadedRecord) {
      _fillFromRecord(widget.loadedRecord!);
      widget.onLoadConsumed();
    }
  }

  void _fillFromRecord(SijiRecord record) {
    setState(() {
      _selectedDate = DateTime.parse(record.date);
      _round = int.tryParse(record.round) ?? 1;
      _st = record.st.map((row) => List<int>.from(row)).toList();
      _diaryController.text = record.diary;
    });
  }

  int _rowScore(int r) => _st[r].where((v) => v == 1).length;
  bool _rowHasAny(int r) => _st[r].any((v) => v != 0);
  int _cumTotal(int r) {
    int t = 0;
    for (int i = 0; i <= r; i++) {
      t += _rowScore(i);
    }
    return t;
  }
  int _grandTotal() {
    int t = 0;
    for (int i = 0; i < 9; i++) {
      t += _rowScore(i);
    }
    return t;
  }
  bool _anyFilled() => _st.any((row) => row.any((v) => v != 0));

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _resetInput() {
    setState(() {
      _selectedDate = DateTime.now();
      _round = 1;
      _st = List.generate(9, (_) => List.filled(5, 0));
      _diaryController.clear();
    });
  }

  void _saveRecord() {
    final dateStr = _formatDate(_selectedDate);
    final key = '${dateStr}_$_round';
    final record = SijiRecord(
      key: key,
      date: dateStr,
      round: _round.toString(),
      st: _st.map((row) => List<int>.from(row)).toList(),
      diary: _diaryController.text,
      total: _grandTotal(),
    );
    widget.onSave(record);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다'), backgroundColor: Color(0xFF1D9E75)),
    );
  }

  Widget _buildCell(int r, int c) {
    final v = _st[r][c];
    return GestureDetector(
      onTap: () {
        setState(() {
          _st[r][c] = (_st[r][c] + 1) % 3;
        });
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: r % 2 == 0 ? Colors.white : const Color(0xFFF7FDFB),
          border: Border.all(color: const Color(0xFF999999), width: 0.5),
        ),
        child: Center(
          child: v == 1
              ? CustomPaint(size: const Size(28, 28), painter: HitPainter())
              : v == 2
                  ? CustomPaint(size: const Size(28, 28), painter: MissPainter())
                  : const SizedBox(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF5C842),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Center(
              child: Text('국궁 시지',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF4A3800))),
            ),
          ),
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(_formatDate(_selectedDate), style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _round,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('제 ${i + 1}회'))),
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
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveRecord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5DCAA5),
                      foregroundColor: const Color(0xFF04342C),
                    ),
                    child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetInput,
                    child: const Text('새 기록'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      _headerCell('순', width: 44),
                      _headerCell('1시'),
                      _headerCell('2시'),
                      _headerCell('3시'),
                      _headerCell('4시'),
                      _headerCell('5시'),
                      _headerCell('순시', width: 40),
                      _headerCell('합시', width: 40),
                    ],
                  ),
                  for (int r = 0; r < 9; r++)
                    Row(
                      children: [
                        _sunCell(sunNames[r]),
                        for (int c = 0; c < 5; c++) Expanded(child: _buildCell(r, c)),
                        _scoreCell(_rowHasAny(r) ? '${_rowScore(r)}' : ''),
                        _totalCell(_rowHasAny(r) ? '${_cumTotal(r)}' : ''),
                      ],
                    ),
                  Container(
                    color: const Color(0xFF5DCAA5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 12),
                            child: const Text('총 합계',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C))),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 38,
                          child: Center(
                            child: Text(
                              _anyFilled() ? '${_grandTotal()}시' : '',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF04342C)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('습사일기',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _diaryController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: '오늘의 습사 기록을 자유롭게 남겨보세요...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: const Color(0xFFF9F9F9),
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
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {double? width}) {
    final cell = Container(
      height: 36,
      color: const Color(0xFF5DCAA5),
      child: Center(
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF04342C), fontSize: 13)),
      ),
    );
    return width != null ? SizedBox(width: width, child: cell) : Expanded(child: cell);
  }

  Widget _sunCell(String text) => SizedBox(
        width: 44,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFA8E6CE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5),
          ),
          child: Center(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF085041), fontSize: 12)),
          ),
        ),
      );

  Widget _scoreCell(String text) => SizedBox(
        width: 40,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE1F5EE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5),
          ),
          child: Center(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF0F6E56), fontSize: 14)),
          ),
        ),
      );

  Widget _totalCell(String text) => SizedBox(
        width: 40,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFC8EDDE),
            border: Border.all(color: const Color(0xFF999999), width: 0.5),
          ),
          child: Center(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF0F6E56), fontSize: 14)),
          ),
        ),
      );
}

// 관중 그리기
class HitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCC2200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 1, paint);
    final tp = TextPainter(
      text: const TextSpan(
        text: '中',
        style: TextStyle(
          color: Color(0xFFCC2200),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 불발 그리기
class MissPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.15),
      Offset(size.width * 0.25, size.height * 0.85),
      paint,
    );
    paint.strokeWidth = 1.8;
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.41),
      Offset(size.width * 0.66, size.height * 0.59),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 저장기록 탭
class RecordsTab extends StatefulWidget {
  final List<SijiRecord> records;
  final Function(String) onDelete;
  final Function(SijiRecord) onLoad;

  const RecordsTab({
    super.key,
    required this.records,
    required this.onDelete,
    required this.onLoad,
  });

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _deleteKey;

  List<SijiRecord> get _filtered {
    return widget.records.where((r) {
      final d = DateTime.parse(r.date);
      if (_fromDate != null && d.isBefore(_fromDate!)) return false;
      if (_toDate != null && d.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.round.compareTo(a.round);
      });
  }

  static const sunNames = ['一巡', '二巡', '三巡', '四巡', '五巡', '六巡', '七巡', '八巡', '九巡'];

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF5C842),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Center(
              child: Text('저장된 기록',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF4A3800))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _dateButton(_fromDate, '시작일', (d) => setState(() => _fromDate = d))),
                const SizedBox(width: 6),
                Expanded(child: _dateButton(_toDate, '종료일', (d) => setState(() => _toDate = d))),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => setState(() { _fromDate = null; _toDate = null; }),
                  child: const Text('전체'),
                ),
              ],
            ),
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
          if (_deleteKey != null) _buildDeleteDialog(),
        ],
      ),
    );
  }

  Widget _dateButton(DateTime? date, String hint, Function(DateTime) onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          date != null
              ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
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
        title: Text('${rec.date}  제${rec.round}회',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${rec.total}시',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF0F6E56))),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => widget.onLoad(rec),
              child: const Text('불러오기', style: TextStyle(color: Color(0xFF0F6E56), fontSize: 12)),
            ),
            TextButton(
              onPressed: () => setState(() => _deleteKey = rec.key),
              child: const Text('삭제', style: TextStyle(color: Color(0xFFE24B4A), fontSize: 12)),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildMiniTable(rec),
          ),
          if (rec.diary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(rec.diary, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniTable(SijiRecord rec) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FixedColumnWidth(32),
        6: FixedColumnWidth(28),
        7: FixedColumnWidth(28),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF5DCAA5)),
          children: ['순', '1', '2', '3', '4', '5', '순시', '합시']
              .map((t) => TableCell(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF04342C))),
                      ),
                    ),
                  ))
              .toList(),
        ),
        for (int r = 0; r < 9; r++)
          TableRow(
            children: [
              TableCell(
                child: Container(
                  color: const Color(0xFFA8E6CE),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(sunNames[r],
                          style: const TextStyle(fontSize: 10, color: Color(0xFF085041))),
                    ),
                  ),
                ),
              ),
              for (int c = 0; c < 5; c++)
                TableCell(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: rec.st[r][c] == 1
                          ? CustomPaint(size: const Size(16, 16), painter: HitPainter())
                          : rec.st[r][c] == 2
                              ? CustomPaint(size: const Size(16, 16), painter: MissPainter())
                              : const SizedBox(height: 16),
                    ),
                  ),
                ),
              TableCell(
                child: Container(
                  color: const Color(0xFFE1F5EE),
                  child: Center(
                    child: Text(
                      rec.st[r].any((v) => v != 0)
                          ? '${rec.st[r].where((v) => v == 1).length}'
                          : '',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F6E56), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              TableCell(
                child: Container(
                  color: const Color(0xFFC8EDDE),
                  child: Center(
                    child: Text(
                      rec.st[r].any((v) => v != 0)
                          ? '${rec.st.sublist(0, r + 1).fold(0, (sum, row) => sum + row.where((v) => v == 1).length)}'
                          : '',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F6E56), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF5DCAA5)),
          children: [
            ...List.generate(6, (_) => const TableCell(child: SizedBox(height: 28))),
            TableCell(
              child: Center(
                child: Text(
                  '${rec.total}시',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF04342C)),
                ),
              ),
            ),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _deleteKey = null),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onDelete(_deleteKey!);
                              setState(() => _deleteKey = null);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
                            child: const Text('삭제', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
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

// 통계 탭
class StatsTab extends StatefulWidget {
  final List<SijiRecord> records;

  const StatsTab({super.key, required this.records});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  int _year = DateTime.now().year;
  String _type = 'monthly';

  List<SijiRecord> get _filtered =>
      widget.records.where((r) => int.parse(r.date.split('-')[0]) == _year).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF5C842),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Center(
                child: Text('성적 통계',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF4A3800))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  DropdownButton<int>(
                    value: _year,
                    items: List.generate(6, (i) => DateTime.now().year - i)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y년')))
                        .toList(),
                    onChanged: (v) => setState(() => _year = v!),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('월별 합시')),
                      DropdownMenuItem(value: 'avg', child: Text('월별 평균')),
                      DropdownMenuItem(value: 'daily', child: Text('일별 합시')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ],
              ),
            ),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('저장된 기록이 없습니다\n먼저 시지를 입력하고 저장해보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _statCard('최고', '${filtered.map((r) => r.total).reduce((a, b) => a > b ? a : b)}시'),
                    _statCard('평균',
                        '${(filtered.fold(0, (s, r) => s + r.total) / filtered.length).toStringAsFixed(1)}시'),
                    _statCard('최저', '${filtered.map((r) => r.total).reduce((a, b) => a < b ? a : b)}시'),
                    _statCard('횟수', '${filtered.length}회'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildBarChart(filtered),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F6E56))),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      );

  Widget _buildBarChart(List<SijiRecord> filtered) {
    Map<String, List<int>> data = {};

    if (_type == 'monthly' || _type == 'avg') {
      for (int m = 1; m <= 12; m++) {
        final key = '$m월';
        final vals = filtered.where((r) => int.parse(r.date.split('-')[1]) == m).map((r) => r.total).toList();
        data[key] = vals;
      }
    } else {
      final sorted = filtered.toList()..sort((a, b) => a.date.compareTo(b.date));
      for (final r in sorted) {
        final key = '${r.date.substring(5)} ${r.round}회';
        data[key] = [r.total];
      }
    }

    const maxVal = 45.0;
    final entries = data.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _type == 'monthly' ? '$_year년 월별 합시' : _type == 'avg' ? '$_year년 월별 평균' : '$_year년 일별 합시',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: entries.map((e) {
              final vals = e.value;
              final val = vals.isEmpty
                  ? 0.0
                  : _type == 'avg'
                      ? vals.fold(0, (s, v) => s + v) / vals.length
                      : vals.fold(0, (s, v) => s + v).toDouble();
              final height = val == 0 ? 0.0 : (val / maxVal) * 160;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (val > 0)
                      Text(val.toStringAsFixed(val == val.roundToDouble() ? 0 : 1),
                          style: const TextStyle(fontSize: 8, color: Color(0xFF0F6E56))),
                    const SizedBox(height: 2),
                    Container(
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(93, 202, 165, 0.8),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(e.key, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
