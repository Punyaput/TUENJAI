// --- Firebase Cloud Functions (v2) ---
import { onDocumentUpdated, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

// --- Firebase Admin Modular Imports ---
import { initializeApp } from "firebase-admin/app";
import {
  getFirestore,
  FieldPath,
  Timestamp,
  DocumentSnapshot,
} from "firebase-admin/firestore";
import { getMessaging, MulticastMessage } from "firebase-admin/messaging";

// --- Initialize Admin SDK ---
initializeApp();
const db = getFirestore();
const messaging = getMessaging(); // Messaging instance

// --- Helper: send multicast notification ---
async function sendMulticast(message: MulticastMessage) {
  try {
    // Use sendEachForMulticast to get individual results
    const response = await messaging.sendEachForMulticast(message);
    logger.log(`sendMulticast: Success count: ${response.successCount}, Failure count: ${response.failureCount}`);

    // --- ADDED: Log detailed errors for failures ---
    if (response.failureCount > 0) {
      const failedTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(message.tokens[idx]);
          // Log the specific error for each failure
          logger.error(
            `sendMulticast: Failed to send to token ${idx}:`,
            resp.error // This contains the actual error code and message
          );
        }
      });
      // Optionally, you could try removing failedTokens from Firestore here
    }
    // --- END ADDED BLOCK ---

    return response; // Return the full response object
  } catch (err) {
    logger.error("sendMulticast general error:", err);
    throw err; // Re-throw to indicate function failure if needed
  }
}

/**
 * Trigger when a group document is updated (detect new pending member)
 */
export const onNewPendingMember = onDocumentUpdated(
  "groups/{groupId}",
  async (event) => {
    const beforeSnapshot = event.data?.before;
    const afterSnapshot = event.data?.after;
    if (!beforeSnapshot?.exists || !afterSnapshot?.exists) return;

    const beforeData = beforeSnapshot.data();
    const afterData = afterSnapshot.data();
    if (!beforeData || !afterData) return;

    const beforePending: string[] = beforeData.pendingRequests ?? [];
    const afterPending: string[] = afterData.pendingRequests ?? [];

    if (afterPending.length <= beforePending.length) return;

    const newMemberId = afterPending.find((id) => !beforePending.includes(id));
    if (!newMemberId) return;

    const groupId = event.params.groupId;
    const groupName = afterData.groupName || "your group";

    try {
      const userDoc = await db.collection("users").doc(newMemberId).get();
      if (!userDoc.exists) return;
      const requestorName = userDoc.data()?.username || "Someone";

      const memberIds: string[] = afterData.members ?? [];
      if (memberIds.length === 0) return;

      const caretakersSnap = await db
        .collection("users")
        .where(FieldPath.documentId(), "in", memberIds)
        .where("role", "==", "caretaker")
        .get();
      if (caretakersSnap.empty) return;

      const allTokens: string[] = [];
      caretakersSnap.docs.forEach((doc) => {
        const tokens: string[] = doc.data().fcmTokens ?? [];
        tokens.forEach((t) => {
          if (typeof t === "string" && t.trim().length > 0) allTokens.push(t);
        });
      });
      if (allTokens.length === 0) return;

      const message: MulticastMessage = {
        tokens: allTokens,
        notification: {
          title: "🔔 TuenJai: มีคำขอใหม่",
          body: `${requestorName} ต้องการเข้าร่วมกลุ่ม ${groupName}`,
        },
        data: { groupId, screen: "group_settings_pending" },
      };

      await sendMulticast(message);
      logger.log(`onNewPendingMember: Notification sent for group ${groupId}`);
    } catch (err) {
      logger.error(`onNewPendingMember error (group ${groupId}):`, err);
    }
  }
);

/**
 * Trigger when a task document is updated (detect task completion)
 */
