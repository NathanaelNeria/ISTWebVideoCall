import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:image_downloader/image_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:core';
import 'signaling.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'package:email_validator/email_validator.dart';


class CallSample extends StatefulWidget {
  static String tag = 'call_sample';

  final String host;

  CallSample({Key key, @required this.host}) : super(key: key);

  @override
  _CallSampleState createState() => _CallSampleState();
}

class _CallSampleState extends State<CallSample> {
  final _formKey = GlobalKey<FormState>();
  Signaling _signaling;
  List<dynamic> _peers;
  var _selfId;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  Session _session;
  DateTime selectedDate = DateTime.now();
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  File ektp;
  File selfieEktp;

  String ektpUrl;
  String selfieEktpUrl;

  bool nikvalidate = false;
  bool emailvalidate = false;

  FirebaseStorage storage = FirebaseStorage.instance;

  String nik = '';
  String name = '';
  String pob = '';
  String dob = '';
  String email = '';
  String mobile = '';
  String address = '';

  final TextEditingController nikController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pobController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // ignore: unused_element
  _CallSampleState({Key key});

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    if (_signaling != null) _signaling.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _connect() async {
    if (_signaling == null) {
      _signaling = Signaling(widget.host)..connect();

      _signaling.onSignalingStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
          case SignalingState.ConnectionOpen:
            break;
        }
      };

      _signaling.onCallStateChange = (Session session, CallState state) {
        switch (state) {
          case CallState.CallStateNew:
            setState(() {
              _session = session;
              _inCalling = true;
            });
            break;
          case CallState.CallStateBye:
            setState(() {
              _localRenderer.srcObject = null;
              _remoteRenderer.srcObject = null;
              _inCalling = false;
              _session = null;
            });
            break;
          case CallState.CallStateInvite:
          case CallState.CallStateConnected:
          case CallState.CallStateRinging:
        }
      };

      _signaling.onPeersUpdate = ((event) {
        setState(() {
          _selfId = event['self'];
          _peers = event['peers'];
        });
      });

      _signaling.onLocalStream = ((_, stream) {
        _localRenderer.srcObject = stream;
        setState(() {}); // ADD THIS
      });

      _signaling.onAddRemoteStream = ((_, stream) {
        _remoteRenderer.srcObject = stream;
        setState(() {}); // AND ADD THIS
      });

