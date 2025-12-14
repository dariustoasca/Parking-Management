/*
 * Smart Parking System - Cloud Functions
 * Author: Darius Toasca
 * Course: CN Project
 *
 * This file contains all the Firebase Cloud Functions for my parking management
 * system. The functions handle everything from barrier control to ticket
 * management and payment processing.
 *
 * The system uses the "parking" Firestore database instance.
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

// Using europe-central2 region since it's closest to my location (Romania)
setGlobalOptions({ maxInstances: 10, region: "europe-central2" });


// ============================================
// PARKING LIGHTS SYSTEM
// ============================================
// This section handles automatic lighting control.
// The lights turn on at night (6 PM to 6 AM) and off during the day.
// A scheduled function runs every hour to check and update the lights.

exports.toggleParkingLights = onSchedule({
  schedule: "every 1 hours",
  region: "europe-central2",
}, async (event) => {
  const now = new Date();
  const hour = now.getHours();

  // Night time is between 18:00 and 06:00
  const isNight = hour >= 18 || hour < 6;

  logger.info(`Checking time: ${hour}:00. Is Night? ${isNight}`);

  try {
    const db = getFirestore("parking");
    await db.collection("Parking")
      .doc("SystemSettings").set({
        lightsOn: isNight,
        lastUpdated: new Date(),
      }, { merge: true });

    logger.info(`Parking lights turned ${isNight ? "ON" : "OFF"}`);
  } catch (error) {
    logger.error("Error toggling parking lights", error);
  }
});


// ============================================
// BARRIER CONTROL SYSTEM
// ============================================
// The barriers are connected to Raspberry Pi devices that communicate with
// these functions. When a barrier opens, it automatically closes after 5 seconds
// for safety reasons.

exports.autoCloseBarrier = onDocumentUpdated(
  {
    document: "Barrier/{barrierId}",
    database: "parking",
    region: "europe-central2",
  },
  async (event) => {
    const newValue = event.data.after.data();
    const previousValue = event.data.before.data();

    // Only trigger when barrier changes from closed to open
    if (newValue.isOpen === true && previousValue.isOpen === false) {
      logger.info(
        `Barrier ${event.params.barrierId} opened. Closing in 5s.`,
      );

      // Wait 5 seconds then close
      await new Promise((resolve) => setTimeout(resolve, 5000));

      await event.data.after.ref.update({ isOpen: false });
      logger.info(`Barrier ${event.params.barrierId} closed automatically.`);
    }
  },
);


// ============================================
// DATABASE SEEDING FUNCTIONS
// ============================================
// These functions are for testing and initial setup. They populate the
// database with sample data for development purposes.

// Creates exactly 5 parking spots (spot1 through spot5)
exports.seedParkingSpots = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");

    try {
      // Clear existing spots first
      const existingSpots = await db.collection("ParkingSpots").get();
      const deleteBatch = db.batch();
      existingSpots.docs.forEach((doc) => {
        deleteBatch.delete(doc.ref);
      });
      await deleteBatch.commit();
      logger.info(`Deleted ${existingSpots.docs.length} existing parking spots`);

      // Create 5 new spots
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

// Creates sample tickets for testing
exports.seedTickets = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");
    const batch = db.batch();

    const userId = request.query.userId || "testUser123";

    const tickets = [
      {
        id: "TKT-2025-001",
        userId: userId,
        spotId: "spot1",
        startTime: new Date(Date.now() - 2 * 60 * 60 * 1000),
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


// ============================================
// PARKING SPOT MANAGEMENT
// ============================================
// This trigger automatically updates parking spot availability when
// tickets are created or their status changes. It keeps the spot
// status in sync with the ticket status.

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
      return;
    }

    const newData = snapshot.after.data();
    const oldData = snapshot.before.data();

    // Handle ticket deletion
    if (!newData) {
      return;
    }

    const spotId = newData.spotId;
    if (!spotId || spotId === "pending") return;

    const spotRef = db.collection("ParkingSpots").doc(spotId);

    // Ticket is active -> mark spot as occupied
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
      // Ticket paid/completed -> free up the spot
      await spotRef.update({
        occupied: false,
        assignedUserId: null,
      });
      logger.info(`Spot ${spotId} marked as free (ticket ${newData.status})`);
    }
  },
);


// ============================================
// PAYMENT SYSTEM
// ============================================
// Handles saving credit card details securely. For the prototype,
// we're only storing the last 4 digits and card type.

exports.savePaymentCard = onCall(
  {
    region: "europe-central2",
  },
  async (request) => {
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
// ENTRY/EXIT BARRIER SYSTEM
// ============================================
// This is the main logic for handling parking entry and exit.
// The flow works like this:
// 1. User presses "Enter Parking" in the app
// 2. requestParkingEntry registers them as "pending"
// 3. User has 60 seconds to press the physical button on the Raspberry Pi
// 4. confirmParkingEntry creates the ticket and opens the barrier
// 5. Sensor detects where they parked -> assignParkingSpot updates the ticket
// 6. When leaving, similar flow with requestParkingExit and confirmParkingExit

// Helper function to generate unique ticket IDs
// Format: TKT-YEAR-XXX where XXX is a random 3-digit number
/**
 * Generates a unique ticket ID in the format TKT-YEAR-XXX
 * @param {Object} db - Firestore database instance
 * @return {Promise<string>} Unique ticket ID
 */