export const onTaskCompleted = onDocumentUpdated(
  "groups/{groupId}/tasks/{taskId}",
  async (event) => {
    const beforeSnapshot = event.data?.before;
    const afterSnapshot = event.data?.after;
    const taskId = event.params.taskId;
    const groupId = event.params.groupId;

    if (!beforeSnapshot?.exists || !afterSnapshot?.exists) return;
    const beforeData = beforeSnapshot.data();
    const afterData = afterSnapshot.data();
    if (!beforeData || !afterData) return;

    let completerId: string | undefined;
    let completedItemTitle: string | undefined;
    const taskTitle = afterData.title || "A task";

    if (
      afterData.taskType === "appointment" &&
      beforeData.status !== "completed" &&
      afterData.status === "completed"
    ) {
      completerId = afterData.completedBy;
    } else if (afterData.taskType === "habit_schedule") {
      const beforeHistory = beforeData.completionHistory ?? {};
      const afterHistory = afterData.completionHistory ?? {};
      for (const key in afterHistory) {
        if (key.endsWith("_by")) continue;
        if (afterHistory[key] === "completed" && beforeHistory[key] !== "completed") {
          completerId = afterHistory[`${key}_by`];
          const keyParts = key.split("_");
          if (keyParts.length >= 3) completedItemTitle = keyParts.slice(2).join("_");
          break;
        }
      }
    }

    if (!completerId) return;

    try {
      const userDoc = await db.collection("users").doc(completerId).get();
      const completerName = userDoc.data()?.username || "Someone";

      const groupDoc = await db.collection("groups").doc(groupId).get();
      if (!groupDoc.exists) return;
      const groupData = groupDoc.data();
      const groupName = groupData?.groupName || "your group";
      const memberIds: string[] = groupData?.members ?? [];
      if (memberIds.length === 0) return;

      const caretakersSnap = await db
        .collection("users")
        .where(FieldPath.documentId(), "in", memberIds)
        .where("role", "==", "caretaker")
        .get();

      const tokens: string[] = [];
      caretakersSnap.docs.forEach((doc) => {
        if (doc.id === completerId) return;
        const tks: string[] = doc.data().fcmTokens ?? [];
        tks.forEach((t) => {
          if (typeof t === "string" && t.trim().length > 0) tokens.push(t);
        });
      });
      if (tokens.length === 0) return;

      const message: MulticastMessage = {
        tokens,
        notification: {
          title: "✅ TuenJai: งานเสร็จสิ้น",
          body: `${completerName} ทำ ${completedItemTitle || taskTitle} (กลุ่ม ${groupName}) เสร็จแล้ว`,
        },
        data: { groupId, taskId, screen: "group_detail" },
      };

      await sendMulticast(message);
      logger.log(`onTaskCompleted: Notification sent for task ${taskId}`);
    } catch (err) {
      logger.error(`onTaskCompleted error (${taskId}):`, err);
    }
  }
);

/**
 * Scheduled function: Daily 8AM notifications
 */
export const dailyNotificationsJob = onSchedule(
  { schedule: "every day 08:00", timeZone: "Asia/Bangkok" },
  async (event) => {
    logger.log("Executing dailyNotificationsJob at:", event.scheduleTime);

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);

    const todayTs = Timestamp.fromDate(today);
    const tomorrowTs = Timestamp.fromDate(tomorrow);

    try {
      // Process countdown tasks due today/tomorrow
      const countdownsToday = await db.collectionGroup("tasks")
        .where("taskType", "==", "countdown")
        .where("taskDateTime", "==", todayTs)
        .get();

      const countdownsTomorrow = await db.collectionGroup("tasks")
        .where("taskType", "==", "countdown")
        .where("taskDateTime", "==", tomorrowTs)
        .get();

      for (const doc of countdownsToday.docs) {
        const task = doc.data();
        await notifyGroupMembers(
          task.groupId,
          `⏰ วันนี้: ${task.title || "Countdown Event"}!`,
          `กิจกรรม "${task.title}" ถึงกำหนดแล้ววันนี้`,
          { screen: "group_detail", groupId: task.groupId, taskId: doc.id }
        );
      }

      for (const doc of countdownsTomorrow.docs) {
        const task = doc.data();
        await notifyGroupMembers(
          task.groupId,
          `🗓️ พรุ่งนี้: ${task.title || "Countdown Event"}`,
          `อย่าลืม! "${task.title}" จะถึงกำหนดพรุ่งนี้`,
          { screen: "group_detail", groupId: task.groupId, taskId: doc.id }
        );
      }
    } catch (err) {
      logger.error("Error processing countdowns:", err);
    }

    // Morning summaries for carereceivers
    try {
      const receivers = await db.collection("users")
        .where("role", "==", "carereceiver")
        .get();

      for (const userDoc of receivers.docs) {
        const user = userDoc.data();
        const userId = userDoc.id;
        const username = user.username || "User";
        const groups: string[] = user.joinedGroups ?? [];
        const tokens: string[] = user.fcmTokens ?? [];
        if (groups.length === 0 || tokens.length === 0) continue;

        let appointmentCount = 0;
        let habitCount = 0;

        const apptSnap = await db.collectionGroup("tasks")
          .where("groupId", "in", groups)
          .where("assignedTo", "array-contains", userId)
          .where("taskType", "==", "appointment")
          .where("taskDateTime", ">=", todayTs)
          .where("taskDateTime", "<", tomorrowTs)
          .get();
        appointmentCount = apptSnap.size;

        const weekday = (today.getDay() === 0 ? 7 : today.getDay()).toString();
        const habitsSnap = await db.collectionGroup("tasks")
          .where("groupId", "in", groups)
          .where("assignedTo", "array-contains", userId)
          .where("taskType", "==", "habit_schedule")
          .get();
        habitsSnap.docs.forEach((doc) => {
          const schedule = doc.data().schedule ?? {};
          if (schedule[weekday]?.length > 0) habitCount += schedule[weekday].length;
        });

        if (appointmentCount > 0 || habitCount > 0) {
          let body = `สวัสดี ${username}! วันนี้คุณมี`;
          if (habitCount > 0) body += ` ${habitCount} กิจวัตร`;
          if (appointmentCount > 0 && habitCount > 0) body += ` และ`;
          if (appointmentCount > 0) body += ` ${appointmentCount} นัดหมาย`;
          body += ` ที่ต้องทำ`;

          await sendMulticast({
            tokens,
            notification: { title: "☀️ TuenJai: สรุปงานวันนี้", body },
            data: { screen: "home" },
          });

          logger.log(`Sent summary to ${username} (${userId})`);
        }
      }
    } catch (err) {
      logger.error("Error sending morning summaries:", err);
    }

    logger.log("Finished dailyNotificationsJob.");
  }
);

