/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const {
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");

initializeApp();

// Set global options for v2 functions
setGlobalOptions({ maxInstances: 10, region: "europe-central2" });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

/**
 * Checks the time and toggles parking lights.
 * Runs every hour.
 */
exports.toggleParkingLights = onSchedule({
  schedule: "every 1 hours",
  region: "europe-central2",
}, async (event) => {
  const now = new Date();
  const hour = now.getHours();

  // Assume night is between 18:00 (6 PM) and 06:00 (6 AM)
  const isNight = hour >= 18 || hour < 6;

  logger.info(`Checking time: ${hour}:00. Is Night? ${isNight}`);

  try {
    // Update Firestore with the new state
    // The physical system can listen to this document
    const db = getFirestore("parking");
    await db.collection("Parking")
      .doc("SystemSettings").set({
        lightsOn: isNight,
        lastUpdated: new Date(), // Use JS Date or FieldValue
      }, { merge: true });

    logger.info(`Parking lights turned ${isNight ? "ON" : "OFF"}`);
  } catch (error) {
    logger.error("Error toggling parking lights", error);
  }
});

/**
 * Automatically closes the barrier after 5 seconds.
 */
exports.autoCloseBarrier = onDocumentUpdated(
  {
    document: "Barrier/{barrierId}",
    database: "parking",
    region: "europe-central2",
  },
  async (event) => {
    const newValue = event.data.after.data();
    const previousValue = event.data.before.data();

    // Only trigger if it changed from closed to open
    if (newValue.isOpen === true && previousValue.isOpen === false) {
      logger.info(
        `Barrier ${event.params.barrierId} opened. Closing in 5s.`,
      );

      // Wait 5 seconds
      await new Promise((resolve) => setTimeout(resolve, 5000));

      // Close the barrier
      await event.data.after.ref.update({ isOpen: false });
      logger.info(`Barrier ${event.params.barrierId} closed automatically.`);
    }
  },
);

/**
 * HTTP function to seed the database with parking spots.
 * Deletes all existing spots and creates exactly 5 new ones.
 */
exports.seedParkingSpots = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");

    try {
      // First, delete all existing parking spots
      const existingSpots = await db.collection("ParkingSpots").get();
      const deleteBatch = db.batch();
      existingSpots.docs.forEach((doc) => {
        deleteBatch.delete(doc.ref);
      });
      await deleteBatch.commit();
      logger.info(`Deleted ${existingSpots.docs.length} existing parking spots`);

      // Now create exactly 5 new spots
      const createBatch = db.batch();
      for (let i = 1; i <= 5; i++) {
        const spotId = `spot${i}`;
        const spotRef = db.collection("ParkingSpots").doc(spotId);
        createBatch.set(spotRef, {
          number: i,
          occupied: false,
          assignedUserId: null,
        });
      }

      await createBatch.commit();
      response.send("Database seeded successfully with 5 parking spots (spot1-spot5).");
    } catch (error) {
      logger.error("Error seeding database", error);
      response.status(500).send("Error seeding database: " + error.message);
    }
  },
);

/**
 * HTTP function to seed the database with parking tickets.
 * Run this once to populate the ParkingTickets collection.
 */
exports.seedTickets = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");
    const batch = db.batch();

    // Use a fixed user ID for testing or get from request query
    const userId = request.query.userId || "testUser123";

    const tickets = [
      {
        id: "TKT-2025-001",
        userId: userId,
        spotId: "spot1",
        startTime: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
        endTime: null,
        status: "active",
        amount: 5.0,
        qrCodeData: "TKT-2025-001-QR",
      },
      {
        id: "TKT-2024-892",
        userId: userId,
        spotId: "spot2",
        startTime: new Date("2024-12-01T10:00:00"),
        endTime: new Date("2024-12-01T14:30:00"),
        status: "paid",
        amount: 12.5,
        qrCodeData: "TKT-2024-892-QR",
      },
      {
        id: "TKT-2024-855",
        userId: userId,
        spotId: "spot3",
        startTime: new Date("2024-11-28T09:00:00"),
        endTime: new Date("2024-11-28T10:45:00"),
        status: "paid",
        amount: 4.0,
        qrCodeData: "TKT-2024-855-QR",
      },
    ];

    try {
      for (const ticket of tickets) {
        const ticketRef = db.collection("ParkingTickets").doc(ticket.id);
        batch.set(ticketRef, ticket, { merge: true });
      }

      await batch.commit();
      response.send(
        `Database seeded successfully with tickets for user ${userId}.`,
      );
    } catch (error) {
      logger.error("Error seeding tickets", error);
      response.status(500).send("Error seeding tickets: " + error.message);
    }
  },
);

