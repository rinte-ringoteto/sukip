import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String peerId;
  final String peerNickname;
  final String? peerAvatar;

  ChatScreen({
    required this.chatRoomId,
    required this.peerId,
    required this.peerNickname,
    this.peerAvatar,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _markVisibleMessagesAsRead();
    });
    _configureFirebaseMessaging(); // Call this method in initState
  }

// Add this method to configure Firebase Messaging
  void _configureFirebaseMessaging() {
    // Request notification permissions for iOS devices
    _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    // On message received
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null &&
          message.data['chatRoomId'] == widget.chatRoomId) {
        // Show an in-app notification if needed
        // You can customize this as you want
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${notification.title}: ${notification.body}'),
          ),
        );
      }
    });
  }

  Future<void> _markVisibleMessagesAsRead() async {
    final currentUserId = _auth.currentUser!.uid;
    final querySnapshot = await _firestore
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    final chatRoomDoc =
        await _firestore.collection('chatRooms').doc(widget.chatRoomId).get();
    List<String>? readMessagesList =
        chatRoomDoc.get('readMessages.$currentUserId')?.cast<String>();

    if (readMessagesList == null) {
      readMessagesList = [];
    }

    final visibleMessageIds = <String>[];
    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] != currentUserId &&
          !readMessagesList.contains(doc.id)) {
        visibleMessageIds.add(doc.id);
      }
    }

    final chatRoomRef =
        _firestore.collection('chatRooms').doc(widget.chatRoomId);

    await chatRoomRef.update({
      'readMessages.$currentUserId': FieldValue.arrayUnion(visibleMessageIds),
      'readMessagesCount.$currentUserId':
          FieldValue.increment(visibleMessageIds.length),
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(widget.peerId)
          .get();

      if (!followingSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("このユーザーにメッセージを送るにはフォローが必要です。"),
          ),
        );
        return;
      }

      final senderDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      final newMessage = {
        'content': _messageController.text.trim(),
        'senderId': _auth.currentUser!.uid,
        'senderName': senderDoc.get('nickname'),
        'senderAvatar': senderDoc.get('photoUrl'),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add(newMessage);

      await _firestore.collection('chatRooms').doc(widget.chatRoomId).update({
        'totalMessagesCount': FieldValue.increment(1),
        'readMessagesCount.${_auth.currentUser!.uid}': FieldValue.increment(1),
      });

      // メッセージ送信後、テキストフィールドをクリアする
      _messageController.clear();
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final chatRoomRef =
          _firestore.collection('chatRooms').doc(widget.chatRoomId);

      // Firestore から既読メッセージの情報を取得します
      final chatRoomDoc = await chatRoomRef.get();
      List<String>? readMessagesList =
          chatRoomDoc.get('readMessages.${currentUser.uid}')?.cast<String>();

      // 既読メッセージの情報が存在しない場合、空のリストを作成します
      if (readMessagesList == null) {
        readMessagesList = [];
      }

      // メッセージが既読でない場合、既読メッセージリストに追加し、Firestore を更新します
      if (!readMessagesList.contains(messageId)) {
        readMessagesList.add(messageId);

        await chatRoomRef.update({
          'readMessagesCount.${currentUser.uid}': FieldValue.increment(1),
          'readMessages.${currentUser.uid}': readMessagesList,
        });
      }
    }
  }

  Widget _buildMessage(Map<String, dynamic> data, bool isMe, String messageId) {
    final String content = data['content'] as String;
    final DateTime timestamp =
        data['timestamp']?.toDate()?.toLocal() ?? DateTime.now();
    final String formattedTimestamp =
        DateFormat('MM/dd HH:mm').format(timestamp);

    void onVisibilityChanged(VisibilityInfo info) async {
      if (!isMe && info.visibleFraction == 1.0) {
        await markMessageAsRead(messageId);
      }
    }

    return VisibilityDetector(
      key: Key(messageId),
      onVisibilityChanged: onVisibilityChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe)
              CircleAvatar(
                backgroundImage: (data.containsKey('senderAvatar') &&
                        data['senderAvatar'] != null)
                    ? NetworkImage(data['senderAvatar'] as String)
                    : Image.asset('lib/images/default_avatar.png')
                        .image, // ここを変更
              ),
            if (!isMe) SizedBox(width: 8.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    data.containsKey('senderName')
                        ? data['senderName'] as String
                        : '',
                  ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue : Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content),
                      SizedBox(height: 4.0),
                    ],
                  ),
                ),
                Text(
                  formattedTimestamp,
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerNickname),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chatRooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot doc = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == _auth.currentUser!.uid;

                    return _buildMessage(data, isMe, doc.id);
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力',
                      contentPadding: EdgeInsets.all(8.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await _sendMessage();
                  _messageController.clear();
                },
                icon: Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
