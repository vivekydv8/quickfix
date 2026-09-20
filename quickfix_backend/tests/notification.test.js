const assert = require('assert');
const { Notification, setUseLocalDb } = require('../models');
const notificationService = require('../services/notificationService');

// Ensure local db mode is active for safe test execution
setUseLocalDb(true);

async function runTests() {
  console.log('--- STARTING NOTIFICATION BACKEND INTEGRATION TESTS ---');

  const customerA = { id: 'test-cust-A', role: 'customer' };
  const customerB = { id: 'test-cust-B', role: 'customer' };

  // Helper to create mock req
  const reqA = { user: customerA };
  const reqB = { user: customerB };

  // Cleanup existing test notifications
  await Notification.deleteMany({ userId: { $in: ['test-cust-A', 'test-cust-B'] } });
  await Notification.deleteMany({ id: { $regex: /^test-notif-/ } });

  // 1. Create test notifications
  console.log('1. Creating test notifications...');
  const notifA1 = await Notification.create({
    id: 'test-notif-A1',
    title: 'Booking Confirmed A1',
    body: 'Your booking has been confirmed',
    userId: customerA.id,
    isRead: false,
    readBy: [],
    deletedBy: []
  });

  const notifA2 = await Notification.create({
    id: 'test-notif-A2',
    title: 'Provider Arrived A2',
    body: 'Provider is at your doorstep',
    userId: customerA.id,
    isRead: false,
    readBy: [],
    deletedBy: []
  });

  const notifB1 = await Notification.create({
    id: 'test-notif-B1',
    title: 'Booking Confirmed B1',
    body: 'Customer B booking',
    userId: customerB.id,
    isRead: false,
    readBy: [],
    deletedBy: []
  });

  const broadcast1 = await Notification.create({
    id: 'test-notif-broadcast1',
    title: 'Festival Sale',
    body: 'Get 20% off today',
    userId: '',
    shopId: '',
    type: 'broadcast',
    isRead: false,
    readBy: [],
    deletedBy: []
  });

  // Verify initial fetch
  let notifsA = await notificationService.getNotifications(reqA);
  assert(notifsA.some(n => n.id === 'test-notif-A1'), 'Customer A should receive A1');
  assert(notifsA.some(n => n.id === 'test-notif-A2'), 'Customer A should receive A2');
  assert(notifsA.some(n => n.id === 'test-notif-broadcast1'), 'Customer A should receive broadcast1');
  assert(!notifsA.some(n => n.id === 'test-notif-B1'), 'Customer A MUST NOT receive B1');
  console.log('✅ Scenario: Fetch list isolates customer data and includes broadcasts');

  // Verify unread count
  let unreadCountA = await notificationService.getUnreadCount(reqA);
  assert.strictEqual(unreadCountA.count >= 3, true, 'Customer A should have at least 3 unread notifications');
  console.log('✅ Scenario: Unread count computed accurately');

  // 2. Mark one notification as read
  console.log('2. Testing Mark as Read...');
  const markReadRes = await notificationService.markAsRead(reqA, 'test-notif-A1');
  assert.strictEqual(markReadRes.success, true, 'markAsRead should succeed');
  assert.strictEqual(markReadRes.notification.isRead, true, 'Returned notification must have isRead: true');

  // Verify in database
  const dbDocA1 = await Notification.findOne({ id: 'test-notif-A1' });
  assert.strictEqual(dbDocA1.isRead, true, 'MongoDB document must have isRead: true');
  assert(dbDocA1.readAt != null, 'MongoDB document must have readAt timestamp');

  // Check unread count decreased
  const newUnreadA = await notificationService.getUnreadCount(reqA);
  assert.strictEqual(newUnreadA.count, unreadCountA.count - 1, 'Unread count should decrease by 1');
  console.log('✅ Scenario: Mark as Read updates database and decrements unread count');

  // 3. Mark broadcast as read for Customer A
  console.log('3. Testing Mark Broadcast as Read...');
  const markBroadcastRes = await notificationService.markAsRead(reqA, 'test-notif-broadcast1');
  assert.strictEqual(markBroadcastRes.success, true);
  assert.strictEqual(markBroadcastRes.notification.isRead, true, 'Broadcast should be read for Customer A');

  // But for Customer B, broadcast must remain unread!
  const notifsB = await notificationService.getNotifications(reqB);
  const bBroadcast = notifsB.find(n => n.id === 'test-notif-broadcast1');
  assert(bBroadcast != null, 'Customer B should see broadcast');
  assert.strictEqual(bBroadcast.isRead, false, 'Broadcast MUST remain unread for Customer B');
  console.log('✅ Scenario: Broadcast read status tracks per-customer independently');

  // 4. Test IDOR protection: Customer B cannot mark Customer A notification as read
  console.log('4. Testing IDOR Protection on Mark as Read...');
  const idorReadRes = await notificationService.markAsRead(reqB, 'test-notif-A2');
  assert.strictEqual(idorReadRes.status, 403, 'Customer B must receive 403 Forbidden when accessing Customer A notification');
  console.log('✅ Scenario: IDOR prevention on read access passes');

  // 5. Test IDOR protection: Customer B cannot delete Customer A notification
  console.log('5. Testing IDOR Protection on Delete...');
  const idorDeleteRes = await notificationService.deleteNotification(reqB, 'test-notif-A2');
  assert.strictEqual(idorDeleteRes.status, 403, 'Customer B must receive 403 Forbidden when deleting Customer A notification');
  const notifA2StillExists = await Notification.findOne({ id: 'test-notif-A2' });
  assert(notifA2StillExists != null, 'Customer A notification must not be deleted by Customer B');
  console.log('✅ Scenario: IDOR prevention on delete passes');

  // 6. Permanently delete Customer A notification
  console.log('6. Testing Permanent Deletion of customer notification...');
  const deleteResA1 = await notificationService.deleteNotification(reqA, 'test-notif-A1');
  assert.strictEqual(deleteResA1.success, true);
  assert.strictEqual(deleteResA1.id, 'test-notif-A1');

  // Verify it is completely gone from DB
  const deletedDbA1 = await Notification.findOne({ id: 'test-notif-A1' });
  assert.strictEqual(deletedDbA1, null, 'Notification record must be permanently removed from MongoDB');

  // 7. Verify subsequent API request does not return deleted notification
  console.log('7. Verifying deleted notification does not reappear...');
  notifsA = await notificationService.getNotifications(reqA);
  assert(!notifsA.some(n => n.id === 'test-notif-A1'), 'Deleted notification MUST NOT appear on refresh');
  console.log('✅ Scenario: Notification remains permanently absent after refresh');

  // 8. Delete broadcast notification for Customer A
  console.log('8. Testing Broadcast Deletion per-customer...');
  const deleteBroadcastRes = await notificationService.deleteNotification(reqA, 'test-notif-broadcast1');
  assert.strictEqual(deleteBroadcastRes.success, true);

  // Customer A must no longer see the broadcast
  notifsA = await notificationService.getNotifications(reqA);
  assert(!notifsA.some(n => n.id === 'test-notif-broadcast1'), 'Customer A must not see deleted broadcast');

  // But Customer B MUST still see the broadcast!
  const notifsBAfter = await notificationService.getNotifications(reqB);
  assert(notifsBAfter.some(n => n.id === 'test-notif-broadcast1'), 'Customer B must still have access to broadcast');
  console.log('✅ Scenario: Broadcast deleted per-customer without impacting other customers');

  // 9. Mark all as read
  console.log('9. Testing Mark All as Read...');
  const markAllRes = await notificationService.markAllAsRead(reqA);
  assert.strictEqual(markAllRes.success, true);
  notifsA = await notificationService.getNotifications(reqA);
  for (const n of notifsA) {
    assert.strictEqual(n.isRead, true, `All customer notifications must be marked read (failed on ${n.id})`);
  }
  const zeroUnread = await notificationService.getUnreadCount(reqA);
  assert.strictEqual(zeroUnread.count, 0, 'Unread count must be 0 after mark all read');
  console.log('✅ Scenario: Mark all as read completes with 0 unread count');

  // 10. Delete all notifications for Customer A
  console.log('10. Testing Delete All Notifications...');
  const deleteAllRes = await notificationService.deleteAllNotifications(reqA);
  assert.strictEqual(deleteAllRes.success, true);
  notifsA = await notificationService.getNotifications(reqA);
  assert.strictEqual(notifsA.length, 0, 'Customer A notification list must be completely empty');
  console.log('✅ Scenario: Delete all results in empty notification list');

  // Customer B's notification must still be intact
  const notifsBFinal = await notificationService.getNotifications(reqB);
  assert(notifsBFinal.some(n => n.id === 'test-notif-B1'), 'Customer B notification was not affected');

  // Clean up
  await Notification.deleteMany({ userId: { $in: ['test-cust-A', 'test-cust-B'] } });
  await Notification.deleteMany({ id: { $regex: /^test-notif-/ } });

  console.log('--- ALL BACKEND NOTIFICATION TESTS PASSED SUCCESSFULLY! ---');
}

runTests().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