/**
 * Triggers when a ParkingTicket is created or updated.
 * Updates the corresponding ParkingSpot's occupied status.
 */
exports.manageParkingSpotOnTicket = onDocumentWritten(
  {
    document: "ParkingTickets/{ticketId}",
    database: "parking",
    region: "europe-central2",
  },
  async (event) => {
    const db = getFirestore("parking");
    const snapshot = event.data;

    if (!snapshot) {
      return; // No data
    }

    const newData = snapshot.after.data();
    const oldData = snapshot.before.data();

    // Handle deletion
    if (!newData) {
      // Ticket deleted, maybe free the spot?
      // For now, let's assume we only care about active/paid transitions
      return;
    }

    const spotId = newData.spotId;
    if (!spotId) return;

    const spotRef = db.collection("ParkingSpots").doc(spotId);

    // If ticket is newly created as active OR status changed to active
    if (newData.status === "active" &&
      (!oldData || oldData.status !== "active")) {
      await spotRef.update({
        occupied: true,
        assignedUserId: newData.userId,
      });
      logger.info(
        `Spot ${spotId} marked as occupied for user ${newData.userId}`,
      );
    } else if (
      ["paid", "completed"].includes(newData.status) &&
      (!oldData || !["paid", "completed"].includes(oldData.status))
    ) {
      // If ticket status changed to paid or completed
      await spotRef.update({
        occupied: false,
        assignedUserId: null,
      });
      logger.info(`Spot ${spotId} marked as free (ticket ${newData.status})`);
    }
  },
);

/**
 * Callable function to save a payment card securely.
 */
exports.savePaymentCard = onCall(
  {
    region: "europe-central2",
  },
  async (request) => {
    // Check authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
      );
    }

    const userId = request.auth.uid;
    const data = request.data;

    // Basic validation
    if (!data.cardNumber || data.cardNumber.length !== 16) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid card number length.",
      );
    }
    if (!data.expirationDate || !data.cvv) {
      throw new HttpsError(
        "invalid-argument",
        "Missing card details.",
      );
    }

    const db = getFirestore("parking");

    try {
      // Save to Users/{userId}/CreditCardDetails
      const cardRef = await db.collection("Users").doc(userId)
        .collection("CreditCardDetails").add({
          userId: userId,
          last4Digits: data.cardNumber.slice(-4),
          cardType: data.cardType || "Unknown",
          cardHolderName: data.cardHolderName || "",
          expiryMonth: data.expiryMonth,
          expiryYear: data.expiryYear,
          isDefault: data.isDefault || false,
          createdAt: FieldValue.serverTimestamp(),
        });

      logger.info(`Card saved for user ${userId} with ID ${cardRef.id}`);
      return { success: true, cardId: cardRef.id };
    } catch (error) {
      logger.error("Error saving payment card", error);
      throw new HttpsError("internal", "Unable to save card.");
    }
  },
);

// ============================================
// BARRIER ENTRY/EXIT SYSTEM
// ============================================

/**
 * Helper function to generate a unique ticket ID.
 * Format: TKT-{YEAR}-{3 random digits}
 * @param {FirebaseFirestore.Firestore} db - Firestore database instance
 * @return {Promise<string>} Unique ticket ID
 */
async function generateUniqueTicketId(db) {
  const year = new Date().getFullYear();
  let ticketId;
  let isUnique = false;
  let attempts = 0;

  while (!isUnique && attempts < 10) {
    const randomNum = Math.floor(Math.random() * 900) + 100; // 100-999
    ticketId = `TKT-${year}-${randomNum}`;

    // Check if this ID already exists
    const existing = await db.collection("ParkingTickets").doc(ticketId).get();
    if (!existing.exists) {
      isUnique = true;
    }
    attempts++;
  }

  if (!isUnique) {
    // Fallback: use timestamp
    ticketId = `TKT-${year}-${Date.now().toString().slice(-6)}`;
  }

  return ticketId;
}

/**
 * Callable function for user to request parking entry.
 * Registers the user as pending entry (1 minute timeout).
 */
