# Cloud Functions — push notifications to friends

When you save a split bill with a member’s **registered email**, the app writes to `fcm_outbox`. A Cloud Function sends **FCM push** to their phone and adds a row in their **Notifications** list.

---

## Prerequisites

1. **Blaze (pay-as-you-go)** plan on Firebase project `splitmate-mobile`
2. **Firestore rules** published (includes `fcm_outbox` — see `firebase/firestore.rules`)
3. **Node.js 20** installed on your PC
4. **Firebase CLI**: `npm install -g firebase-tools`

---

## Deploy (one time)

```bash
cd c:\laragon\www\MOBILE
firebase login
firebase use splitmate-mobile
cd functions
npm install
cd ..
firebase deploy --only functions
```

You should see: `sendPushOnOutbox` deployed to `asia-southeast1`.

---

## How to test with 2 accounts

1. **Phone A** — register `usera@test.com`, login, allow notifications  
2. **Phone B** — register `userb@test.com`, login, allow notifications  
3. On **Phone A**: Scan or Split → **Add member**  
   - Name: `Friend`  
   - Email: `userb@test.com` (exact login email on Phone B)  
4. Assign items → **Confirm & Save Bill**  
5. **Phone B** should get a push: *"… invited you to split …"*

---

## Flow

```
App → fcm_outbox/{id}  (Firestore)
        ↓
Cloud Function sendPushOnOutbox
        ↓
FCM → friend's device
        +
users/{friendId}/notifications/{id}
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No push on friend phone | Friend must **login once** (saves `fcmToken` in `users`) |
| `permission-denied` on save | Publish updated Firestore rules |
| Function not running | `firebase deploy --only functions` |
| `no_token` in outbox doc | Friend reopens app while logged in |
| Email not found | Email must match `users.email` in Firestore exactly |

Check function logs:

```bash
firebase functions:log --only sendPushOnOutbox
```

Check outbox in Console: **Firestore → fcm_outbox** → field `status`: `sent` | `no_token` | `error`

---

## Files

| Path | Purpose |
|------|---------|
| `functions/index.js` | Cloud Function |
| `lib/services/push_outbox_service.dart` | App queues messages |
| `firebase/firestore.rules` | Security for `fcm_outbox` |
