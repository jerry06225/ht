import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String nas = "http://192.168.1.100:8080";
final FlutterLocalNotificationsPlugin noti = FlutterLocalNotificationsPlugin();

// 主题
const Color bg = Color(0xff0F141E);
const Color card = Color(0xff1A2233);
const Color primary = Colors.orangeAccent;

class Api {
  static Future<Map> dash() async => json.decode(await http.get(Uri.parse("$nas/dashboard")).then((e)=>e.body));
  static Future<Map> btDetail(int id) async => json.decode(await http.get(Uri.parse("$nas/backtest/detail?id=$id")));
  static Future<Map> watchAdd(Map d) async => json.decode(await http.post(Uri.parse("$nas/watch/add"), body: json.encode(d)));
  static Future<Map> trade(String b,String c,int n) async => json.decode(await http.get(Uri.parse("$nas/trade?broker=$b&code=$c&amount=$n")));
  static Future evolve(int id) async => http.get(Uri.parse("$nas/ai/evolve?id=$id"));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await noti.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MainPage()));
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int idx = 0;
  final pages = const [QuotePage(), StrategyPage(), AssetPage(), WatchPage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: pages[idx],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: card, selectedItemColor: primary, unselectedItemColor: Colors.grey,
        currentIndex: idx, onTap: (i)=>setState(()=>idx=i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "行情"),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: "策略"),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: "资产"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "盯盘"),
        ],
      ),
    );
  }
}

// 行情页面
class QuotePage extends StatefulWidget {
  const QuotePage({super.key});
  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> {
  Map data = {};
  @override void initState() {super.initState();load();}
  Future<void> load() async => setState(()=>data = await Api.dash());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg, appBar: AppBar(title: const Text("实时行情"), backgroundColor: card, elevation: 0),
      body: RefreshIndicator(onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          for(var k in (data["stocks"]??{}).keys)
            Card(color: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(padding: const EdgeInsets.all(14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data["stocks"][k]["name"], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12))
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(data["stocks"][k]["price"].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("${data["stocks"][k]["change"]}%", style: TextStyle(color: data["stocks"][k]["change"]>=0?Colors.red:Colors.green))
                ]),
              ])),
            ),
          const SizedBox(height:20),
          const Text("实盘下单", style: TextStyle(fontSize:16, fontWeight:FontWeight.w500)),
          const SizedBox(height:10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primary), onPressed: ()=>Api.trade("htsc","sh600036",100), child: const Text("华泰")),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primary), onPressed: ()=>Api.trade("eastmoney","sh600036",100), child: const Text("东财")),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primary), onPressed: ()=>Api.trade("futu","sh600036",100), child: const Text("富途")),
          ])
        ]),
      ),
    );
  }
}

// 策略页面 + 回测详情入口
class StrategyPage extends StatefulWidget {
  const StrategyPage({super.key});
  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {
  Map data = {};
  @override void initState() {super.initState();load();}
  Future<void> load() async => setState(()=>data = await Api.dash());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg, appBar: AppBar(
        backgroundColor: card, elevation:0, title: const Text("策略中心"),
        actions: [
          TextButton(onPressed: ()=>launchUrl(Uri.parse("$nas/export/excel")), child: const Text("Excel", style: TextStyle(color: Colors.white))),
          TextButton(onPressed: ()=>launchUrl(Uri.parse("$nas/export/pdf")), child: const Text("PDF", style: TextStyle(color: Colors.white))),
        ],
      ),
      body: RefreshIndicator(onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          for(var s in (data["strategies"]??[]))
            Card(color: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                Icon(s["type"]=="ai"?Icons.smart_button:s["type"]=="custom"?Icons.edit:Icons.book, color: primary),
                const SizedBox(width:10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s["name"], style: const TextStyle(fontSize:15, fontWeight:FontWeight.w500)),
                  Text("胜率 ${s["win"]} | 回撤 ${s["dd"]}", style: const TextStyle(color: Colors.grey, fontSize:12))
                ])),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primary), onPressed: ()=>Api.evolve(s["id"]).then((v)=>load()), child: const Text("进化")),
                const SizedBox(width:6),
                TextButton(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (c)=>BacktestDetailPage(id: s["id"]))), child: const Text("详情")),
              ])),
            ),
        ]),
      ),
    );
  }
}

// 回测详情页（新增）
class BacktestDetailPage extends StatefulWidget {
  final int id;
  const BacktestDetailPage({super.key, required this.id});
  @override
  State<BacktestDetailPage> createState() => _BacktestDetailPageState();
}

class _BacktestDetailPageState extends State<BacktestDetailPage> {
  Map data = {};
  @override void initState() {super.initState();load();}
  Future<void> load() async => setState(()=>data = await Api.btDetail(widget.id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: bg, appBar: AppBar(backgroundColor: card, title: Text("${data["name"]} 回测详情")),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(color: card, child: Padding(padding: const EdgeInsets.all(12), child: SizedBox(height:220,
          child: LineChart(LineChartData(lineBarsData: [LineChartBarData(
            spots: [for(int i=0;i<(data["profits"]??[]).length;i++) FlSpot(i.toDouble(), data["profits"][i].toDouble())], color: primary)
          ])),
        )),
        const SizedBox(height:16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          item("总收益", data["total_return"]), item("胜率", data["win_rate"]), item("最大回撤", data["drawdown"]), item("夏普比率", data["sharpe"]),
        ]),
      ])),
    );
  }
  Widget item(String t,String v)=>Column(children: [Text(t, style: const TextStyle(color: Colors.grey)), const SizedBox(height:4), Text(v, style: const TextStyle(fontSize:15, fontWeight:FontWeight.w500))]);
}

// 资产页面
class AssetPage extends StatefulWidget {
  const AssetPage({super.key});
  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  Map data = {};
  @override void initState() {super.initState();load();}
  Future<void> load() async => setState(()=>data = await Api.dash());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg, appBar: AppBar(backgroundColor: card, title: const Text("资产")),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(color: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            const Text("总资产", style: TextStyle(color: Colors.grey)),
            Text(data["asset"]?["total"] ?? "0.00", style: const TextStyle(fontSize:26, fontWeight:FontWeight.bold)),
            const SizedBox(height:16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              col("总盈亏", data["asset"]?["profit"]), col("今日盈亏", data["asset"]?["today"]),
            ])
          ])),
        ),
      ]),
    );
  }
  Widget col(String t,String? v)=>Column(children: [Text(t, style: const TextStyle(color: Colors.grey)), Text(v??"0", style: const TextStyle(color: Colors.red))]);
}

// 盯盘页面（新增）
class WatchPage extends StatefulWidget {
  const WatchPage({super.key});
  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController triCtrl = TextEditingController();

  Future<void> add() async {
    await Api.watchAdd({"code":"sh${codeCtrl.text}","type":"up","trigger":double.parse(triCtrl.text)});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg, appBar: AppBar(backgroundColor: card, title: const Text("价格盯盘")),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "股票代码")),
          TextField(controller: triCtrl, decoration: const InputDecoration(labelText: "触发价")),
          const SizedBox(height:12),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primary), onPressed: add, child: const Text("添加监控")),
        ]))),
      ]),
    );
  }
}
