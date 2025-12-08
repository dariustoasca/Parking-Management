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
 * Run this once to populate the ParkingSpots collection.
 */
exports.seedParkingSpots = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");
    const batch = db.batch();

    try {
      // Column 1: spot11 to spot15
      for (let i = 1; i <= 5; i++) {
        const spotId = `spot1${i}`;
        const spotRef = db.collection("ParkingSpots").doc(spotId);
        batch.set(spotRef, {
          number: i,
          section: "1",
          occupied: false,
          assignedUserId: null,
        }, { merge: true });
      }

      // Column 2: spot21 to spot25
      for (let i = 1; i <= 5; i++) {
        const spotId = `spot2${i}`;
        const spotRef = db.collection("ParkingSpots").doc(spotId);
        batch.set(spotRef, {
          number: i,
          section: "2",
          occupied: false,
          assignedUserId: null,
        }, { merge: true });
      }

      await batch.commit();
      response.send("Database seeded successfully with 10 parking spots.");
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
        spotId: "spot11",
        startTime: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
        endTime: null,
        status: "active",
        amount: 5.0,
        qrCodeData: "TKT-2025-001-QR",
      },
      {
        id: "TKT-2024-892",
        userId: userId,
        spotId: "spot23",
        startTime: new Date("2024-12-01T10:00:00"),
        endTime: new Date("2024-12-01T14:30:00"),
        status: "paid",
        amount: 12.5,
        qrCodeData: "TKT-2024-892-QR",
      },
      {
        id: "TKT-2024-855",
        userId: userId,
        spotId: "spot15",
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
