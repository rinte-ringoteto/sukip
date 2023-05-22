import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sukip2/screens/sign_in_screen.dart';
import 'package:sukip2/screens/profile_setup_screen.dart';
import 'package:sukip2/screens/chat_list_screen.dart';
import 'package:sukip2/screens/search_screen.dart';
import 'package:sukip2/screens/timeline_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCMの初期化
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // 通知の許可をリクエスト
  await _firebaseMessaging.requestPermission();

  // FCMのトークンを取得
  String? token = await _firebaseMessaging.getToken();
  print('FCM Token: $token');

  runApp(MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(notification.title ?? ''),
              content: Text(notification.body ?? ''),
            );
          },
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // Handle notification tap action here
    });

    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFFFE0E6),
        appBarTheme: AppBarTheme(
          backgroundColor: Color.fromRGBO(221, 29, 29, 1),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Color.fromRGBO(221, 29, 29, 1),
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromRGBO(221, 29, 29, 1)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Color.fromRGBO(221, 29, 29, 1),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Color.fromRGBO(221, 29, 29, 1),
          ),
        ),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
    _configureFirebaseMessaging();
  }

  void _configureFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // バックグラウンドでの通知処理の設定
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 通知の許可を要求
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 通知の設定状況を表示（オプション）
    print('User granted permission: ${settings.authorizationStatus}');

    // 通知の受信時の処理
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        // ここで通知を表示したり、処理を行います
      }
    });
  }

  int _currentIndex = 0;

  final List<Widget> _children = [
    SearchScreen(),
    TimelineScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _checkCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    _handleAuthChanged(user);
    setState(() {
      _user = user;
    });
  }

  Future<void> _handleAuthChanged(User? user) async {
    setState(() {
      _user = user;
    });

    if (user != null) {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final docRef = usersRef.doc(user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ログインしました")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 3 && _user != null
          ? AppBar(
              title: Text("プロフィール設定"),
              actions: [
                IconButton(
                  icon: Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    await GoogleSignIn().signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("ログアウトしました")),
                    );
                    setState(() {
                      _user = null;
                    });
                  },
                ),
              ],
            )
          : null,
      body: _user == null
          ? SignInScreen(onSignIn: _handleAuthChanged)
          : _children[_currentIndex],
      bottomNavigationBar: _user == null
          ? null
          : BottomNavigationBar(
              onTap: onTabTapped,
              currentIndex: _currentIndex,
              unselectedItemColor: Colors.grey, // 未選択のアイコンの色をグレーに設定
              selectedItemColor: Colors.red,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.timeline), // この行を追加
                  label: 'TimeLine', // この行を追加
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat),
                  label: 'Chats',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final _user = FirebaseAuth.instance.currentUser;

    if (_user == null) {
      return Center(child: Text("ログインしていません"));
    }

    return ProfileSetupScreen(
      user: _user,
      onLogout: () async {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ログアウトしました")),
        );
      },
    );
  }
}
