const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Helper function to send notification to owners
 * @param {string} shopId
 * @param {string} title
 * @param {string} body
 */
async function sendToOwners(shopId, title, body) {
  const ownersSnapshot = await admin.firestore()
      .collection("users")
      .where("role", "==", "owner")
      .get();

  const tokens = [];
  ownersSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.fcmToken) {
      tokens.push(data.fcmToken);
    }
  });

  if (tokens.length > 0) {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      android: {
        notification: {
          channelId: "high_importance_channel",
        },
      },
      tokens: tokens,
    };
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Successfully sent ${response.successCount} messages`);
  } else {
    console.log("No owner tokens found");
  }
}

// 1. Unified Notification Trigger
exports.onNotificationAdded = onDocumentCreated(
    "notifications/{notifId}",
    async (event) => {
      const notification = event.data.data();
      const shopId = notification.shopId;
      const title = notification.title;
      const body = notification.body;

      return sendToOwners(shopId, title, body);
    },
);
