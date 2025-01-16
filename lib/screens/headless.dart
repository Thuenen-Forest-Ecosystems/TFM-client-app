import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class StatelessTest extends StatefulWidget {
  const StatelessTest({super.key});

  @override
  State<StatelessTest> createState() => _StatelessTestState();
}

class _StatelessTestState extends State<StatelessTest> {
  HeadlessInAppWebView? headlessWebView;
  String url = "";

  Future _initHeadless() async {
    String htmlString = await rootBundle.loadString('assets/html/index.html');
    //String htmlString = '<html></html>';

    headlessWebView = HeadlessInAppWebView(
      initialFile: htmlString,
      //initialUrlRequest: URLRequest(url: WebUri("https://github.com/flutter")),
      initialSettings: InAppWebViewSettings(isInspectable: kDebugMode),
      onWebViewCreated: (controller) {
        const snackBar = SnackBar(
          content: Text('HeadlessInAppWebView created!'),
          duration: Duration(seconds: 1),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      },
      onConsoleMessage: (controller, consoleMessage) {
        final snackBar = SnackBar(
          content: Text('Console Message: ${consoleMessage.message}'),
          duration: const Duration(seconds: 1),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      },
      onLoadStart: (controller, url) async {
        final snackBar = SnackBar(
          content: Text('onLoadStart $url'),
          duration: const Duration(seconds: 1),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);

        setState(() {
          this.url = url?.toString() ?? '';
        });
      },
      onLoadStop: (controller, url) async {
        var result = await controller.injectJavascriptFileFromAsset(assetFilePath: "assets/html/script.js");
        print(result.runtimeType); // int
        print(result); // 30

        final snackBar = SnackBar(
          content: Text('onLoadStop $url'),
          duration: const Duration(seconds: 1),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);

        setState(() {
          this.url = url?.toString() ?? '';
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initHeadless();
  }

  @override
  void dispose() {
    super.dispose();
    headlessWebView?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stateless Test'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Text('URL: $url'),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    await headlessWebView?.dispose();
                    await headlessWebView?.run();
                  },
                  child: const Text("Run HeadlessInAppWebView")),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    if (headlessWebView?.isRunning() ?? false) {
                      await headlessWebView?.webViewController?.evaluateJavascript(source: "console.log('Here is the message!');");
                    } else {
                      const snackBar = SnackBar(
                        content: Text('HeadlessInAppWebView is not running. Click on "Run HeadlessInAppWebView"!'),
                        duration: Duration(milliseconds: 1500),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  },
                  child: const Text("Send console.log message")),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    if (headlessWebView?.isRunning() ?? false) {
                      await headlessWebView?.webViewController?.evaluateJavascript(source: "TESTFN('Msg from Flutter');");
                    } else {
                      const snackBar = SnackBar(
                        content: Text('HeadlessInAppWebView is not running. Click on "Run HeadlessInAppWebView"!'),
                        duration: Duration(milliseconds: 1500),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  },
                  child: const Text("Send TESTFN message")),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    await headlessWebView?.dispose();
                    setState(() {
                      url = '';
                    });
                  },
                  child: const Text("Dispose HeadlessInAppWebView")),
            ),
          ],
        ),
      ),
    );
  }
}
