import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class Proposal {
  String id;
  String title;
  String github;
  String type;
  bool result = false;

  Proposal(
      {required this.id,
      required this.title,
      required this.github,
      required this.type});
}


class LoadingWidget extends StatefulWidget {
  final String text;
  final Stream<String>? stream;

  LoadingWidget({required this.text, this.stream});

  @override
  State<StatefulWidget> createState() {
    return _LoadingWidget();
  }
}

class _LoadingWidget extends State<LoadingWidget> {
  String? _text;
  StreamSubscription<String>? _textSub;

  void initAsync() async {
    _text = widget.text;

    if (widget.stream != null) {
      _textSub = widget.stream!.listen((event) {
        setState(() {
          _text = event;
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initAsync();
  }

  @override
  void dispose() {
    super.dispose();

    if (_textSub != null) {
      _textSub!.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.transparent,
        child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(height: 100, width: 100, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
              SizedBox(height: 20),
              Text(this._text ?? '')
            ])));
  }
}


class LoadingOverlay {
  BuildContext _context;
  Stream<String> _loadingText;

  void hide() {
    Navigator.of(_context).pop();
  }

  void show() {
    showDialog(
        context: _context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Container(
              child: Material(
                  type: MaterialType.transparency,
                  child: LoadingWidget(
                    text: 'Loading',
                    stream: _loadingText,
                  )));
        });
  }

  Future<T> during<T>(Future<T> future, {String? text}) {
    show();
    return future.whenComplete(() => hide());
  }

  LoadingOverlay._create(this._context, this._loadingText);

  factory LoadingOverlay.of(BuildContext context, {Stream<String>? loadingText}) {
    Stream<String> controller;
    if (loadingText == null) {
      // ignore: close_sinks
      var streamController = StreamController<String>();
      streamController.add('Loading');
      controller = streamController.stream;
    } else {
      controller = loadingText;
    }
    var overlay = LoadingOverlay._create(context, controller);
    return overlay;
  }
}


class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DefiChain Masternode DFIP/CFP Signer',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: MyHomePage(title: 'DefiChain Masternode DFIP/CFP Signer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _addressController =
      TextEditingController(text: 'http://127.0.0.1:8555/');
  var _usernameController = TextEditingController(text: 'aRcHsKuR');
  var _passwordController = TextEditingController(
      text: 'c29193c17fc12001a1e890a2199b539253b65689cf6980d2aead5e6a7ffd9e88');

  Map<int, Widget> _widgets = new Map<int, Widget>();
  var _myMasterNodes = [];
  var _masterNodes = [];
  var _signedMessages = [];
  String _signedText = '';

  bool _masterNodesLoaded = false;

  var dfips = [
    new Proposal(
        id: 'dfip-10',
        title:
            'Long-term (5y & 10y) lock-in of staking DFI in exchange for higher staking returns',
        github: 'https://github.com/DeFiCh/dfips/issues/39',
        type: 'DFIP'),
    new Proposal(
        id: 'dfip-11',
        title: 'Interim ticker council establishment for asset tokenization',
        github: 'https://github.com/DeFiCh/dfips/issues/41',
        type: 'DFIP'),
    new Proposal(
        id: 'cfp-12',
        title: 'DeFiChain Promo (15,000 DFI + 6,000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/28',
        type: 'CFP'),
    new Proposal(
        id: 'cfp-13',
        title: 'DeFiChain bug bounty fund pre-allocation (10,000 DFI)',
        github: 'https://github.com/DeFiCh/dfips/issues/30',
        type: 'CFP'),
  ];

  @override
  void initState() {
    super.initState();
  }

  void listMasterNodes() async {

    final overlay = LoadingOverlay.of(context);
    overlay.show();

    var masterNodes = await createJsonRpcCall('listmasternodes', {
      "pagination": {"including_start": true, "limit": 100000}
    });

    setState(() {
      _myMasterNodes = [];
      _signedMessages = [];
      _signedText = '';
    });

    for (var mn in masterNodes.values) {
      var addressInfo = await getAddressInfo(mn['ownerAuthAddress']);

      _masterNodes.add(mn);

      if (addressInfo['ismine'] == true) {
        _myMasterNodes.add(mn);
      }
    }

    setState(() {
      _masterNodes = _masterNodes;
      _myMasterNodes = _myMasterNodes;
      _masterNodesLoaded = true;
    });

    overlay.hide();
  }

  void signMessageCfps() async
  {
    final overlay = LoadingOverlay.of(context);
    overlay.show();

    _signedMessages = [];

    for (var proposal in dfips) {
      _signedMessages.add('=========================');
      _signedMessages.add('');
      _signedMessages.add(proposal.github);
      _signedMessages.add('');
      _signedMessages.add('');

      for (var mn in _myMasterNodes) {
        var message = proposal.id + " " + (proposal.result ? "yes" : "no");

        _signedMessages.add('\$ defi-cli signmessage ' + mn['ownerAuthAddress'] + " " + message);
        _signedMessages.add(await signMessage(mn['ownerAuthAddress'], message));
      }

      _signedMessages.add('=========================');
    }

    setState(() {
      _signedMessages = _signedMessages;
      _signedText = _signedMessages.join('\n');
    });

    overlay.hide();
  }

  dynamic signMessage(String owner, String message)
  {
    return createJsonRpcCall("signmessage", [owner, message]);
  }

  dynamic getAddressInfo(String owner) {
    return createJsonRpcCall('getaddressinfo', [owner]);
  }

  dynamic createJsonRpcCall(String method, dynamic params) async {
    String username = _usernameController.text;
    String password = _passwordController.text;
    String address = _addressController.text;
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));

