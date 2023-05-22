import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sukip2/screens/user_profile_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  late QRViewController _qrController;

  // QRコードの読み取り時に呼び出されるメソッド
  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null) {
        await _searchUserByUniqueId(scanData.code!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("QRコードが無効です")),
        );
      }
    });
  }

  Future<void> _searchUserByUniqueId(String uniqueId) async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('users')
        .where('uniqueId', isEqualTo: uniqueId)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot docSnapshot = querySnapshot.docs.first;

      // Get the current user
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser!.uid == docSnapshot.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("自分自身を検索することはできません")),
        );
        return;
      }

      // Create a chat room if it doesn't exist
      String chatRoomId = createChatRoomId(currentUser.uid, docSnapshot.id);

      final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);

      final chatRoomSnapshot = await chatRoomRef.get();
      if (!chatRoomSnapshot.exists) {
        // Create a new chat room
        await chatRoomRef.set({
          'roomName': docSnapshot['nickname'],
          'members': [currentUser.uid, docSnapshot.id],
        });
      }

      // Navigate to the chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: docSnapshot.id,
            nickname: docSnapshot['nickname'],
            uniqueId: docSnapshot['uniqueId'],
            photoUrl: docSnapshot['photoUrl'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ユーザーが見つかりません")),
      );
    }
  }

  String createChatRoomId(String user1, String user2) {
    return (user1.compareTo(user2) < 0) ? '$user1-$user2' : '$user2-$user1';
  }

  Stream<QuerySnapshot> _followingStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('following')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ユーザー検索"),
      ),
      body: Column(
        children: [
          // Padding(
          //   padding: EdgeInsets.all(16.0),
          //   child: TextField(
          //     controller: _searchController,
          //     decoration: InputDecoration(labelText: "ユーザーIDを入力"),
          //     onSubmitted: (value) async {
          //       if (value.trim().isNotEmpty) {
          //         await _searchUserByUniqueId(value.trim());
          //       }
          //     },
          //   ),
          // ),
          // TextButton(
          //   onPressed: () async {
          //     if (_searchController.text.trim().isNotEmpty) {
          //       await _searchUserByUniqueId(_searchController.text.trim());
          //     }
          //   },
          //   child: Text("検索"),
          // ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final userData = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .get();
                  final uniqueId = userData['uniqueId'];
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text("あなたのQRコード"),
                      content: SizedBox(
                        width: 200.0,
                        height: 200.0,
                        child: QrImage(
                          data: uniqueId,
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                      ),
                    ),
                  );
                },
                child: Text("QRコードを表示"),
              ),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text("QRコードをスキャン"),
                      content: Container(
                        width: 300,
                        height: 300,
                        child: QRView(
                          key: qrKey,
                          onQRViewCreated: _onQRViewCreated,
                        ),
                      ),
                    ),
                  );
                },
                child: Text("QRコードをスキャン"),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "大切な3人",
              style: TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _followingStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text("エラー: ${snapshot.error}");
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final followingDoc = snapshot.data!.docs[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(followingDoc.id)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.hasError) {
                          return Text("エラー: ${userSnapshot.error}");
                        }

                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userData['photoUrl'] != null
                                ? NetworkImage(userData['photoUrl'] as String)
                                : AssetImage('lib/images/default_avatar.png')
                                    as ImageProvider<Object>,
                          ),
                          title: Text(userData['nickname'] ?? 'Unknown'),
                          subtitle: Text(userData['uniqueId'] ?? 'Unknown'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(
                                  userId: userSnapshot.data!.id,
                                  nickname: userData['nickname'] ?? 'Unknown',
                                  uniqueId: userData['uniqueId'] ?? 'Unknown',
                                  photoUrl: userData['photoUrl'],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
