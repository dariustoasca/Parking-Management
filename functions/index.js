/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions/v2");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();

// Set global options for v2 functions
setGlobalOptions({maxInstances: 10, region: "europe-central2"});

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
        .document("SystemSettings").set({
          lightsOn: isNight,
          lastUpdated: new Date(), // Use JS Date or FieldValue
        }, {merge: true});

    logger.info(`Parking lights turned ${isNight ? "ON" : "OFF"}`);
  } catch (error) {
    logger.error("Error toggling parking lights", error);
  }
});

/**
 * Automatically closes the barrier after 5 seconds.
 */
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");

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
        await event.data.after.ref.update({isOpen: false});
        logger.info(`Barrier ${event.params.barrierId} closed automatically.`);
      }
    },
);

/**
 * HTTP function to seed the database with parking spots.
 * Run this once to populate the ParkingSpots collection.
 */
const {onRequest} = require("firebase-functions/v2/https");

exports.seedParkingSpots = onRequest(
    {
      region: "europe-central2",
    },
    async (request, response) => {
      const db = getFirestore("parking");
      const batch = db.batch();
      const sections = ["A", "B"];
      const spotsPerSection = 10;

      try {
        for (const section of sections) {
          for (let i = 1; i <= spotsPerSection; i++) {
            const spotId = `${section}${i}`;
            const spotRef = db.collection("ParkingSpots").document(spotId);
            batch.set(spotRef, {
              number: i,
              section: section,
              occupied: false,
              assignedUserId: null,
            }, {merge: true});
          }
        }

        await batch.commit();
        response.send("Database seeded successfully with parking spots.");
      } catch (error) {
        logger.error("Error seeding database", error);
        response.status(500).send("Error seeding database: " + error.message);
      }
    },
);
