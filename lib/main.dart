import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Expense Log',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xfff7f8f6),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b5b)),
        ),
        home: const Home(),
      );
}

class Preset {
  Preset(
    this.name,
    this.amount,
    this.description, {
    this.kind = 'bus',
    this.useColorEmoji = false,
  });
  String name, description, kind;
  double amount;
  bool useColorEmoji;

  Map<String, dynamic> json() => {
        'n': name,
        'a': amount,
        'd': description,
        'k': kind,
        'c': useColorEmoji,
      };

  factory Preset.from(Map x) => Preset(
        x['n'],
        (x['a'] as num).toDouble(),
        x['d'] ?? x['n'],
        kind: x['k'] ?? 'bus',
        useColorEmoji: x['c'] ?? false,
      );
}

class Entry {
  Entry(this.name, this.description, this.amount, this.time);
  final String name, description;
  final double amount;
  final DateTime time;
  Map<String, dynamic> json() => {
        'n': name,
        'd': description,
        'a': amount,
        't': time.toIso8601String(),
      };
  factory Entry.from(Map x) => Entry(
        x['n'],
        x['d'] ?? x['n'],
        (x['a'] as num).toDouble(),
        DateTime.parse(x['t']),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _Home();
}

class _Home extends State<Home> {
  List<Preset> presets = [];
  List<Entry> entries = [];
  int tab = 0;
  final fmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static const List<String> emojiSuggestions = [
    '🪵', '🚌', '🚇', '🛺', '🚕', '🚗', '🚲', '☕', 
    '🍽️', '🛒', '💼', '⚡', '🏠', '🍿', '🎟️', '✈️', 
    '🏥', '💊', '⛽', '📦', '🍔'
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      presets = p.getString('presets') == null
          ? [
              Preset('Metro', 60, 'Metro (A to B)', kind: '🚇', useColorEmoji: false),
              Preset('Bus', 12, 'Bus (B to C)', kind: '🚌', useColorEmoji: false),
              Preset('Auto', 70, 'Auto (C to B)', kind: '🛺', useColorEmoji: false),
            ]
          : (jsonDecode(p.getString('presets')!) as List)
              .map((x) => Preset.from(x))
              .toList();
      entries = p.getString('entries') == null
          ? []
          : (jsonDecode(p.getString('entries')!) as List)
              .map((x) => Entry.from(x))
              .toList();
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'presets',
      jsonEncode(presets.map((x) => x.json()).toList()),
    );
    await p.setString(
      'entries',
      jsonEncode(entries.map((x) => x.json()).toList()),
    );
  }

  double total(DateTime d) =>
      entries.where((e) => e.time.isAfter(d)).fold(0, (s, e) => s + e.amount);

