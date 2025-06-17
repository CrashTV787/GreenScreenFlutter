import 'dart:convert';

import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:installed_apps/installed_apps.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'WebView Data Bridge',
      home: WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;

  void getUsageStats() async {
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(Duration(hours: 1));
    List<AppUsageInfo> infoList =
    await AppUsage().getAppUsage(startDate, endDate);
    String json = await YourNativePlugin.getDeviceData();
    print(json);

    for (var info in infoList) {
      print(info.toString());
    }
  }

  @override
  void initState() {
    super.initState();

    getUsageStats();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'fetchNativeData',
        onMessageReceived: (JavaScriptMessage message) async {
          // Call your native plugin to get device data
          final data = await YourNativePlugin.getDeviceData();
          // Send the data back to the web content by invoking a JS callback
          final jsonData = Uri.encodeComponent(data.toString());
          _controller.runJavaScript(
              "window.onNativeData && window.onNativeData(decodeURIComponent('$jsonData'));"
          );
        },
      )
      ..loadRequest(
        //Uri.parse('http://10.0.2.2:8080'),
        Uri.parse('https://greenscreen.chrixel.com'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('WebView Data Bridge')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class YourNativePlugin {
  static Future<String> getDeviceData() async {
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(const Duration(hours: 24));

    // Get usage data
    List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);

    // Get user-installed apps only (exclude system apps)
    List<AppInfo> installedUserApps = await InstalledApps.getInstalledApps(true);

    // Create a set of package names
    final userAppPackages = installedUserApps
        .map((app) => app.packageName)
        .toSet();

    // Filter usage data to only include user-installed apps
    List<Map<String, dynamic>> jsonList = infoList
        .where((info) => userAppPackages.contains(info.packageName))
        .map((info) => {
      'packageName': info.packageName,
      'appName': info.appName,
      'usage': info.usage.inSeconds,
      'startTime': info.startDate.toIso8601String(),
      'endTime': info.endDate.toIso8601String(),
    })
        .toList();

    return jsonEncode(jsonList);
  }
}
