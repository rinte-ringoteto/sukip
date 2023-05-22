import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> isUniqueId(String id) async {
  final usersRef = FirebaseFirestore.instance.collection('users');
  final querySnapshot = await usersRef.where('uniqueId', isEqualTo: id).get();
  return querySnapshot.docs.isEmpty;
}