// --- Helper function: Notify all members of a group ---
async function notifyGroupMembers(
  groupId: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
) {
  try {
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const members: string[] = groupDoc.data()?.members ?? [];
    if (members.length === 0) return;

    const allTokens: string[] = [];
    for (let i = 0; i < members.length; i += 10) {
      const batch = members.slice(i, i + 10);
      const usersSnap = await db.collection("users")
        .where(FieldPath.documentId(), "in", batch)
        .get();
      usersSnap.docs.forEach((doc) => {
        const tokens: string[] = doc.data().fcmTokens ?? [];
        tokens.forEach((t) => {
          if (typeof t === "string" && t.trim().length > 0) allTokens.push(t);
        });
      });
    }

    if (allTokens.length === 0) return;

    await sendMulticast({ tokens: allTokens, notification: { title, body }, data });
    logger.log(`notifyGroupMembers: Sent "${title}" to ${allTokens.length} tokens (group ${groupId})`);
  } catch (err) {
    logger.error(`notifyGroupMembers error (group ${groupId}):`, err);
  }
}
/**
 * Triggers when a new task document is created.
 * Notifies assigned care receivers.
 */
export const onTaskCreated = onDocumentCreated(
  "groups/{groupId}/tasks/{taskId}",
  async (event) => {
    // Get the newly created task data
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("onTaskCreated: No data associated with the event.");
      return;
    }
    const taskData = snapshot.data();
    if (!taskData) {
      logger.log("onTaskCreated: Task data is empty.");
      return;
    }

    const taskId = event.params.taskId;
    const groupId = event.params.groupId;
    const taskTitle = taskData.title || "New Task";
    const taskType = taskData.taskType;
    const createdBy = taskData.createdBy; // User ID of the caretaker who created it
    const assignedTo: string[] = taskData.assignedTo ?? []; // Array of User IDs

    // We only need to notify assigned care receivers
    if (assignedTo.length === 0 || taskType === "countdown") {
      logger.log(`Task ${taskId} has no assignees or is a countdown, no notification needed.`);
      return;
    }

    try {
      // 1. Get the name of the Caretaker who created the task
      let creatorName = "A Caretaker";
      if (createdBy) {
        const creatorDoc = await db.collection("users").doc(createdBy).get();
        creatorName = creatorDoc.data()?.username || "A Caretaker";
      }

      // 2. Get the group name
      const groupDoc = await db.collection("groups").doc(groupId).get();
      const groupName = groupDoc.data()?.groupName || "your group";

      // 3. Get tokens for assigned users (only care receivers need this specific notification)
      //    We fetch tokens directly for the assigned users.
      if (assignedTo.length === 0) return; // Should be caught above, but safety check

      const usersSnap = await db.collection("users")
        .where(FieldPath.documentId(), "in", assignedTo)
        // Optionally filter for role 'carereceiver' if needed, though assignment implies target
        // .where("role", "==", "carereceiver")
        .get();

      const tokens: string[] = [];
      usersSnap.docs.forEach((doc) => {
        const tks: string[] = doc.data().fcmTokens ?? [];
        tks.forEach((t) => {
          if (typeof t === "string" && t.trim().length > 0) tokens.push(t);
        });
      });

      if (tokens.length === 0) {
        logger.log(`No valid tokens found for assignees of task ${taskId}.`);
        return;
      }

      // 4. Construct Notification Payload
      const notificationTitle = `🆕 TuenJai: มีงานใหม่`; // "New Task"
      const notificationBody = `${creatorName} มอบหมาย "${taskTitle}" ให้คุณ (กลุ่ม ${groupName})`; // "[Creator] assigned '[Title]' to you (Group [Name])"

      const message: MulticastMessage = {
        tokens,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          groupId: groupId,
          taskId: taskId,
          screen: "group_detail", // Suggest navigating to the task's group
        },
        android: { priority: "high" as const },
        apns: {
          headers: { "apns-priority": "10" }, // High priority for new tasks
          payload: { aps: { sound: "default", badge: 1 } },
        },
      };

      // 5. Send Notifications
      await sendMulticast(message);
      logger.log(`onTaskCreated: Notification sent for new task ${taskId} to ${tokens.length} assignees.`);

    } catch (error) {
      logger.error(`onTaskCreated: Error processing task ${taskId}:`, error);
    }
  }
);
/**
 * Triggers when a task document is updated.
 * Notifies assigned care receivers if relevant details changed.
 */
