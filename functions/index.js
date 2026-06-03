const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
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
  if (
    type === 'application' ||
    type.startsWith('application_') ||
    type.startsWith('disbursement') ||
    type === 'job_work_period_ended' ||
    type === 'job_cancelled'
  ) {
    return 'job';
  }
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

async function claimJobWorkflowOnce(jobId, field) {
  try {
    return await db.runTransaction(async (tx) => {
      const ref = db
        .collection('jobPosts')
        .doc(jobId)
        .collection('workflowReminders')
        .doc('disbursement');
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() : {};
      if (data && data[field]) return false;
      tx.set(ref, { [field]: FieldValue.serverTimestamp() }, { merge: true });
      return true;
    });
  } catch (err) {
    console.error('Failed to claim workflow reminder', jobId, field, err);
    return false;
  }
}

async function notifyEmployerFromFunction({
  employerId,
  type,
  title,
  body,
  data,
}) {
  const nestedData = { type, ...(data || {}) };
  await db.collection('notifications').add({
    recipientId: employerId,
    type,
    title,
    body,
    data: nestedData,
    isRead: false,
    suppressPush: true,
    createdAt: FieldValue.serverTimestamp(),
  });

  await db
    .collection('users')
    .doc(employerId)
    .collection('notifications')
    .add({
      title,
      body,
      category: 'job',
      isRead: false,
      data: nestedData,
      createdAt: FieldValue.serverTimestamp(),
    });
}

function isActiveJob(job) {
  return job.status === 'approved' || job.status === 'active';
}

function shouldNotifyUnderfilledApplicationDeadline(job, nowDate) {
  const deadline = job.applicationDeadline?.toDate?.();
  const startDate = job.startDate?.toDate?.();
  if (!deadline || !startDate) return false;
  if (!isActiveJob(job)) return false;
  if (job.underfilledAccepted === true) return false;

  const slots = Number(job.slots || 0);
  const filledSlots = Number(job.filledSlots || 0);
  if (slots <= 0 || filledSlots >= slots) return false;
  if (deadline >= nowDate) return false;
  return startDate > nowDate;
}

exports.notifyUnderfilledApplicationDeadlines = onSchedule(
  {
    schedule: 'every 15 minutes',
    timeZone: 'Asia/Ho_Chi_Minh',
  },
  async () => {
    const now = Timestamp.now();
    const nowDate = now.toDate();
    const snap = await db
      .collection('jobPosts')
      .where('applicationDeadline', '<=', now)
      .get();

    let sent = 0;
    for (const doc of snap.docs) {
      const job = doc.data();
      if (!shouldNotifyUnderfilledApplicationDeadline(job, nowDate)) continue;

      const employerId = (job.employerId || '').toString();
      if (!employerId) continue;

      const claimed = await claimJobWorkflowOnce(
        doc.id,
        'applicationDeadlineUnderfilledNotifiedAt',
      );
      if (!claimed) continue;

      const slots = Number(job.slots || 0);
      const filledSlots = Number(job.filledSlots || 0);
      const missingSlots = Math.max(slots - filledSlots, 0);
      const titleText = (job.title || 'Công việc').toString();

      await notifyEmployerFromFunction({
        employerId,
        type: 'application_deadline_underfilled',
        title: 'Hết hạn ứng tuyển - chưa đủ người',
        body:
          `"${titleText}" hiện có ${filledSlots}/${slots} ứng viên, ` +
          `thiếu ${missingSlots} người. Mở Quản lý bài đăng để tiếp tục job hoặc hủy.`,
        data: {
          jobId: doc.id,
          filledSlots,
          slots,
          missingSlots,
        },
      });
      sent += 1;
    }

    console.log(`Underfilled application deadline notifications sent=${sent}`);
  },
);

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

exports.autoRequestDisbursement = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: 'Asia/Ho_Chi_Minh',
  },
  async () => {
    // endDate là 00:00:00 của ngày đó. Công việc kết thúc vào 24:00:00.
    // Chờ thêm 3 giờ sau khi kết thúc => 27 giờ sau mốc 00:00:00 của endDate.
    const thresholdTime = new Date(Date.now() - 27 * 60 * 60 * 1000);
    const snap = await db
      .collection('jobPosts')
      .where('endDate', '<=', Timestamp.fromDate(thresholdTime))
      .get();

    let createdCount = 0;
    for (const doc of snap.docs) {
      const job = doc.data();
      if (!isActiveJob(job)) continue;

      const employerId = (job.employerId || '').toString();
      if (!employerId) continue;

      const claimed = await claimJobWorkflowOnce(doc.id, 'autoDisbursementRequestedAt');
      if (!claimed) continue;

      const groupId = (job.groupChatId || '').toString();
      if (!groupId) continue; // Không có group chat = không có thành viên

      // Kiểm tra group chat có thành viên nào không
      const groupSnap = await db.collection('groupChats').doc(groupId).get();
      if (!groupSnap.exists) continue;
      const groupData = groupSnap.data();
      const memberIds = groupData.memberIds || [];
      // Lọc bỏ employerId ra khỏi danh sách member, nếu chỉ có employer thì tức là không có UV
      const candidates = memberIds.filter(id => id !== employerId);
      if (candidates.length === 0) continue; // Không có ứng viên nào -> không giải ngân

      // Đảm bảo không tạo trùng lặp
      const noticesSnap = await db
        .collection('disbursementNotices')
        .where('jobId', '==', doc.id)
        .get();
      if (!noticesSnap.empty) continue;

      const amount = Number(job.salary || 0);
      const titleText = (job.title || 'Công việc').toString();
      
      const workDate = job.endDate 
        ? new Date(job.endDate.toDate().getTime() + 7 * 60 * 60 * 1000).toISOString().split('T')[0]
        : new Date().toISOString().split('T')[0];

      await db.collection('disbursementNotices').add({
        jobId: doc.id,
        groupId: groupId,
        employerId: employerId,
        workDate: workDate,
        amount: amount,
        jobTitle: titleText,
        status: 'pending_admin',
        employerAck: false,
        adminAck: false,
        createdAt: FieldValue.serverTimestamp(),
        isAutoRequested: true,
      });

      await notifyEmployerFromFunction({
        employerId,
        type: 'disbursement_auto_requested',
        title: 'Tự động yêu cầu giải ngân',
        body: `Công việc "${titleText}" đã kết thúc quá 3 giờ. Hệ thống đã tự động gửi yêu cầu giải ngân đến Admin.`,
        data: {
          jobId: doc.id,
        },
      });

      createdCount += 1;
    }

    console.log(`Auto disbursement requests created: ${createdCount}`);
  },
);
