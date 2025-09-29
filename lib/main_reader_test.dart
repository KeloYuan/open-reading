import 'package:flutter/material.dart';
import 'examples/reader_demo_page.dart';

/// 阅读器测试入口
void main() {
  runApp(const ReaderTestApp());
}

/// 阅读器测试应用
class ReaderTestApp extends StatelessWidget {
  const ReaderTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '阅读器测试',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ReaderDemoPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