async function generateUniqueTicketId(db) {
  const year = new Date().getFullYear();
  let ticketId;
  let isUnique = false;
  let attempts = 0;

  while (!isUnique && attempts < 10) {
    const randomNum = Math.floor(Math.random() * 900) + 100;
    ticketId = `TKT-${year}-${randomNum}`;

    // Make sure this ID doesn't already exist
    const existing = await db.collection("ParkingTickets").doc(ticketId).get();
    if (!existing.exists) {
      isUnique = true;
    }
    attempts++;
  }

  // Fallback to timestamp if random IDs keep colliding
  if (!isUnique) {
    ticketId = `TKT-${year}-${Date.now().toString().slice(-6)}`;
  }

  return ticketId;
}

// Called from the app when user wants to enter the parking
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
      // Check if they already have an active ticket
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

      // Make sure there's at least one free spot
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

      // Register as pending - Raspberry Pi will be listening for this
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

// Called by Raspberry Pi when the physical ENTER button is pressed
// Creates the ticket and opens the entry barrier
exports.confirmParkingEntry = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");

    try {
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

      if (!requestedAt) {
        response.status(400).json({
          success: false,
          message: "Invalid pending entry data.",
        });
        return;
      }

      // Check if request is still valid (within 60 seconds)
      const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
      if (requestedAt < oneMinuteAgo) {
        await db.collection("PendingEntry").doc("current").delete();
        response.status(400).json({
          success: false,
          message: "Entry request expired (1 minute timeout).",
        });
        return;
      }

      const userId = pendingData.pendingUserId;
      const ticketId = await generateUniqueTicketId(db);

      // Create ticket - spot will be assigned when sensor detects the car
      await db.collection("ParkingTickets").doc(ticketId).set({
        userId: userId,
        spotId: "pending",
        startTime: FieldValue.serverTimestamp(),
        endTime: null,
        status: "active",
        amount: 0,
        qrCodeData: `${ticketId}-QR`,
      });

      // Open the barrier
      await db.collection("Barrier").doc("enterBarrier").update({
        isOpen: true,
      });

      // Clear the pending entry
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


// ============================================
// SENSOR-BASED SPOT ASSIGNMENT
// ============================================
// Called by Raspberry Pi when a presence sensor detects a car parked.
// The Arduino sensors send signals to the Pi, which then calls this function
// with the spot number to assign it to the waiting ticket.

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

    // Handle both "3" and "spot3" formats
    if (!spotId.startsWith("spot")) {
      spotId = `spot${spotId}`;
    }

    try {
      // Make sure the spot exists in our database
      const spotDoc = await db.collection("ParkingSpots").doc(spotId).get();
      if (!spotDoc.exists) {
        response.status(400).json({
          success: false,
          message: `Spot ${spotId} does not exist.`,
        });
        return;
      }

      // Find tickets waiting for spot assignment
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

      // Get the most recent ticket (in case there are multiple)
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

      // Update the ticket with the actual spot
      await db.collection("ParkingTickets").doc(ticketId).update({
        spotId: spotId,
      });

      // Mark the spot as occupied
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


// ============================================
// EXIT SYSTEM
// ============================================
// Similar to entry, but for leaving the parking.
// User pays their ticket in the app, then requests exit.
// They have 60 seconds to press the physical exit button.

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
      // They need to have a paid ticket to exit
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

      // Register as pending exit
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

// Called by Raspberry Pi when the physical EXIT button is pressed
exports.confirmParkingExit = onRequest(
  {
    region: "europe-central2",
  },
  async (request, response) => {
    const db = getFirestore("parking");

    try {
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

      if (!requestedAt) {
        response.status(400).json({
          success: false,
          message: "Invalid pending exit data.",
        });
        return;
      }

      // Check 60 second timeout
      const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
      if (requestedAt < oneMinuteAgo) {
        await db.collection("PendingExit").doc("current").delete();
        response.status(400).json({
          success: false,
          message: "Exit request expired (1 minute timeout).",
        });
        return;
      }

      const ticketId = pendingData.ticketId;

      // Mark ticket as completed
      await db.collection("ParkingTickets").doc(ticketId).update({
        status: "completed",
        endTime: FieldValue.serverTimestamp(),
      });

      // Open exit barrier
      await db.collection("Barrier").doc("exitBarrier").update({
        isOpen: true,
      });

      // Clear pending exit
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