export const onTaskEdited = onDocumentUpdated(
  "groups/{groupId}/tasks/{taskId}",
  async (event) => {
    const beforeSnapshot = event.data?.before;
    const afterSnapshot = event.data?.after;
    const taskId = event.params.taskId;
    const groupId = event.params.groupId;

    // Ensure snapshots and data exist
    if (!beforeSnapshot?.exists || !afterSnapshot?.exists) {
      logger.log(`onTaskEdited: Task ${taskId} snapshot missing before/after.`);
      return;
    }
    const beforeData = beforeSnapshot.data();
    const afterData = afterSnapshot.data();
    if (!beforeData || !afterData) {
      logger.log(`onTaskEdited: Task ${taskId} data missing before/after.`);
      return;
    }

    // --- Check if the update was just a completion ---
    // (Handled by onTaskCompleted, so we ignore these changes here)
    const statusChangedToCompleted = beforeData.status !== "completed" &&
      afterData.status === "completed";
    const historyChanged = JSON.stringify(beforeData.completionHistory ?? {}) !==
      JSON.stringify(afterData.completionHistory ?? {});
    // If the only change was completion status or history, exit
    if (statusChangedToCompleted ||
      (historyChanged && Object.keys(beforeData).length === Object.keys(afterData).length)) {
      logger.log(`onTaskEdited: Ignoring completion update for task ${taskId}.`);
      return;
    }


    // --- Check if relevant fields changed ---
    // Fields editable in CreateTaskScreen: title, description, taskDateTime, schedule, assignedTo
    const relevantChange =
      beforeData.title !== afterData.title ||
      beforeData.description !== afterData.description ||
      // Compare Timestamps carefully (use isEqual or toMillis)
      !beforeData.taskDateTime?.isEqual(afterData.taskDateTime) ||
      // Compare schedules (simple stringify might work for this structure)
      JSON.stringify(beforeData.schedule ?? {}) !== JSON.stringify(afterData.schedule ?? {}) ||
      // Check if assignees changed
      JSON.stringify(beforeData.assignedTo ?? []) !== JSON.stringify(afterData.assignedTo ?? []);

    if (!relevantChange) {
      logger.log(`onTaskEdited: No relevant changes detected for task ${taskId}.`);
      return;
    }

    // --- Get assignees and notify ---
    const taskTitle = afterData.title || "A task";
    const taskType = afterData.taskType;
    const assignedTo: string[] = afterData.assignedTo ?? []; // Assignees AFTER change

    // No need to notify if no one is assigned or it's a countdown
    if (assignedTo.length === 0 || taskType === "countdown") {
      logger.log(`Task ${taskId} edit has no assignees or is countdown.`);
      return;
    }

    try {
      // 1. Get Group Name
      const groupDoc: DocumentSnapshot = await db.collection("groups").doc(groupId).get();
      const groupName = groupDoc.data()?.groupName || "your group";

      // 2. Get tokens for assigned users
      const usersSnap = await db.collection("users")
        .where(FieldPath.documentId(), "in", assignedTo)
        .get();

      const tokens: string[] = [];
      usersSnap.docs.forEach((doc) => {
        const tks: string[] = doc.data().fcmTokens ?? [];
        tks.forEach((t) => {
          if (typeof t === "string" && t.trim().length > 0) tokens.push(t);
        });
      });

      if (tokens.length === 0) {
        logger.log(`No valid tokens found for assignees of edited task ${taskId}.`);
        return;
      }

      // 3. Construct Notification Payload
      const notificationTitle = `✏️ TuenJai: งานถูกแก้ไข`; // "Task Edited"
      const notificationBody = `งาน "${taskTitle}" (กลุ่ม ${groupName}) มีการเปลี่ยนแปลง กรุณาตรวจสอบ`; // "Task '[Title]' (Group [Name]) has changed. Please check."

      const message: MulticastMessage = {
        tokens,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          groupId: groupId,
          taskId: taskId,
          screen: "group_detail", // Navigate to group detail
        },
        android: { priority: "high" as const },
        apns: {
          headers: { "apns-priority": "5" }, // Normal priority for edits
          payload: { aps: { sound: "default" } },
        },
      };

      // 4. Send Notifications
      await sendMulticast(message);
      logger.log(`onTaskEdited: Notification sent for edited task ${taskId} to ${tokens.length} assignees.`);

    } catch (error) {
      logger.error(`onTaskEdited: Error processing task ${taskId}:`, error);
    }
  }
);
// --- NEW SCHEDULED FUNCTION: checkMissedTasksJob ---
// Runs every 15 minutes
export const checkMissedTasksJob = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Asia/Bangkok", // Use your local timezone
  },
  async (event) => {
    const now = new Date();
    // Define the window to check: e.g., tasks due 15-30 minutes ago
    const checkEndTime = new Date(now.getTime() - 15 * 60 * 1000); // 15 mins ago
    const checkStartTime = new Date(now.getTime() - 30 * 60 * 1000); // 30 mins ago

    const checkEndTimeTs = Timestamp.fromDate(checkEndTime);
    const checkStartTimeTs = Timestamp.fromDate(checkStartTime);

    logger.log(`checkMissedTasksJob: Checking for tasks missed between ${checkStartTime.toISOString()} and ${checkEndTime.toISOString()}`);

    try {
      // --- 1. Check Missed Appointments ---
      const missedAppointmentsSnap = await db.collectionGroup("tasks")
        .where("taskType", "==", "appointment")
        .where("status", "==", "pending") // Only check pending tasks
        .where("taskDateTime", ">=", checkStartTimeTs)
        .where("taskDateTime", "<", checkEndTimeTs)
        // Check if we already sent a missed notification for this
        .where("notifiedMissed", "!=", true) // Check for our new flag
        .get();

      for (const taskDoc of missedAppointmentsSnap.docs) {
        const taskData = taskDoc.data();
        const taskId = taskDoc.id;
        const groupId = taskData.groupId;
        const assignedTo: string[] = taskData.assignedTo ?? [];
        const taskTitle = taskData.title || "Appointment";

        if (assignedTo.length > 0 && groupId) {
          // Notify caretakers about this missed task
          await notifyCaretakersOfMissedTask(
            groupId,
            taskId,
            taskTitle,
            assignedTo, // Pass assignees to find their names
            "appointment",
          );
          // Mark as notified to prevent repeats
          await taskDoc.ref.update({ notifiedMissed: true });
        }
      }

      // --- 2. Check Missed Habit Items ---
      // This is trickier as habits don't have a single due time/status field.
      // We need to check habits that *should* have run today within the time window.
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayKey = today.toISOString().split("T")[0]; // YYYY-MM-DD format
      const todayWeekday = (today.getDay() === 0 ? 7 : today.getDay()).toString();

      // Get active habits
      const activeHabitsSnap = await db.collectionGroup("tasks")
        .where("taskType", "==", "habit_schedule")
        .where("status", "==", "active") // Ensure habit schedule itself is active
        .get();

      for (const habitDoc of activeHabitsSnap.docs) {
        const habitData = habitDoc.data();
        const schedule = habitData.schedule ?? {};
        const tasksForToday: { time: string, title: string }[] = schedule[todayWeekday] ?? [];
        const completionHistory = habitData.completionHistory ?? {};
        const assignedTo: string[] = habitData.assignedTo ?? [];
        const groupId = habitData.groupId;
        const habitTitle = habitData.title || "Habit"; // Main habit title

        if (tasksForToday.length === 0 || assignedTo.length === 0 || !groupId) continue;

        for (const subTask of tasksForToday) {
          const subTaskTimeStr = subTask.time;
          const subTaskTitle = subTask.title;
          const subTaskDueTime = parseTimeStringToDate(subTaskTimeStr, today); // Helper needed

          if (!subTaskDueTime) continue; // Skip if time format is invalid

          // Check if due time is within our check window
          if (subTaskDueTime >= checkStartTime && subTaskDueTime < checkEndTime) {
            const subTaskKey = `${todayKey}_${subTaskTimeStr}_${subTaskTitle}`;
            const missedNotifiedKey = `${subTaskKey}_notifiedMissed`;

            // Check if completed OR already notified as missed
            if (completionHistory[subTaskKey] !== "completed" &&
              completionHistory[missedNotifiedKey] !== true) {

              // This habit item was missed and not yet notified
              await notifyCaretakersOfMissedTask(
                groupId,
                habitDoc.id, // ID of the main habit document
                `${habitTitle}: ${subTaskTitle}`, // Combine titles
                assignedTo,
                "habit",
                subTaskKey, // Pass subTaskKey to update history correctly
              );
              // Mark as notified in completionHistory
              await habitDoc.ref.update({
                [`completionHistory.${missedNotifiedKey}`]: true,
              });
            }
          }
        }
      }


    } catch (error) {
      logger.error("Error checking for missed tasks:", error);
    }
    logger.log("Finished checkMissedTasksJob.");
  }
);