exports.requestParkingEntry = onCall(
  {
    region: "europe-central2",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be authenticated to request entry.",
      );
    }

    const userId = request.auth.uid;
    const db = getFirestore("parking");

    try {
      // Check if user already has an active ticket
      const activeTickets = await db.collection("ParkingTickets")
        .where("userId", "==", userId)
        .where("status", "==", "active")
        .limit(1)
        .get();

      if (!activeTickets.empty) {
        throw new HttpsError(
          "failed-precondition",
          "You already have an active parking ticket.",
        );
      }

      // Check if there are available spots
      const availableSpots = await db.collection("ParkingSpots")
        .where("occupied", "==", false)
        .limit(1)
        .get();

      if (availableSpots.empty) {
        throw new HttpsError(
          "failed-precondition",
          "No parking spots available.",
        );
      }

      // Register pending entry
      await db.collection("PendingEntry").doc("current").set({
        pendingUserId: userId,
        requestedAt: FieldValue.serverTimestamp(),
      });

      logger.info(`User ${userId} registered for parking entry`);
      return { success: true, message: "Waiting for barrier button..." };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Error requesting parking entry", error);
      throw new HttpsError("internal", "Failed to request entry.");
    }
  },
);

/**
 * HTTP function called by Raspberry Pi when ENTER button is pressed.
 * Opens enter barrier and creates ticket with pending spot assignment.
 * Spot will be assigned later when sensor detects occupation.
 */
exports.confirmParkingEntry = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");

    try {
      // Get pending entry
      const pendingDoc = await db.collection("PendingEntry").doc("current").get();

      if (!pendingDoc.exists) {
        response.status(400).json({
          success: false,
          message: "No pending entry request.",
        });
        return;
      }

      const pendingData = pendingDoc.data();
      const requestedAt = pendingData.requestedAt ? pendingData.requestedAt.toDate() : null;

      // Check if within 1 minute
      if (!requestedAt) {
        response.status(400).json({
          success: false,
          message: "Invalid pending entry data.",
        });
        return;
      }

      const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
      if (requestedAt < oneMinuteAgo) {
        // Expired - delete pending entry
        await db.collection("PendingEntry").doc("current").delete();
        response.status(400).json({
          success: false,
          message: "Entry request expired (1 minute timeout).",
        });
        return;
      }

      const userId = pendingData.pendingUserId;

      // Generate unique ticket ID
      const ticketId = await generateUniqueTicketId(db);

      // Create ticket with pending spot (will be assigned by sensor)
      await db.collection("ParkingTickets").doc(ticketId).set({
        userId: userId,
        spotId: "pending",
        startTime: FieldValue.serverTimestamp(),
        endTime: null,
        status: "active",
        amount: 0,
        qrCodeData: `${ticketId}-QR`,
      });

      // Open enter barrier
      await db.collection("Barrier").doc("enterBarrier").update({
        isOpen: true,
      });

      // Delete pending entry
      await db.collection("PendingEntry").doc("current").delete();

      logger.info(`Entry confirmed for user ${userId}, ticket ${ticketId}, awaiting spot assignment`);
      response.json({
        success: true,
        ticketId: ticketId,
        spotId: "pending",
        message: "Barrier opened, ticket created. Awaiting spot assignment from sensor.",
      });
    } catch (error) {
      logger.error("Error confirming parking entry", error);
      response.status(500).json({
        success: false,
        message: "Internal error: " + error.message,
      });
    }
  },
);

/**
 * HTTP function called by Raspberry Pi when a parking spot sensor detects occupation.
 * Assigns the spot to the most recent pending ticket and marks the spot as occupied.
 *
 * @param {string} spotId - Query parameter: the spot ID (e.g., "spot1", "spot11", "1", etc.)
 */
