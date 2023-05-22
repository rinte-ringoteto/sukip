import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sukip2/screens/chat_screen.dart';
import 'dart:async';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String nickname;
  final String uniqueId;
  final String? photoUrl;

  UserProfileScreen({
    required this.userId,
    required this.nickname,
    required this.uniqueId,
    required this.photoUrl,
  });

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isFollowing = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _getUserProfile();
    _checkIfFollowing();
  }

  Future<void> _getUserProfile() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    setState(() {
      _userProfile = userDoc.data() as Map<String, dynamic>?;
    });
  }

  Future<String> _getCurrentUserNickname() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      return currentUserDoc['nickname'] as String;
    } else {
      return '';
    }
  }

  Future<void> _checkIfFollowing() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final followingSnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(widget.userId)
        .get();

    setState(() {
      _isFollowing = followingSnapshot.exists;
    });
  }

  Future<String> _createChatRoomName() async {
    final currentUserNickname = await _getCurrentUserNickname();
    return '${currentUserNickname}-${_userProfile!['nickname']}';
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (_isFollowing) {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(widget.userId)
          .delete();
      setState(() {
        _isFollowing = false;
      });
    } else {
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .get();

      if (followingSnapshot.docs.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("フォローできるユーザーは最大3人です")),
        );
        return;
      }

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(widget.userId)
          .set({});
      setState(() {
        _isFollowing = true;
      });
    }
  }

  String getChatRoomId(String a, String b) {
    return a.hashCode <= b.hashCode ? '$a-$b' : '$b-$a';
  }

  Future<bool> chatRoomExists(String chatRoomId) async {
    final chatRoomSnapshot =
        await _firestore.collection('chatRooms').doc(chatRoomId).get();
    return chatRoomSnapshot.exists;
  }

  Widget _buildChatButton() {
    Future<void> _addUserToChatRoomParticipants(String chatRoomId) async {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final fcmToken = await FirebaseMessaging.instance.getToken();

      // 自分のデータを chatRoomParticipants に追加
      await _firestore
          .collection('chatRoomParticipants')
          .doc(chatRoomId)
          .collection('participants')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'fcmToken': fcmToken,
      });

      // 相手のデータを chatRoomParticipants に追加
      await _firestore
          .collection('chatRoomParticipants')
          .doc(chatRoomId)
          .collection('participants')
          .doc(widget.userId)
          .set({
        'userId': widget.userId,
        'fcmToken': _userProfile!['fcmToken'],
      });
    }

    return ElevatedButton(
      onPressed: () async {
        final chatRoomId = getChatRoomId(
            widget.userId, FirebaseAuth.instance.currentUser!.uid);
        final exists = await chatRoomExists(chatRoomId);

        if (!exists) {
          final chatRoomName = await _createChatRoomName();
          await _firestore.collection('chatRooms').doc(chatRoomId).set({
            'chatRoomName': chatRoomName,
            'members': [widget.userId, FirebaseAuth.instance.currentUser!.uid],
            'totalMessagesCount': 0,
            'readMessagesCount': {
              widget.userId: 0,
              FirebaseAuth.instance.currentUser!.uid: 0,
            },
            // 初期化時に各ユーザーの readMessages を空のリストに設定
            'readMessages': {
              widget.userId: [],
              FirebaseAuth.instance.currentUser!.uid: [],
            },
          });
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoomId,
              peerId: widget.userId,
              peerNickname: _userProfile!['nickname'],
              peerAvatar: _userProfile!['photoUrl'],
            ),
          ),
        );
      },
      child: Text("チャット画面へ"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ユーザープロフィール"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.photoUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(widget.photoUrl!),
                radius: 50,
              )
            else
              CircleAvatar(
                backgroundImage: widget.photoUrl != null
                    ? NetworkImage(widget.photoUrl!)
                    : Image.asset('lib/images/default_avatar.png')
                        .image, // ここを変更
                radius: 50,
              ),
            SizedBox(height: 16),
            Text("ニックネーム: ${widget.nickname}"),
            SizedBox(height: 8),
            Text("ユニークID: ${widget.uniqueId}"),
            SizedBox(height: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _isFollowing
                    ? _buildChatButton()
                    : SizedBox
                        .shrink(), // Show an empty widget if not following
                ElevatedButton(
                  onPressed: _toggleFollow,
                  child: Text(_isFollowing ? "フォロー解除" : "フォロー"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