// --- NEW HELPER FUNCTION for notifying caretakers about missed tasks ---
async function notifyCaretakersOfMissedTask(
  groupId: string,
  taskId: string,
  taskTitle: string,
  assignedUserIds: string[],
  taskType: "appointment" | "habit",
  subTaskKey?: string, // Only for habits
): Promise<void> {
  try {
    // 1. Get Group Data (for members list)
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      logger.error(`notifyMissed: Group ${groupId} not found.`);
      return;
    }
    const groupData = groupDoc.data();
    const memberIds: string[] = groupData?.members ?? [];
    if (memberIds.length === 0) return;

    // 2. Get Names of Assigned Users (who missed the task)
    const assignedUsersSnap = await db.collection("users")
      .where(FieldPath.documentId(), "in", assignedUserIds)
      .get();
    const assignedNames = assignedUsersSnap.docs
      .map((doc) => doc.data()?.username || "Someone")
      .join(", "); // Join names if multiple assigned

    // 3. Find Caretakers (excluding assignees if they happen to be caretakers)
    const caretakersSnap = await db.collection("users")
      .where(FieldPath.documentId(), "in", memberIds)
      .where("role", "==", "caretaker")
      .get();

    const caretakerTokens: string[] = [];
    caretakersSnap.docs.forEach((doc) => {
      // Don't notify users who were assigned the task
      if (assignedUserIds.includes(doc.id)) return;

      const tokens = doc.data().fcmTokens;
      if (tokens && Array.isArray(tokens)) {
        tokens.forEach((token) => {
          if (token && typeof token === "string" && token.length > 0) {
            caretakerTokens.push(token);
          }
        });
      }
    });

    if (caretakerTokens.length === 0) {
      logger.log(`notifyMissed: No caretakers found to notify for task ${taskId}.`);
      return;
    }

    // 4. Construct Payload
    const notificationTitle = `⚠️ TuenJai: งานอาจถูกพลาด`; // "Task Might Be Missed"
    const notificationBody = `${assignedNames} อาจพลาดการทำ "${taskTitle}"`; // "[Assignee Names] might have missed '[Task Title]'"

    const message: MulticastMessage = {
      tokens: caretakerTokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        groupId: groupId,
        taskId: taskId,
        screen: "group_detail", // Navigate to group
      },
      android: { priority: "high" as const },
      apns: {
        headers: { "apns-priority": "5" },
        payload: { aps: { sound: "default" } },
      },
    };

    // 5. Send Notification
    await sendMulticast(message);
    logger.log(`notifyMissed: Sent notification for missed task ${taskId} to ${caretakerTokens.length} tokens.`);

  } catch (error) {
    logger.error(`notifyMissed: Error sending notification for task ${taskId}:`, error);
  }
}

