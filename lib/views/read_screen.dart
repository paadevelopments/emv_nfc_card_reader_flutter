import 'dart:convert';
import 'package:emv_sample/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});
  @override
  State<ReadScreen> createState() => _ReadScreenState();
}
class _ReadScreenState extends State<ReadScreen> {

  MethodChannel javaChannel = const MethodChannel("com.example.emv_sample");
  bool setupComplete = false;
  int setupStatusIndex = 0;
  String setupMessage = "Initializing SDK..";
  bool isScanning = false;
  String scanResult = "";
  int flowIndex = 0;
  
  Future<void> checkNFCStatus() async {
    try {
      setupStatusIndex = await javaChannel.invokeMethod('init');
      if (setupStatusIndex != 2) {
        setState(() {
          setupMessage = setupStatusIndex == 0 ? "NFC Unavailable" : "Turn on NFC and restart the app";
          setupComplete = true;
        });
        return;
      }
      setState(() { flowIndex++; setupComplete = true; });
    } on PlatformException {
      setState(() {
        setupStatusIndex = 0;
        setupMessage = "NFC Unavailable";
        setupComplete = true;
      });
    }
  }

  Future<void> initCardScanListener() async {
    try {
      final scanOp = json.decode(await javaChannel.invokeMethod("listen"));
      if (scanOp['success']) {
        setState(() { scanResult = scanOp['cardData']; flowIndex++; isScanning = false; });
        return;
      }
      throw PlatformException(code: '01', stacktrace: scanOp['error']);
    } on PlatformException catch(e) {
      if (context.mounted) {
        setState(() { flowIndex--; isScanning = false; });
        showSnackMessage(context, e.message.toString(), [ "OK", (){} ],);
      }
    }
  }

  Future<void> forceTerminateNFC() async {
    // ignore: empty_catches
    try { await javaChannel.invokeMethod('terminate'); } on PlatformException {  }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkNFCStatus());
  }

  @override
  Widget build(BuildContext context) {
    
    Widget body = Container();
    
    switch(flowIndex) {
      case 0:
        body = Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100, height: 100,
              child: !setupComplete
                  ? const CircularProgressIndicator(strokeWidth: 5,)
                  : Icon(setupStatusIndex != 2
                      ? Icons.error_outline_outlined : Icons.check_circle_outline_outlined,
                      size: 100,
                    )
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(setupMessage),
            )
          ],
        ),);
      case 1:
        body = const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 100, height: 100,
                child: Icon(Icons.check_circle_outline_outlined, size: 100, color: Colors.green,)
            ),
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text("SDK ready. Use the button below to start scanning a card", textAlign: TextAlign.center,),
            )
          ],
        ),);
        break;
      case 2:
        body = const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 100, height: 100,
                child: Icon(Icons.tap_and_play_outlined, size: 100,)
            ),
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text("Tap card to scan", textAlign: TextAlign.center,),
            )
          ],
        ),);
        break;
      case 3:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10,),
              child: Text("Card Read Successful.\nSee below logs for more info."),
            ),
            Expanded(child: Container(
              decoration: const BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(Radius.circular(5))
              ),
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 100),
              child: SingleChildScrollView(child: Align(
                alignment: Alignment.topLeft,
                child: Text(scanResult),
              ),),
            ),),
          ],
        );
        break;
      default:
        break;
    }
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("EMV Sample"),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        width: double.maxFinite,
        height: double.maxFinite,
        child: body,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: !setupComplete || isScanning ? null : () {
          setState(() { isScanning = true; flowIndex = 2; scanResult = ""; });
          initCardScanListener();
        },
        tooltip: 'Read Card',
        child: !setupComplete || isScanning
            ? Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),),
            )
            : const Icon(Icons.add_card_outlined),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