exports.assignParkingSpot = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");
    let spotId = request.query.spotId || request.body.spotId ||
      request.query.spotNumber || request.body.spotNumber;

    if (!spotId) {
      response.status(400).json({
        success: false,
        message: "Missing spotId or spotNumber parameter.",
      });
      return;
    }

    // If just a number is passed, prepend "spot"
    if (!spotId.startsWith("spot")) {
      spotId = `spot${spotId}`;
    }

    try {
      // Verify spot exists
      const spotDoc = await db.collection("ParkingSpots").doc(spotId).get();
      if (!spotDoc.exists) {
        response.status(400).json({
          success: false,
          message: `Spot ${spotId} does not exist.`,
        });
        return;
      }

      // Find tickets with pending spot assignment (simple query, no index needed)
      const pendingTickets = await db.collection("ParkingTickets")
        .where("spotId", "==", "pending")
        .get();

      if (pendingTickets.empty) {
        response.status(400).json({
          success: false,
          message: "No pending ticket awaiting spot assignment.",
        });
        return;
      }

      // Get the most recent one by checking startTime manually
      let latestTicket = null;
      let latestTime = null;
      pendingTickets.docs.forEach((doc) => {
        const data = doc.data();
        const startTime = data.startTime ? data.startTime.toDate() : null;
        if (!latestTime || (startTime && startTime > latestTime)) {
          latestTime = startTime;
          latestTicket = { id: doc.id, data: data };
        }
      });

      if (!latestTicket) {
        response.status(400).json({
          success: false,
          message: "No valid pending ticket found.",
        });
        return;
      }

      const ticketId = latestTicket.id;
      const userId = latestTicket.data.userId;

      // Update ticket with the actual spot
      await db.collection("ParkingTickets").doc(ticketId).update({
        spotId: spotId,
      });

      // Mark spot as occupied
      await db.collection("ParkingSpots").doc(spotId).update({
        occupied: true,
        assignedUserId: userId,
      });

      logger.info(`Spot ${spotId} assigned to ticket ${ticketId} for user ${userId}`);
      response.json({
        success: true,
        ticketId: ticketId,
        spotId: spotId,
        message: `Spot ${spotId} assigned to ticket ${ticketId}.`,
      });
    } catch (error) {
      logger.error("Error assigning parking spot", error);
      response.status(500).json({
        success: false,
        message: "Internal error: " + error.message,
      });
    }
  },
);

/**
 * Callable function for user to request parking exit.
 * Registers the user as pending exit (1 minute timeout).
 */
exports.requestParkingExit = onCall(
  {
    region: "europe-central2",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be authenticated to request exit.",
      );
    }

    const userId = request.auth.uid;
    const db = getFirestore("parking");

    try {
      // Find the user's paid ticket (ready to exit)
      const paidTickets = await db.collection("ParkingTickets")
        .where("userId", "==", userId)
        .where("status", "==", "paid")
        .limit(1)
        .get();

      if (paidTickets.empty) {
        throw new HttpsError(
          "failed-precondition",
          "No paid ticket found. Please pay your ticket first.",
        );
      }

      const ticketDoc = paidTickets.docs[0];

      // Register pending exit
      await db.collection("PendingExit").doc("current").set({
        pendingUserId: userId,
        ticketId: ticketDoc.id,
        requestedAt: FieldValue.serverTimestamp(),
      });

      logger.info(`User ${userId} registered for parking exit`);
      return { success: true, message: "Waiting for barrier button..." };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Error requesting parking exit", error);
      throw new HttpsError("internal", "Failed to request exit.");
    }
  },
);

/**
 * HTTP function called by Raspberry Pi when EXIT button is pressed.
 * Opens exit barrier if pending exit exists.
 */
exports.confirmParkingExit = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");

    try {
      // Get pending exit
      const pendingDoc = await db.collection("PendingExit").doc("current").get();

      if (!pendingDoc.exists) {
        response.status(400).json({
          success: false,
          message: "No pending exit request.",
        });
        return;
      }

      const pendingData = pendingDoc.data();
      const requestedAt = pendingData.requestedAt ? pendingData.requestedAt.toDate() : null;

      // Check if within 1 minute
      if (!requestedAt) {
        response.status(400).json({
          success: false,
          message: "Invalid pending exit data.",
        });
        return;
      }

      const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
      if (requestedAt < oneMinuteAgo) {
        // Expired - delete pending exit
        await db.collection("PendingExit").doc("current").delete();
        response.status(400).json({
          success: false,
          message: "Exit request expired (1 minute timeout).",
        });
        return;
      }

      const ticketId = pendingData.ticketId;

      // Update ticket status to completed
      await db.collection("ParkingTickets").doc(ticketId).update({
        status: "completed",
        endTime: FieldValue.serverTimestamp(),
      });

      // Open exit barrier
      await db.collection("Barrier").doc("exitBarrier").update({
        isOpen: true,
      });

      // Delete pending exit
      await db.collection("PendingExit").doc("current").delete();

      logger.info(`Exit confirmed for ticket ${ticketId}`);
      response.json({
        success: true,
        ticketId: ticketId,
        message: "Exit barrier opened.",
      });
    } catch (error) {
      logger.error("Error confirming parking exit", error);
      response.status(500).json({
        success: false,
        message: "Internal error: " + error.message,
      });
    }
  },
);
