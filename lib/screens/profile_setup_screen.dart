import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sukip2/utils/firestore_helpers.dart';
import 'package:sukip2/screens/sign_in_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileSetupScreen extends StatefulWidget {
  final User user;

  final VoidCallback onLogout; // コールバックを追加

  ProfileSetupScreen({required this.user, required this.onLogout}); // コールバックを追加

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final _uniqueIdController = TextEditingController();
  final _nicknameController = TextEditingController();
  File? _profileImage;
  bool _isLoading = false; // この行を追加
  User? _user;

  String? _profileImageUrl;
  String? _currentUniqueId;

  @override
  void initState() {
    super.initState();
    _getUserDetails();
    _user = widget.user;
  }

  Future<void> _getUserDetails() async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final userDoc = await usersRef.doc(widget.user.uid).get();
    if (userDoc.exists) {
      if (mounted) {
        // この行を追加
        setState(() {
          _nicknameController.text = userDoc['nickname'] ?? '';
          _uniqueIdController.text = userDoc['uniqueId'] ?? '';
          _profileImageUrl = userDoc['photoUrl'] as String?;
          _currentUniqueId = userDoc['uniqueId'] as String?;
        });
      } // この行を追加
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (mounted) {
      // この行を追加
      setState(() {
        if (pickedFile != null) {
          _profileImage = File(pickedFile.path);
        } else {
          print("No image selected.");
        }
      });
    } // この行を追加
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) {
      return null;
    }

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('${widget.user.uid}.jpg');
    final uploadTask = storageRef.putFile(_profileImage!);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _handleAuthChanged(User? user) async {
    if (mounted) {
      setState(() {
        _user = user;
      });
    }

    if (user != null) {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final docRef = usersRef.doc(user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileSetupScreen(
                user: _user!,
                onLogout: () async {
                  await FirebaseAuth.instance.signOut();
                  await GoogleSignIn().signOut();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("ログアウトしました")),
                  );
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _user = user;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ログインしました")),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // if (mounted) {
      //   setState(() {
      //     _isLoading = true;
      //   });
      // }

      print(_currentUniqueId);
      print(_uniqueIdController.text);
      final isUniqueIdChanged = _currentUniqueId != _uniqueIdController.text;
      if (isUniqueIdChanged) {
        final unique = await isUniqueId(_uniqueIdController.text);
        if (!unique) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("このIDはすでに使用されています。別のIDを入力してください。")),
          );
          return;
        }
        _currentUniqueId = _uniqueIdController.text;
      }

      String? photoUrl;
      if (_profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child("user_photos")
            .child("${widget.user.uid}.jpg");
        final uploadTask = storageRef.putFile(_profileImage!);
        await uploadTask.whenComplete(() async {
          photoUrl = await storageRef.getDownloadURL();
        });
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.user.uid)
          .set({
        'uniqueId': _uniqueIdController.text,
        'nickname': _nicknameController.text,
        "photoUrl":
            photoUrl ?? _profileImageUrl, // プロフィール画像が選択されない場合、以前の画像を維持します
        "email": widget.user.email, // メールアドレスを保存します
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("プロフィールが更新されました")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            SizedBox(height: 16),
            if (_profileImage != null)
              Center(
                child: Image.network(
                  _profileImageUrl!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(height: 16),
            // プロフィール画像選択ボタン
            ElevatedButton(
              onPressed: _pickProfileImage,
              child: Text("プロフィール画像を選択"),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nicknameController,
              decoration: InputDecoration(labelText: "ニックネーム"),
              validator: (value) {
                if (value!.isEmpty) {
                  return 'ニックネームを入力してください';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _uniqueIdController,
              decoration: InputDecoration(labelText: "ユニークID"),
              validator: (value) {
                if (value!.isEmpty) {
                  return 'ユニークIDを入力してください';
                }
                return null;
              },
            ),

            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveProfile,
              child: Text("保存"),
            ),
            // ログアウトボタンを追加
            if (FirebaseAuth.instance.currentUser != null)
              // ElevatedButton(
              //   onPressed: () async {
              //     await FirebaseAuth.instance.signOut();
              //     await GoogleSignIn().signOut();
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       SnackBar(content: Text("ログアウトしました")),
              //     );
              //     // ログアウト後にサインイン画面に遷移
              //     widget.onLogout();
              //   },
              //   child: Text("ログアウト"),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor:
              //         Color.fromARGB(0, 255, 255, 255), // ボタンの背景色を透明に設定
              //     foregroundColor: Colors.black, // テキストの色を黒に設定
              //   ),
              // ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(child: CircularProgressIndicator()),
                ),
          ],
        ),
      ),
    );
  }
}