// --- NEW HELPER FUNCTION to parse time string ---
// (Needed because Cloud Functions don't have Intl or Date parsing like Dart)
function parseTimeStringToDate(timeStr: string, baseDate: Date): Date | null {
  try {
    const parts = timeStr.split(":");
    if (parts.length !== 2) return null;
    const hour = parseInt(parts[0], 10);
    const minute = parseInt(parts[1], 10);
    if (isNaN(hour) || isNaN(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    // Create date in the correct timezone (function runs in UTC by default)
    // We assume baseDate is already correct for the target timezone (e.g., Asia/Bangkok)
    const date = new Date(baseDate);
    date.setHours(hour, minute, 0, 0); // Set hours/minutes for the baseDate
    return date;
  } catch (e) {
    logger.error(`Error parsing time string "${timeStr}":`, e);
    return null;
  }
}
// Runs every 5 minutes (adjust schedule as needed for balance between timeliness and cost)
export const checkUpcomingTasksJob = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Bangkok",
  },
  async (event) => {
    const now = new Date();
    const dueTimeWindowEnd = new Date(now.getTime() + 5 * 60 * 1000); // Tasks due in the next 5 mins
    const oneHourWindowStart = new Date(now.getTime() + 55 * 60 * 1000); // Tasks due 55 mins from now
    const oneHourWindowEnd = new Date(now.getTime() + 60 * 60 * 1000); // Tasks due 60 mins from now

    const nowTs = Timestamp.fromDate(now);
    const oneHourWindowEndTs = Timestamp.fromDate(oneHourWindowEnd);

    logger.log(`checkUpcomingTasksJob: Checking between ${now.toISOString()} and ${oneHourWindowEnd.toISOString()}`);

    try {
      // --- 1. Check Upcoming Appointments ---
      const upcomingAppointmentsSnap = await db.collectionGroup("tasks")
        .where("taskType", "==", "appointment")
        .where("status", "==", "pending")
        .where("taskDateTime", ">=", nowTs)
        .where("taskDateTime", "<", oneHourWindowEndTs)
        .get();

      for (const taskDoc of upcomingAppointmentsSnap.docs) {
        const taskData = taskDoc.data();
        const taskId = taskDoc.id;
        const groupId = taskData.groupId;
        const taskDateTime = (taskData.taskDateTime as Timestamp)?.toDate();
        const assignedTo: string[] = taskData.assignedTo ?? [];
        const taskTitle = taskData.title || "Appointment";
        const notified1Hour = taskData.notified1Hour ?? false;
        const notifiedDue = taskData.notifiedDue ?? false;

        if (!taskDateTime || assignedTo.length === 0 || !groupId) continue;

        // Check for 1-hour window (Notify Assignees)
        if (!notified1Hour && taskDateTime >= oneHourWindowStart && taskDateTime < oneHourWindowEnd) {
          await notifyAssigneesOfUpcomingTask(
            groupId, taskId, taskTitle, assignedTo, taskDateTime, "1hour"
          );
          await taskDoc.ref.update({ notified1Hour: true });
        }
        // Check for Due Time window (Notify Assignees AND Caretakers)
        else if (!notifiedDue && taskDateTime >= now && taskDateTime < dueTimeWindowEnd) {
          // Notify Assignees
          await notifyAssigneesOfUpcomingTask(
            groupId, taskId, taskTitle, assignedTo, taskDateTime, "due"
          );
          // Mark assignee notification sent
          await taskDoc.ref.update({ notifiedDue: true });

          // --- ADDED: Notify Caretakers ---
          logger.log(`Task ${taskId} is due now, notifying caretakers.`);
          await notifyCaretakersOfDueTask(
            groupId,
            taskId,
            taskTitle,
            assignedTo // Pass assignees to get names and exclude them
          );
          // --- END ADDED ---
        }
      }

      // --- 2. Check Upcoming Habit Items ---
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayKey = today.toISOString().split("T")[0]; // YYYY-MM-DD format
      const todayWeekday = (today.getDay() === 0 ? 7 : today.getDay()).toString();

      const activeHabitsSnap = await db.collectionGroup("tasks")
        .where("taskType", "==", "habit_schedule")
        .where("status", "==", "active")
        .get();

      for (const habitDoc of activeHabitsSnap.docs) {
        const habitData = habitDoc.data();
        const schedule = habitData.schedule ?? {};
        const tasksForToday: { time: string, title: string }[] = schedule[todayWeekday] ?? [];
        const completionHistory = habitData.completionHistory ?? {};
        const assignedTo: string[] = habitData.assignedTo ?? [];
        const groupId = habitData.groupId;
        const habitTitle = habitData.title || "Habit"; // Main habit title

        if (tasksForToday.length === 0 || assignedTo.length === 0 || !groupId) continue;

        for (const subTask of tasksForToday) {
          const subTaskTimeStr = subTask.time;
          const subTaskTitle = subTask.title;
          const subTaskDueTime = parseTimeStringToDate(subTaskTimeStr, today); // Helper

          if (!subTaskDueTime || subTaskDueTime < now) continue; // Skip invalid or past

          const subTaskKey = `${todayKey}_${subTaskTimeStr}_${subTaskTitle}`;
          const notified1HourKey = `${subTaskKey}_notified1Hour`;
          const notifiedDueKey = `${subTaskKey}_notifiedDue`;
          const isCompleted = completionHistory[subTaskKey] === "completed";
          const notified1Hour = completionHistory[notified1HourKey] === true;
          const notifiedDue = completionHistory[notifiedDueKey] === true;

          if (isCompleted) continue;

          const fullSubTaskTitle = `${habitTitle}: ${subTaskTitle}`;

          // Check for 1-hour window (Notify Assignees)
          if (!notified1Hour && subTaskDueTime >= oneHourWindowStart && subTaskDueTime < oneHourWindowEnd) {
            await notifyAssigneesOfUpcomingTask(
              groupId, habitDoc.id, fullSubTaskTitle, assignedTo, subTaskDueTime, "1hour", subTaskKey
            );
            await habitDoc.ref.update({ [`completionHistory.${notified1HourKey}`]: true });
          }
          // Check for Due Time window (Notify Assignees AND Caretakers)
          else if (!notifiedDue && subTaskDueTime >= now && subTaskDueTime < dueTimeWindowEnd) {
            // Notify Assignees
            await notifyAssigneesOfUpcomingTask(
              groupId, habitDoc.id, fullSubTaskTitle, assignedTo, subTaskDueTime, "due", subTaskKey
            );
            // Mark assignee notification sent
            await habitDoc.ref.update({ [`completionHistory.${notifiedDueKey}`]: true });

            // --- ADDED: Notify Caretakers ---
            logger.log(`Habit item ${subTaskKey} is due now, notifying caretakers.`);
            await notifyCaretakersOfDueTask(
              groupId,
              habitDoc.id, // Pass main habit ID
              fullSubTaskTitle,
              assignedTo // Pass assignees to get names and exclude them
            );
            // --- END ADDED ---
          }
        }
      }

    } catch (error) {
      logger.error("Error checking for upcoming tasks:", error);
    }
    logger.log("Finished checkUpcomingTasksJob.");
  }
);
// --- NEW HELPER FUNCTION for notifying caretakers about DUE tasks ---
async function notifyCaretakersOfDueTask(
  groupId: string,
  taskId: string,
  taskTitle: string,
  assignedUserIds: string[]
): Promise<void> {
  try {
    // 1. Get Group Data (for members list)
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      logger.error(`notifyDue: Group ${groupId} not found.`);
      return;
    }
    const groupData = groupDoc.data();
    const memberIds: string[] = groupData?.members ?? [];
    if (memberIds.length === 0) return;

    // 2. Get Names of Assigned Users (who the task is for)
    let assignedNames = "Someone"; // Default if no assignees somehow
    if (assignedUserIds.length > 0) {
      const assignedUsersSnap = await db.collection("users")
        .where(FieldPath.documentId(), "in", assignedUserIds)
        .get();
      assignedNames = assignedUsersSnap.docs
        .map((doc) => doc.data()?.username || "User")
        .join(", "); // Join names if multiple assigned
    }


    // 3. Find Caretakers (excluding assignees)
    const caretakersSnap = await db.collection("users")
      .where(FieldPath.documentId(), "in", memberIds)
      .where("role", "==", "caretaker")
      .get();

    const caretakerTokens: string[] = [];
    caretakersSnap.docs.forEach((doc) => {
      // Don't notify users who were assigned the task
      if (assignedUserIds.includes(doc.id)) return;

      const tokens = doc.data().fcmTokens;
      if (tokens && Array.isArray(tokens)) {
        tokens.forEach((token) => {
          if (token && typeof token === "string" && token.length > 0) {
            caretakerTokens.push(token);
          }
        });
      }
    });

    if (caretakerTokens.length === 0) {
      logger.log(`notifyDue: No caretakers (excluding assignees) found to notify for task ${taskId}.`);
      return;
    }

    // 4. Construct Payload
    const notificationTitle = `🔔 TuenJai: งานถึงกำหนด`; // "Task Due"
    const notificationBody = `งาน "${taskTitle}" สำหรับ ${assignedNames} ถึงกำหนดแล้วตอนนี้`; // "Task '[Title]' for [Assignee Names] is due now"

    const message: MulticastMessage = {
      tokens: caretakerTokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        groupId: groupId,
        taskId: taskId,
        screen: "group_detail", // Navigate to group
      },
      android: { priority: "high" as const },
      apns: {
        headers: { "apns-priority": "5" }, // Normal priority
        payload: { aps: { sound: "default" } },
      },
    };

    // 5. Send Notification
    await sendMulticast(message);
    logger.log(`notifyDue: Sent notification for due task ${taskId} to ${caretakerTokens.length} tokens.`);

  } catch (error) {
    logger.error(`notifyDue: Error sending notification for task ${taskId}:`, error);
  }
}

