const admin = require('firebase-admin');
const serviceAccount = require('./firebase-adminsdk.json'); // Giả định admin sdk có trong thư mục nếu cần, hoặc dùng default

admin.initializeApp({
  credential: admin.credential.applicationDefault() // Nếu chạy trong môi trường có firebase CLI đã login
});

const db = admin.firestore();

async function cleanup() {
  console.log("Bắt đầu dọn dẹp các nhóm chat bị lỗi...");
  try {
    const groupsSnap = await db.collection('groupChats').get();
    let count = 0;
    
    for (const doc of groupsSnap.docs) {
      const data = doc.data();
      const status = data.status || '';
      const jobId = data.jobId;
      
      if (status !== 'closed' && jobId) {
        const jobDoc = await db.collection('jobPosts').doc(jobId).get();
        if (jobDoc.exists) {
          const jobStatus = jobDoc.data().status || '';
          if (jobStatus === 'closed' || jobStatus === 'cancelled' || jobStatus === 'rejected') {
            console.log(`Đóng nhóm ${doc.id} vì job ${jobId} đã đóng`);
            await doc.ref.update({
              status: 'closed',
              closedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            count++;
          }
        }
      }
    }
    console.log(`Đã dọn dẹp thành công ${count} nhóm chat rác.`);
  } catch (e) {
    console.error("Lỗi:", e);
  }
}

cleanup();