  void log(Preset p) {
    final newEntry = Entry(p.name, p.description, p.amount, DateTime.now());
    setState(() => entries.insert(0, newEntry));
    save();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.name} logged · ${fmt.format(p.amount)}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unlogEntry(newEntry, silent: true),
        ),
      ),
    );
  }

  void unlogEntry(Entry entry, {bool silent = false}) {
    final index = entries.indexOf(entry);
    if (index == -1) return;
    final removed = entries[index];
    setState(() => entries.removeAt(index));
    save();

    if (!silent) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${removed.name} unlogged'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() {
                final targetIndex = index.clamp(0, entries.length);
                entries.insert(targetIndex, removed);
              });
              save();
            },
          ),
        ),
      );
    }
  }

  Future<void> confirmAndDelete(Entry e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${e.description}" (${fmt.format(e.amount)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      unlogEntry(e);
    }
  }

  IconData getIconData(String kind) {
    switch (kind) {
      case 'log':
      case '🪵':
        return Icons.forest_outlined;
      case 'train':
      case '🚇':
        return Icons.train;
      case 'bus':
      case '🚌':
        return Icons.directions_bus;
      case 'auto':
      case '🛺':
        return Icons.electric_rickshaw;
      case 'taxi':
      case '🚕':
      case '🚗':
        return Icons.local_taxi;
      case 'bike':
      case '🚲':
        return Icons.directions_bike;
      case 'coffee':
      case '☕':
        return Icons.local_cafe;
      case 'food':
      case '🍽️':
      case '🍔':
        return Icons.restaurant;
      case 'cart':
      case '🛒':
        return Icons.shopping_cart;
      case 'work':
      case '💼':
        return Icons.work_outline;
      case 'power':
      case '⚡':
        return Icons.bolt;
      case 'home':
      case '🏠':
        return Icons.home_outlined;
      case 'movie':
      case '🍿':
      case '🎟️':
        return Icons.confirmation_number_outlined;
      case 'flight':
      case '✈️':
        return Icons.flight;
      case 'hospital':
      case '🏥':
      case '💊':
        return Icons.medical_services_outlined;
      case 'gas':
      case '⛽':
        return Icons.local_gas_station;
      case 'box':
      case '📦':
        return Icons.inventory_2_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Widget presetIcon(Preset p, {double size = 32}) {
    if (!p.useColorEmoji) {
      return Icon(
        getIconData(p.kind),
        size: size,
        color: const Color(0xff176b5b),
      );
    }
    return Text(
      p.kind,
      style: TextStyle(fontSize: size, height: 1.1),
    );
  }

  @override
  Widget build(BuildContext c) {
    final v = [quick(), history(), edit()];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tab == 0
              ? 'Expense Log 🪵'
              : tab == 1
                  ? 'History & Reports'
                  : 'Quick Buttons',
        ),
      ),
      body: SafeArea(child: v[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Text('🪵', style: TextStyle(fontSize: 20)),
            selectedIcon: Text('🪵', style: TextStyle(fontSize: 24)),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Edit',
          ),
        ],
      ),
    );
  }

  Widget quick() {
    final n = DateTime.now();
    final totalCount = presets.length + 1;
    final columns = totalCount <= 4 ? 2 : 3;
    final childAspectRatio = columns == 2
        ? (totalCount <= 2 ? 1.4 : 1.12)
        : 0.95;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(n),
          style: const TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Today: ${fmt.format(total(DateTime(n.year, n.month, n.day)))}',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        Row(
          children: const [
            Text('🪵', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'TAP BUTTON TO LOG',
              style: TextStyle(
                letterSpacing: 1.3,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xff176b5b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (c, i) => i == presets.length
              ? otherCard(compact: columns > 2)
              : presetCard(presets[i], compact: columns > 2),
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text(
            'RECENT LOGS',
            style: TextStyle(
              letterSpacing: 1.3,
              fontWeight: FontWeight.bold,
              color: Color(0xff176b5b),
            ),
          ),
          const SizedBox(height: 10),
          ...entries.take(4).map((e) => tile(e, allowDelete: false)),
        ],
      ],
    );
  }

  Widget presetCard(Preset p, {bool compact = false}) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        shadowColor: Colors.black.withAlpha(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => log(p),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(compact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xffe2f1ec),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: presetIcon(p, size: compact ? 26 : 34),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xff176b5b).withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'TAP TO LOG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff176b5b),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 16 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff2d3748),
                      ),
                    ),
                    if (p.description != p.name) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  fmt.format(p.amount),
                  style: TextStyle(
                    fontSize: compact ? 22 : 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xff176b5b),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget otherCard({bool compact = false}) => Material(
        color: const Color(0xffe2f1ec),
        borderRadius: BorderRadius.circular(22),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: other,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 10 : 12),
                  decoration: BoxDecoration(
                    color: const Color(0xff176b5b).withAlpha(40),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: compact ? 26 : 34,
                    color: const Color(0xff176b5b),
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Other Expense',
                      style: TextStyle(
                        fontSize: compact ? 16 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff176b5b),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Custom entry',
                      style: TextStyle(
                        fontSize: compact ? 11 : 13,
                        color: const Color(0xff176b5b).withAlpha(180),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '+ Enter',
                  style: TextStyle(
                    fontSize: compact ? 22 : 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xff176b5b),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget tile(Entry e, {bool allowDelete = true}) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xffe2f1ec),
            child: Icon(Icons.payments_outlined, color: Color(0xff176b5b)),
          ),
          title: Text(
            e.description,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(DateFormat('dd MMM yyyy · hh:mm a').format(e.time)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmt.format(e.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
              if (allowDelete) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => confirmAndDelete(e),
                  icon: const Icon(Icons.delete_outline, color: Colors.black45),
                  tooltip: 'Delete entry',
                ),
              ],
            ],
          ),
        ),
      );

  Widget history() {
    final n = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            stat('This week', total(n.subtract(const Duration(days: 7)))),
            const SizedBox(width: 10),
            stat('This month', total(DateTime(n.year, n.month, 1))),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This year', style: TextStyle(color: Colors.black54)),
              Text(
                fmt.format(total(DateTime(n.year))),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              'ALL ENTRIES',
              style: TextStyle(
                letterSpacing: 1.3,
                fontWeight: FontWeight.bold,
                color: Color(0xff176b5b),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: entries.isEmpty ? null : copy,
              icon: const Icon(Icons.content_copy_outlined),
              tooltip: 'Copy report',
            ),
            IconButton(
              onPressed: entries.isEmpty ? null : pdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
            ),
          ],
        ),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 45),
            child: Center(
              child: Text(
                'No expenses logged yet.\nYour entries will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            ),
          )
        else
          ...entries.map((e) => tile(e, allowDelete: true)),
      ],
    );
  }

  Widget stat(String s, double v) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s, style: const TextStyle(color: Colors.black54)),
              Text(
                fmt.format(v),
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );

  Widget edit() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Set the label, icon style, cost, and full export description for each quick button.',
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ...presets.asMap().entries.map(
                (x) => Card(
                  elevation: 0,
                  child: ListTile(
                    leading: presetIcon(x.value),
                    title: Text(x.value.name),
                    subtitle: Text(
                      '${fmt.format(x.value.amount)} · ${x.value.description}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => preset(index: x.key),
                  ),
                ),
              ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => preset(),
            icon: const Icon(Icons.add),
            label: const Text('Add quick button'),
          ),
        ],
      );

  Future<void> other() async {
    final n = TextEditingController(), a = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Other expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'What was it?'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: a,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xff176b5b),
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹  ',
                prefixStyle: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff176b5b),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(a.text);
              if (n.text.trim().isNotEmpty && v != null) {
                final newEntry =
                    Entry(n.text.trim(), n.text.trim(), v, DateTime.now());
                setState(() => entries.insert(0, newEntry));
                save();
                Navigator.pop(c);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${newEntry.name} logged · ${fmt.format(newEntry.amount)}'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => unlogEntry(newEntry, silent: true),
                    ),
                  ),
                );
              }
            },
            child: const Text('Log expense'),
          ),
        ],
      ),
    );
  }

  Future<void> preset({int? index}) async {
    final old = index == null ? null : presets[index];
    final n = TextEditingController(text: old?.name),
        a = TextEditingController(text: old?.amount.toString()),
        d = TextEditingController(text: old?.description),
        emoji = TextEditingController(
          text: old?.kind == 'train'
              ? '🚇'
              : old?.kind == 'auto'
                  ? '🛺'
                  : old?.kind == 'bus'
                      ? '🚌'
                      : old?.kind,
        );

    bool useColorEmoji = old?.useColorEmoji ?? false;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: Text(old == null ? 'New quick button' : 'Edit quick button'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: n,
                  decoration: const InputDecoration(labelText: 'Button title'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xffe2f1ec),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Icon Color Style',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      useColorEmoji ? 'Full Color Emoji' : 'Theme Green Icon (Default)',
                      style: TextStyle(
                        fontSize: 12,
                        color: useColorEmoji ? Colors.deepOrange : const Color(0xff176b5b),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: useColorEmoji,
                    onChanged: (val) {
                      setDialogState(() => useColorEmoji = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emoji,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Icon / Emoji selection',
                    helperText: 'Pick an icon below or paste custom emoji',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quick Icons / Emojis:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emojiSuggestions.map((e) {
                    final selected = emoji.text.trim() == e;
                    return InkWell(
                      onTap: () {
                        setDialogState(() => emoji.text = e);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xff176b5b).withAlpha(40)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: selected
                                ? const Color(0xff176b5b)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: useColorEmoji
                            ? Text(e, style: const TextStyle(fontSize: 20))
                            : Icon(getIconData(e), size: 22, color: const Color(0xff176b5b)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: a,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff176b5b),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixText: '₹  ',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: d,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Export description',
                    helperText: 'e.g. Bus (A to B)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (old != null)
              TextButton(
                onPressed: () {
                  setState(() => presets.removeAt(index!));
                  save();
                  Navigator.pop(c);
                },
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(a.text);
                if (n.text.trim().isNotEmpty && v != null) {
                  final x = Preset(
                    n.text.trim(),
                    v,
                    d.text.trim().isEmpty ? n.text.trim() : d.text.trim(),
                    kind: emoji.text.trim().isEmpty ? '🚌' : emoji.text.trim(),
                    useColorEmoji: useColorEmoji,
                  );
                  setState(() {
                    if (old == null) {
                      presets.add(x);
                    } else {
                      presets[index!] = x;
                    }
                  });
                  save();
                  Navigator.pop(c);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String report() {
    final b = StringBuffer(
      'EXPENSE REPORT\nGenerated ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}\n\n',
    );
    for (final e in entries) {
      b.writeln(
        '${DateFormat('dd MMM yyyy, hh:mm a').format(e.time)}  |  ${e.description}  |  ${fmt.format(e.amount)}',
      );
    }
    b.writeln(
      '\nTOTAL: ${fmt.format(entries.fold(0.0, (s, e) => s + e.amount))}',
    );
    return b.toString();
  }

  void copy() {
    Clipboard.setData(ClipboardData(text: report()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Professional expense report copied')),
    );
  }

  Future<void> pdf() async {
    final d = pw.Document();
    final rows = entries
        .map(
          (e) => [
            DateFormat('dd MMM yyyy\nhh:mm a').format(e.time),
            e.description,
            fmt.format(e.amount),
          ],
        )
        .toList();
    d.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Expense Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date & time', 'Description', 'Amount'],
            data: rows,
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'TOTAL  ${fmt.format(entries.fold(0.0, (s, e) => s + e.amount))}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await d.save(),
      filename:
          'expense-report-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }
}
