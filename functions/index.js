const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotification = functions.firestore
    .document("chatRooms/{chatRoomId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
      const messageData = snapshot.data();
      const chatRoomId = context.params.chatRoomId;

      // 通知の内容を設定
      const payload = {
        notification: {
          title: "新しいメッセージ",
          body: `${messageData.senderName}: ${messageData.content}`,
        },
      };

      // チャットルームの参加者を取得
      const participantsSnapshot = await admin
          .firestore()
          .collection("chatRoomParticipants")
          .doc(chatRoomId)
          .collection("participants")
          .get();

      // 参加者のFCMトークンを取得
      const registrationTokens = participantsSnapshot.docs.map(
          (doc) => doc.data().fcmToken,
      );

      // 通知を送信
      const multicastMessage = {
        tokens: registrationTokens,
        ...payload,
      };

      try {
        const res = await admin.messaging().sendMulticast(multicastMessage);
        console.log("Notification sent successfully:", res);
      } catch (error) {
        console.log("Error sending notification:", error);
      }
    });