    Map<String, String> headers = {
      'content-type': 'application/json',
      'accept': 'application/json',
      'authorization': basicAuth
    };

    String stringParams = json.encode(params);

    http.Response response = await http.post(Uri.parse(address),
        headers: headers,
        body:
            '{"jsonrpc": "1.0", "id":"curltest", "method": "$method", "params": $stringParams }');

    final decoded = json.decode(response.body);

    if (null != decoded['error']) {
      return null;
    }

    return decoded['result'];
  }

  @override
  Widget build(BuildContext context) {
    var scrollView = CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(10),
              child: Container(
                margin: EdgeInsets.only(top: 10.0),
                child: Row(children: [
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                              child: SizedBox(height: 300, child: Scrollbar(
                                  child: ListView(shrinkWrap: true,children: [
                            ListView.builder(
                                physics: BouncingScrollPhysics(),
                                scrollDirection: Axis.vertical,
                                shrinkWrap: true,
                                itemCount: _myMasterNodes.length,
                                itemBuilder: (context, index) {
                                  var mn = _myMasterNodes.elementAt(index);
                                  return SelectableText(mn['ownerAuthAddress'] ?? '');
                                })
                          ]))))),
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(height: 300, child: Scrollbar(
                              child: SelectableText(_signedText))))),
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(children: [
                            TextField(
                              controller: _addressController,
                              decoration:
                                  InputDecoration(hintText: 'RPC Address'),
                            ),
                            TextField(
                              controller: _usernameController,
                              decoration:
                                  InputDecoration(hintText: 'RPC Username'),
                            ),
                            TextField(
                              controller: _passwordController,
                              decoration:
                                  InputDecoration(hintText: 'RPC Password'),
                            ),
                            Padding(padding: EdgeInsets.only(top: 10)),
                            ElevatedButton(
                                onPressed: listMasterNodes,
                                child: Text('LoadMasterNodes')),
                            Padding(padding: EdgeInsets.only(top: 10)),
                            ElevatedButton(
                                onPressed: _masterNodesLoaded ? signMessageCfps : null,
                                child: Text('Sign'))
                          ])))
                ]),
              )),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final account = dfips[index];
              return new Column(children: [
                Text(account.title),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Radio(
                      value: true,
                      groupValue: account.result,
                      onChanged: (var value) {
                        setState(() {
                          account.result = true;
                        });
                      },
                    ),
                    new Text(
                      'Yes',
                      style: new TextStyle(fontSize: 16.0),
                    ),
                    new Radio(
                      value: false,
                      groupValue: account.result,
                      onChanged: (var value) {
                        setState(() {
                          account.result = false;
                        });
                      },
                    ),
                    new Text(
                      'No',
                      style: new TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                )
              ]);
            },
            childCount: dfips.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(10),
              child: Container(
                margin: EdgeInsets.only(top: 10.0),
                child: Column(children: [

                ]),
              )),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: LayoutBuilder(builder: (_, builder) {
        return scrollView;
      }),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: Icon(Icons.add),
      // ),
    );
  }
}
