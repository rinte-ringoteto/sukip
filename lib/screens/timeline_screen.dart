import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';

class TimelineScreen extends StatefulWidget {
  @override
  _TimelineScreenState createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TextEditingController _postController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _submitPost() async {
    if (_postController.text.trim().isEmpty) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    await _firestore.collection('posts').add({
      'content': _postController.text.trim(),
      'authorId': currentUser!.uid,
      'timestamp': Timestamp.now(),
    });

    _postController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("投稿が完了しました")),
    );
  }

  Future<String> _getUsername(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    return userDoc['nickname'];
  }

  Future<String> _getUserProfileImageUrl(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    return userDoc['profileImageUrl'];
  }

  Stream<List<QueryDocumentSnapshot>> _timelineStream() {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Get the list of users that the current user is following, including the current user
    final followingStream = _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('following')
        .snapshots();

    return followingStream.switchMap((snapshot) {
      final followedUserIds = snapshot.docs.map((doc) => doc.id).toList();

      // Include the current user's ID as well
      followedUserIds.add(currentUser.uid);

      // Use the 'whereIn' operator to get posts with multiple 'authorId's in a single query
      return _firestore
          .collection('posts')
          .where('authorId', whereIn: followedUserIds)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("タイムライン"),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: InputDecoration(labelText: "投稿内容を入力"),
                  ),
                ),
                TextButton(
                  onPressed: _submitPost,
                  child: Text("投稿"),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.data == null) {
                  return Center(child: Text("ログインしていません"));
                }

                return StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _timelineStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text("エラー: ${snapshot.error}");
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.data == null || snapshot.data!.isEmpty) {
                      return Center(child: Text("まだ投稿がありません"));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final postDoc = snapshot.data![index];
                        final authorId = postDoc['authorId'];
                        final timestamp = postDoc['timestamp'].toDate();
                        final formattedDate =
                            DateFormat('yyyy/MM/dd HH:mm').format(timestamp);

                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection('users')
                              .doc(authorId)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            final authorDoc = snapshot.data!;
                            final authorName = authorDoc['nickname'];
                            final photoUrl = authorDoc['photoUrl'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : Image.asset(
                                            'lib/images/default_avatar.png')
                                        .image,
                              ),
                              title: Text(authorName),
                              subtitle: Text(postDoc['content']),
                              trailing: Text(formattedDate),
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
