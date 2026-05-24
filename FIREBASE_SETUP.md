# Firebase database setup (SplitMate)

This app uses **Firebase**, not Laragon MySQL:

| Service | Purpose |
|---------|---------|
| **Firestore** | Users + bills (expenses, history, home) |
| **Firebase Storage** | Receipt images (`receipts/…`) |
| **Firebase Auth** | Login / register |
| **FCM** | Push token on `users/{uid}` |

---

## 1. Firebase Console

Project: **splitmate-mobile** (or your project name).

### Authentication
1. **Build → Authentication → Sign-in method**
2. Enable **Email/Password**

### Firestore Database
1. **Build → Firestore Database → Create database**
2. Start in **test mode** for development, then publish rules below

### Storage
1. **Build → Storage → Get started**
2. Requires **Blaze (pay-as-you-go)** plan to upload from the app
3. Publish storage rules below

---

## 2. Security rules (copy from this repo)

### Firestore
File: `firebase/firestore.rules`

In Console: **Firestore → Rules** → paste → **Publish**

```
users/{userId}   — only that signed-in user can read/write
bills/{billId}   — only owner (userId == auth.uid) can read/write
```

### Storage
File: `firebase/storage.rules`

In Console: **Storage → Rules** → paste → **Publish**

```
receipts/** — read/write only when signed in
```

---

## 3. Data structure

### `users/{uid}`
| Field | Type | Notes |
|-------|------|--------|
| email | string | lowercased |
| displayName | string | |
| fcmToken | string? | from FCM after login |
| createdAt | timestamp | first register |
| updatedAt | timestamp | |

Created automatically on **register/login** via `AuthService.syncUserProfile`.

### `bills/{autoId}`
| Field | Type | Notes |
|-------|------|--------|
| userId | string | owner uid |
| title | string | e.g. "Lunch at Mamak" |
| total | number | RM amount |
| participants | array | member names |
| items | array | `{ name, price, assignedTo }` |
| category | string | Food & Dining, Transport, … |
| status | string | `split` \| `pending` \| `personal` |
| splitMode | string? | `byItems` \| `equally` |
| receiptImageUrl | string? | Storage download URL |
| ocrText | string? | raw OCR text |
| createdAt | timestamp | |
| updatedAt | timestamp | |

---

## 4. How data is saved in the app

| Action | Firestore |
|--------|-----------|
| Register / login | `users/{uid}` |
| Add Bill (manual) | `bills` + optional Storage image |
| Scan → Split → **Confirm & Save Bill** | `bills` + image upload |
| History / Home / Expenses | Read `bills` (live `StreamBuilder`) |
| Bill detail – assign items | `updateBillItems` → updates `status` |

---

## 5. Demo / dummy data

**In the app (easiest):**

1. Login → **Home** tab
2. Tap **Load demo data** on the green banner
3. ~14 sample bills appear in Home, History, and Expenses

**Reseed** deletes your bills and loads fresh samples (for presentations).

Requires Firestore rules published and user logged in.

---

## 6. Notifications (FCM + in-app)

**On login:** app requests permission, saves FCM token to `users/{uid}.fcmToken`.

**In the app:**
- Home → bell icon → **Notifications** list
- **Send test** — local alert + saved to Firestore
- **Copy FCM token** — paste in Firebase Console → Messaging → test message

**Auto alerts when:**
- You save a bill (Add Bill or Split → Confirm & Save)

**Firestore path:** `users/{uid}/notifications/{id}`

Publish updated rules (includes `notifications` subcollection).

**Push from Firebase Console:** Messaging → New campaign → test on device token.

**Push to friends’ phones** — see **`CLOUD_FUNCTIONS_SETUP.md`** (deploy `sendPushOnOutbox`). Add member with their **login email** when splitting.

---

## 7. Verify it works

1. Run app, **register** a new account
2. Firebase Console → **Firestore** → you should see `users` with your uid
3. **Add Bill** from Home or save after **Split**
4. Check `bills` collection — documents should appear
5. **History** and **Expenses** tabs should update automatically

### Common errors

| Error | Fix |
|-------|-----|
| `permission-denied` | Publish Firestore rules (step 2) |
| `configuration-not-found` | Enable Email/Password in Auth |
| Storage upload fails | Enable Blaze plan + Storage rules |
| Empty Home/History | Add at least one bill while logged in |

---

## 8. Optional: Firebase CLI

If you use Firebase CLI:

```bash
firebase deploy --only firestore:rules,storage
```

(Requires `firebase.json` linked to your project.)

---

## Not used

- Laragon **MySQL** — not connected to this Flutter app
- Old demo collection `receipt_images` — legacy; main flow uses `bills`
