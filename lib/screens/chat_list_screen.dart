import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sukip2/screens/chat_screen.dart';
import 'package:sukip2/screens/search_screen.dart'; // 新しいインポート
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<DocumentSnapshot> _getPeerData(String peerId) async {
    DocumentSnapshot peerDoc = await _db.collection('users').doc(peerId).get();
    return peerDoc;
  }

  Stream<DocumentSnapshot> _getLastMessageStream(String roomId) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.first);
  }

  int _calculateUnreadMessagesCount(
      Map<String, dynamic> chatRoomData, String currentUserId) {
    int totalMessagesCount = chatRoomData['totalMessagesCount'] as int;
    int readMessagesCount =
        chatRoomData['readMessagesCount'][currentUserId] as int;
    return totalMessagesCount - readMessagesCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('チャット一覧'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('chatRooms')
            .where('members', arrayContains: _currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chatRoomData = snapshot.data!.docs[index].data()!;
              final chatRoom = chatRoomData as Map<String, dynamic>;
              String peerId = (chatRoom['members'])
                  .firstWhere((memberId) => memberId != _currentUser!.uid);

              int unreadMessagesCount =
                  _calculateUnreadMessagesCount(chatRoom, _currentUser!.uid);

              return FutureBuilder<DocumentSnapshot>(
                future: _getPeerData(peerId),
                builder: (context, peerSnapshot) {
                  if (!peerSnapshot.hasData) {
                    return SizedBox.shrink();
                  }
                  final peerData =
                      peerSnapshot.data!.data()! as Map<String, dynamic>;
                  ;

                  return StreamBuilder<DocumentSnapshot>(
                    stream:
                        _getLastMessageStream(snapshot.data!.docs[index].id),
                    builder: (context, lastMessageSnapshot) {
                      if (!lastMessageSnapshot.hasData) {
                        return SizedBox.shrink();
                      }
                      final lastMessage = lastMessageSnapshot.data!.data()!
                          as Map<String, dynamic>;
                      ;
                      final DateTime timestamp =
                          lastMessage['timestamp']?.toDate()?.toLocal() ??
                              DateTime.now();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: peerData['photoUrl'] != null &&
                                  (peerData['photoUrl'] as String).isNotEmpty
                              ? NetworkImage(peerData['photoUrl'] as String)
                              : Image.asset('lib/images/default_avatar.png')
                                  .image,
                        ),
                        title: Text(peerData['nickname'] as String? ?? ''),
                        subtitle: Text(lastMessage['content'] as String? ?? ''),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(timestamp),
                            ),
                            if (unreadMessagesCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.0, vertical: 2.0),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Text(
                                    '$unreadMessagesCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.0,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                peerId: peerId,
                                peerNickname:
                                    peerData['nickname'] as String? ?? '',
                                peerAvatar: peerData['photoUrl'] as String? ??
                                    'lib/images/default_avatar.png',
                                chatRoomId: snapshot.data!.docs[index].id,
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
          );
        },
      ),
    );
  }
}
