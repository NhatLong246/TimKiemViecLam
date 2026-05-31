const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const DEFAULT_PREFS = {
  job: true,
  system: true,
  promo: false,
  profile: true,
  message: true,
};

/** Map legacy `type` → category prefs key. */
function categoryFromPayload(payload) {
  if (payload.category) return payload.category;
  const type = (payload.type || '').toString();
  if (type === 'message') return 'message';
  if (type === 'application' || type.startsWith('disbursement')) return 'job';
  if (type === 'review') return 'profile';
  if (type.includes('complaint')) return 'system';
  return 'system';
}

function prefsAllow(prefs, category) {
  const p = { ...DEFAULT_PREFS, ...(prefs || {}) };
  return p[category] !== false;
}

/** FCM `data` chỉ nhận string. */
function stringifyData(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj || {})) {
    if (v === null || v === undefined) continue;
    if (typeof v === 'object') {
      out[k] = JSON.stringify(v);
    } else {
      out[k] = String(v);
    }
  }
  return out;
}

async function isGroupMuted(userId, groupId) {
  if (!groupId) return false;
  const snap = await db.collection('groupChats').doc(groupId).get();
  if (!snap.exists) return false;
  const mutedBy = snap.data().mutedBy || [];
  return mutedBy.includes(userId);
}

async function collectTokens(userId) {
  const userSnap = await db.collection('users').doc(userId).get();
  if (!userSnap.exists) return { tokens: [], prefs: {} };

  const raw = userSnap.data().fcmTokens || {};
  const tokens = Object.keys(raw).filter((t) => t && t.length > 10);
  return { tokens, prefs: userSnap.data().notificationPrefs || {} };
}

async function sendPushToUser(userId, payload) {
  if (!userId) return null;

  const { tokens, prefs } = await collectTokens(userId);
  if (!tokens.length) {
    console.log('No FCM tokens for user', userId);
    return null;
  }

  const category = categoryFromPayload(payload);
  if (!prefsAllow(prefs, category)) {
    console.log('Push blocked by prefs', userId, category);
    return null;
  }

  const type = (payload.type || '').toString();
  const groupId = (payload.groupId || '').toString();

  if (category === 'message' || type === 'message') {
    if (await isGroupMuted(userId, groupId)) {
      console.log('Push blocked — muted group', userId, groupId);
      return null;
    }
  }

  const title = (payload.title || 'ViecNow').toString();
  const body = (payload.body || '').toString();

  const dataPayload = stringifyData({
    type: type || category,
    category,
    groupId,
    jobId: payload.jobId || '',
    appId: payload.appId || '',
    noticeId: payload.noticeId || '',
    phase: payload.phase || '',
  });

  // Gộp thêm field từ nested `data` map (legacy notifications).
  if (payload.data && typeof payload.data === 'object') {
    Object.assign(dataPayload, stringifyData(payload.data));
  }

  const message = {
    tokens,
    notification: { title, body },
    data: dataPayload,
    android: {
      priority: 'high',
      notification: {
        channelId: 'viecnow_default',
        priority: 'high',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  const res = await messaging.sendEachForMulticast(message);
  console.log(
    `Push → ${userId}: success=${res.successCount} fail=${res.failureCount}`,
  );

  // Dọn token hết hạn.
  const stale = [];
  res.responses.forEach((r, i) => {
    if (
      !r.success &&
      r.error &&
      (r.error.code === 'messaging/registration-token-not-registered' ||
        r.error.code === 'messaging/invalid-registration-token')
    ) {
      stale.push(tokens[i]);
    }
  });
  if (stale.length) {
    const updates = {};
    stale.forEach((t) => {
      updates[`fcmTokens.${t}`] = FieldValue.delete();
    });
    await db.collection('users').doc(userId).update(updates);
  }

  return res;
}

function buildPayloadFromLegacy(data) {
  const nested = data.data && typeof data.data === 'object' ? data.data : {};
  return {
    title: data.title,
    body: data.body,
    type: data.type || nested.type || 'system',
    category: categoryFromPayload({ type: data.type, ...nested }),
    groupId: nested.groupId || data.groupId || '',
    jobId: nested.jobId || data.jobId || '',
    appId: nested.appId || '',
    noticeId: nested.noticeId || '',
    phase: nested.phase || '',
    data: nested,
  };
}

function buildPayloadFromInbox(data) {
  const nested = data.data && typeof data.data === 'object' ? data.data : {};
  return {
    title: data.title,
    body: data.body,
    type: nested.type || data.category || 'system',
    category: data.category || categoryFromPayload(nested),
    groupId: nested.groupId || '',
    jobId: nested.jobId || '',
    appId: nested.appId || '',
    noticeId: nested.noticeId || '',
    phase: nested.phase || '',
    data: nested,
  };
}

/** NTD legacy collection — bỏ qua nếu đã push qua inbox. */
exports.onLegacyNotificationCreated = onDocumentCreated(
  'notifications/{notifId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return null;
    if (data.suppressPush === true) return null;

    const recipientId = data.recipientId;
    if (!recipientId) return null;

    return sendPushToUser(recipientId, buildPayloadFromLegacy(data));
  },
);

/** Hộp thư user — push chính cho UV + NTD. */
exports.onUserInboxNotificationCreated = onDocumentCreated(
  'users/{userId}/notifications/{notifId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return null;

    const userId = event.params.userId;
    return sendPushToUser(userId, buildPayloadFromInbox(data));
  },
);
