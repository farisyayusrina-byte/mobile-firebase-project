const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({region: "asia-southeast1"});

/**
 * Client writes to `fcm_outbox/{id}` → sends FCM to recipient and
 * saves a copy in `users/{toUserId}/notifications`.
 */
exports.sendPushOnOutbox = onDocumentCreated("fcm_outbox/{docId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();
  const toUserId = data.toUserId;
  const fromUserId = data.fromUserId;
  const title = data.title || "Split";
  const body = data.body || "";
  const billId = data.billId || "";
  const type = data.type || "split_request";

  const ref = snap.ref;
  const db = admin.firestore();

  if (!toUserId) {
    await ref.update({
      status: "error",
      error: "missing_toUserId",
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  if (toUserId === fromUserId) {
    await ref.update({
      status: "skipped",
      error: "self_send",
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  try {
    const userDoc = await db.collection("users").doc(toUserId).get();
    const token = userDoc.data()?.fcmToken;

    if (token) {
      await admin.messaging().send({
        token,
        notification: {title, body},
        data: {
          type,
          billId,
          fromUserId: fromUserId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {channelId: "split_notifications"},
        },
      });
    }

    await db
        .collection("users")
        .doc(toUserId)
        .collection("notifications")
        .add({
          title,
          body,
          type,
          billId: billId || null,
          fromUserId: fromUserId || null,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    await ref.update({
      status: token ? "sent" : "no_token",
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error("sendPushOnOutbox failed", err);
    await ref.update({
      status: "error",
      error: String(err.message || err),
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});
