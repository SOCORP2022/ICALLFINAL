import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:i_call/Contacts/usermodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FBCloudStore {
  var date = new DateTime.now();
  static FBCloudStore get instanace => FBCloudStore();
  User _userik = FirebaseAuth.instance.currentUser;
  // About Firebase Database
  Future<List<String>> saveUserDataToFirebaseDatabase(userEmail,userId,userName,userPhone,downloadUrl) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final QuerySnapshot result = await FirebaseFirestore.instance.collection('users').where('userId', isEqualTo: prefs.get('userId')).get();
      final List<DocumentSnapshot> documents = result.docs;
      String myID = _userik.uid;
      if (documents.length == 0) {
        await prefs.setString('userId',_userik.uid);
        await FirebaseFirestore.instance.collection('users').doc(_userik.uid).set({
          'email':userEmail,
          'name':userName,
          'phone':userPhone.toString(),
          'userImageUrl':downloadUrl,
          'userId': _userik.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'FCMToken':prefs.get('FCMToken')?? 'NOToken',
          'first' : 0
        });
      }else {
        myID = documents[0]['userId'];
        await prefs.setString('userId',_userik.uid);
        await FirebaseFirestore.instance.collection('users').doc(_userik.uid).update({
          'email':userEmail,
          'name':userName,
          'phone':userPhone.toString(),
          'userImageUrl':downloadUrl,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'FCMToken':prefs.get('FCMToken')?? 'NOToken',
          'first': 0
        });
      }
      return [_userik.uid,downloadUrl];
    }catch(e) {
      print(e.message);
      return null;
    }
  }

  Future<void> updateMyChatListValues(String documentID,String chatID,bool isInRoom) async{
    var updateData = isInRoom ? {
      'inRoom':isInRoom,
      'badgeCount':0
    }:{
      'inRoom':isInRoom
    };
    final DocumentReference result = FirebaseFirestore.instance.collection('users').doc(documentID).collection('chatlist').doc(chatID);
    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(result);
      if (!snapshot.exists) {
        transaction.set(result, updateData);
      }else{
        transaction.update(result, updateData);
      }
    });
    // await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(documentID)
    //     .collection('chatlist')
    //     .doc(chatID)
    //     .set(updateData);
    int unReadMSGCount = await FBCloudStore.instanace.getUnreadMSGCount(documentID);
    FlutterAppBadger.updateBadgeCount(unReadMSGCount);
  }

  Future<void> updateUserToken(userID, token) async {
    User _userik = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('users').doc(_userik.uid).update({
      'FCMToken':token,
    });
  }

  Future<List<DocumentSnapshot>> takeUserInformationFromFBDB() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final QuerySnapshot result =
    await FirebaseFirestore.instance.
      collection('users').
      where('FCMToken', isEqualTo: prefs.get('FCMToken') ?? 'None').
      get();
    return result.docs;
  }

  Future<int> getUnreadMSGCount(String peerUserID) async{
    try {
      int unReadMSGCount = 0;
      QuerySnapshot userChatList = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userik.uid)
          .collection('chatlist')
          .get();
      List<QueryDocumentSnapshot> chatListDocuments = userChatList.docs;
      for(QueryDocumentSnapshot snapshot in chatListDocuments){
        unReadMSGCount = unReadMSGCount + snapshot['badgeCount'];
      }
      print('unread MSG count is $unReadMSGCount');
      return unReadMSGCount;
    }catch(e) {
      print(e.message);
    }
  }

  Future updateUserChatListField(String documentID,String lastMessage,chatID,myID,selectedUserID) async{

    var userBadgeCount = 0;
    var isRoom = false;
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(documentID)
        .collection('chatlist')
        .doc(chatID)
        .get();

    if(userDoc.data() != null) {
      isRoom = userDoc['inRoom'] ?? false;
      if(userDoc != null && documentID != _userik.uid && !userDoc['inRoom']){
        userBadgeCount = userDoc['badgeCount'];
        userBadgeCount++;
      }
    }else{
      userBadgeCount++;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(documentID)
        .collection('chatlist')
        .doc(chatID)
        .set({'chatID':chatID,
      'chatWith':documentID == myID ? selectedUserID : myID,
      'lastChat':lastMessage,
      'badgeCount': isRoom ? 0 : userBadgeCount,
      'inRoom':isRoom,
      'timestamp':DateTime.now().millisecondsSinceEpoch});
  }

  Future sendMessageToChatRoom(chatID,myID,selectedUserID,content,messageType) async {
    await FirebaseFirestore.instance
        .collection('chatroom')
        .doc(chatID)
        .collection(chatID)
        .doc(DateTime.now().millisecondsSinceEpoch.toString()).set({
      'idFrom': _userik.uid,
      'idTo': selectedUserID,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'content': content,
      'type':messageType,
      'isread':false,
      'time': date.hour
    });
    await FirebaseFirestore.instance.collection('chatroom')
        .doc(chatID).set({
      "status" : "not"


    });
  }
  Future < List < UserModel >  > getAppContacts ( ) async {
    try {
      final data = await FirebaseFirestore.instance.collection(" users ").get();
      return data.docs.map((e) => UserModel.fromJson(e.data())).toList();
    } on Exception catch (e) {
      return Future.value(null);
    }
  }

}