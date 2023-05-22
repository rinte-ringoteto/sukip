import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInScreen extends StatefulWidget {
  final Function(User?) onSignIn;

  SignInScreen({required this.onSignIn});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  Future<void> _signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      widget.onSignIn(userCredential.user);
    } on FirebaseAuthException catch (e) {
      print(e);
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            // 画像を追加
            'lib/images/logo_main.png', // ここに画像ファイル名を入れてください
            width: 300,
            height: 300,
          ),
          SizedBox(height: 20), // スペースを追加
          Text(
            '大切な人とのつながりを\n楽しみましょう', // ここに表示したいテキストを入れてください
            style: TextStyle(
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40), // スペースを追加
          ElevatedButton.icon(
            onPressed: _signInWithGoogle,
            icon: Icon(Icons.login),
            label: Text("Googleでログイン"),
          ),
        ],
      ),
    );
  }
}