      _signaling.onRemoveRemoteStream = ((_, stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }

  _invitePeer(BuildContext context, String peerId, bool useScreen) async {
    if (_signaling != null && peerId != _selfId) {
      _signaling.invite(peerId, 'video', useScreen);
    }
  }

  _hangUp() {
    if (_signaling != null) {
      _signaling.bye(_session.sid);
    }
  }

  _switchCamera() {
    _signaling.switchCamera();
  }

  _muteMic() {
    _signaling.muteMic();
  }

  _buildRow(context, peer) {
    var self = (peer['id'] == _selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + '[Your self]'
            : peer['name'] + '[' + peer['user_agent'] + ']'),
        onTap: null,
        trailing: SizedBox(
            width: 100.0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.videocam),
                    onPressed: () => _invitePeer(context, peer['id'], false),
                    tooltip: 'Video calling',
                  ),
                  IconButton(
                    icon: const Icon(Icons.screen_share),
                    onPressed: () => _invitePeer(context, peer['id'], true),
                    tooltip: 'Screen sharing',
                  )
                ])),
        subtitle: Text('id: ' + peer['id']),
      ),
      Divider()
    ]);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(1950, 1),
        lastDate: DateTime(2101));
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
        dob = selectedDate.toString();
        print(dob);
      });
  }

    Widget _eKtp() {
      if (ektpUrl == null) {
        return Image.asset("images/no_photo_selected.png",
          width: 200.0,
          height: 300.0,
          fit: BoxFit.cover,);
      } else {
        return Image.network(
          ektpUrl,
          height: 300.0,
          width: 200.0,
          fit: BoxFit.cover,
        );
      }
    }

  Widget _selfieEktp() {
    if (selfieEktpUrl == null) {
      return Image.asset("images/no_photo_selected.png",
        width: 200.0,
        height: 300.0,
        fit: BoxFit.cover,);
    } else {
      return Image.network(
        selfieEktpUrl,
        height: 300.0,
        width: 200.0,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Call Sample'),

        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: null,
            tooltip: 'setup',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 200.0,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // FloatingActionButton(
                    //   child: const Icon(Icons.switch_camera),
                    //   onPressed: _switchCamera,
                    // ),
                    FloatingActionButton(
                      onPressed: _hangUp,
                      tooltip: 'Hangup',
                      child: Icon(Icons.call_end),
                      backgroundColor: Colors.pink,
                    ),
                    FloatingActionButton(
                      child: const Icon(Icons.mic_off),
                      onPressed: _muteMic,
                    ),
                    FloatingActionButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  content: Container(
                                    child: SingleChildScrollView(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            Positioned(
                                              right: -40.0,
                                              top: -40.0,
                                              child: InkResponse(
                                                onTap: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: CircleAvatar(
                                                  child: Icon(Icons.close),
                                                  backgroundColor: Colors.red,
                                                ),
                                              ),
                                            ),
                                            Form(
                                              key: _formKey,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  ListTile(
                                                    title: new TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: "NIK",
                                                      ),
                                                      controller: nikController,
                                                      maxLength: 16,
                                                      onChanged: (String value) {
                                                        if(nikController.text.length > 15){
                                                          this.setState(() {
                                                            nik = value;
                                                            nikvalidate = true;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  ListTile(
                                                    title: new TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: "Name",
                                                      ),
                                                      controller: nameController,
                                                      onChanged: (String value){
                                                        this.setState(() {
                                                          name = value;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  ListTile(
                                                    title: new TextField(
                                                      decoration:
                                                      InputDecoration(
                                                        hintText: "Address",
                                                      ),
                                                      controller: addressController,
                                                      onChanged: (String value){
                                                        this.setState(() {
                                                          address = value;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  ListTile(
                                                    title: new TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            "Place of Birth",
                                                      ),
                                                      controller: pobController,
                                                      onChanged: (String value){
                                                        this.setState(() {
                                                          pob = value;
                                                          print(pob);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  // Text(
                                                  //     "${selectedDate.toLocal()}"
                                                  //         .split(' ')[0]),
                                                  ListTile(
                                                    title: new TextField(
                                                      decoration:
                                                      InputDecoration(
                                                        hintText: selectedDate.toString().split(' ')[0],
                                                      ),
                                                      enabled: false,
                                                      controller: dobController,
                                                      // onChanged: (String value){
                                                      //   this.setState(() {
                                                      //     email = value;
                                                      //   });
                                                      // },
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height: 20.0,
                                                  ),
                                                  RaisedButton(
                                                    onPressed: () {
                                                      _selectDate(context);
                                                      this.setState(() {
                                                        dobController.text = selectedDate.toString();
                                                      });
                                                    },
                                                    child:
                                                        Text('Date of Birth'),
                                                  ),
                                                  ListTile(
                                                    title: new TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: "Email",
                                                      ),
                                                      controller: emailController,
                                                      onChanged: (String value){
                                                        this.setState(() {
                                                          email = value;
                                                          emailvalidate = EmailValidator.validate((value));
                                                          emailvalidate = true;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  ListTile(
                                                    title: new TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: "Mobile Number",
                                                      ),
                                                      controller: mobileController,
                                                      onChanged: (String value) {
                                                        setState(() {
                                                          mobile = value;
                                                          print(mobile);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  _eKtp(),
                                                  _selfieEktp(),
                                                  Padding(
                                                    padding:
                                                      const EdgeInsets.all(8.0),
                                                    child: RaisedButton(
                                                      child: Text('Retrieve'),
                                                      onPressed: (){
                                                        storage.ref().child('ektp.jpg').getDownloadURL().then((url){
                                                          setState(() {
                                                            ektpUrl = url;
                                                          });
                                                        });
                                                        
                                                        storage.ref().child('selfieEktp.jpg').getDownloadURL().then((url){
                                                          setState(() {
                                                            selfieEktpUrl = url;
                                                          });
                                                        });
                                                        
                                                        firestore.collection('form').doc('user').get().then((result){
                                                          Map <String, dynamic> data = result.data();
                                                          setState(() {
                                                            nik = data['nik'];
                                                            name = data['name'];
                                                            pob = data['pob'];
                                                            dob = data['dob'];
                                                            email = data['email'];
                                                            mobile = data['mobile'];
                                                            address = data['address'];

                                                            nikController.text = nik;
                                                            nameController.text = name;
                                                            addressController.text = address;
                                                            pobController.text = pob;
                                                            dobController.text = dob.split(' ')[0];
                                                            emailController.text = email;
                                                            mobileController.text = mobile;
                                                          });
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: RaisedButton(
                                                      child: Text("Submit"),
                                                      onPressed: () {
                                                        if(nik != null && name != null && pob != null && dob != null && mobile != null) {
                                                          firestore.collection('form').doc('user').set({
                                                            'nik': nik,
                                                            'name': name,
                                                            'address': address,
                                                            'pob': pob,
                                                            'dob': dob,
                                                            'email': email,
                                                            'mobile': mobile,
                                                          }).whenComplete(() => print('upload complete'))
                                                          .catchError((e) => print(e));
                                                          Navigator.pop(context);
                                                        }
                                                      },
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ]),
                                    ),
                                  ),
                                );
                              });
                        },
                        child: Text("Form"))
                  ]))
          : null,
      body: _inCalling
          ? OrientationBuilder(builder: (context, orientation) {
              return Container(
                child: Stack(children: <Widget>[
                  Positioned(
                      left: 0.0,
                      right: 0.0,
                      top: 0.0,
                      bottom: 0.0,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: RTCVideoView(_remoteRenderer),
                        decoration: BoxDecoration(color: Colors.black54),
                      )),
                  Positioned(
                    left: 20.0,
                    top: 20.0,
                    child: Container(
                      width: orientation == Orientation.portrait ? 90.0 : 120.0,
                      height:
                          orientation == Orientation.portrait ? 120.0 : 90.0,
                      child: RTCVideoView(_localRenderer, mirror: true),
                      decoration: BoxDecoration(color: Colors.black54),
                    ),
                  ),
                ]),
              );
            })
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(0.0),
              itemCount: (_peers != null ? _peers.length : 0),
              itemBuilder: (context, i) {
                return _buildRow(context, _peers[i]);
              }),
    );
  }
}