// --- NEW HELPER FUNCTION for notifying assignees about upcoming tasks ---
async function notifyAssigneesOfUpcomingTask(
  groupId: string,
  taskId: string,
  taskTitle: string,
  assignedUserIds: string[],
  dueTime: Date, // Pass the actual due time
  type: "1hour" | "due",
  subTaskKey?: string, // Only for habits
): Promise<void> {
  try {
    if (assignedUserIds.length === 0) return;

    // 1. Get Group Name (Optional, but good for context)
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.groupName || "your group";

    // 2. Get tokens for assigned users
    const usersSnap = await db.collection("users")
      .where(FieldPath.documentId(), "in", assignedUserIds)
      .get();

    const tokens: string[] = [];
    usersSnap.docs.forEach((doc) => {
      const tks: string[] = doc.data().fcmTokens ?? [];
      tks.forEach((t) => {
        if (typeof t === "string" && t.trim().length > 0) tokens.push(t);
      });
    });

    if (tokens.length === 0) {
      logger.log(`notifyUpcoming: No valid tokens found for assignees of task ${taskId}.`);
      return;
    }

    // 3. Construct Payload
    let notificationTitle = "";
    let notificationBody = "";
    // Format time for display (HH:MM) in Bangkok time
    const timeFormatter = new Intl.DateTimeFormat("en-US", {
      hour: "2-digit", minute: "2-digit", timeZone: "Asia/Bangkok", hour12: false,
    });
    const formattedTime = timeFormatter.format(dueTime);

    if (type === "1hour") {
      notificationTitle = `⏳ TuenJai: อีก 1 ชั่วโมง`; // "In 1 Hour"
      notificationBody = `เวลา ${formattedTime} น. - "${taskTitle}" (กลุ่ม ${groupName})`; // "At [Time] - '[Title]' (Group [Name])"
    } else { // type === "due"
      notificationTitle = `❗ TuenJai: ถึงเวลา`; // "It's Time"
      notificationBody = `"${taskTitle}" (กลุ่ม ${groupName}) - ${formattedTime} น.`; // "'[Title]' (Group [Name]) - [Time]"
    }

    // Create payload structure compatible with interactive notifications
    // Payload needs enough info for the _handleTaskCompletion function
    let taskTypeIdentifier = subTaskKey ? "habit" : "appointment";
    let payloadString = `${taskTypeIdentifier}/${groupId}/${taskId}`;
    if (subTaskKey) {
      payloadString += `/${subTaskKey}`; // Add subTaskKey for habits
    }

    const message: MulticastMessage = {
      tokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        groupId: groupId,
        taskId: taskId,
        screen: "home", // Go to home screen where task should be visible
        // Include payload needed by local notification handler IF we show this via local notif
        // 'local_payload': payloadString, // Example if needed later
      },
      // IMPORTANT: Add notification category for actions on Android/iOS
      // Using the same category as local notifications for consistency
      android: {
        priority: "high" as const,
        notification: {
          channelId: "tuenjai_tasks", // Match local channel ID
          // Add click action if needed for direct navigation (more complex setup)
          // clickAction: 'FLUTTER_NOTIFICATION_CLICK', // Standard Flutter action
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            sound: "default",
            category: "task_due_category", // Match local category ID for actions
            badge: 1,
          },
        },
      },
      // Add webpush config if supporting web later
    };


    // 4. Send Notification using sendMulticast helper
    await sendMulticast(message);
    logger.log(`notifyUpcoming: Sent "${type}" notification for task ${taskId} to ${tokens.length} tokens.`);

  } catch (error) {
    logger.error(`notifyUpcoming: Error sending notification for task ${taskId}:`, error);
  }
}