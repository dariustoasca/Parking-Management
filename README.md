# <img src="https://github.com/user-attachments/assets/a0d4e94b-3c4a-442d-9f7d-31bc228a3093" height="45" style="vertical-align:bottom"/> Smart Parking System

## Project Overview

This project is a comprehensive Internet of Things (IoT) solution designed to modernize parking management. It replaces traditional paper tickets with a fully digital system controlled via an iOS mobile application. The system integrates a cloud backend with physical hardware to manage access control, real-time spot monitoring, and payment processing.

The solution consists of three main components:
1.  **iOS Client:** A SwiftUI application for user interaction.
2.  **Backend:** Firebase Cloud Functions and Firestore Database for logic and storage.
3.  **Hardware:** A physical model powered by Raspberry Pi and Arduino with sensors and servo motors.

---

## App Demos

### 1. Application Walkthrough
This demonstration covers the complete user journey within the iOS app, including secure login, dashboard navigation, and the payment process for a parking session.

https://github.com/user-attachments/assets/24c76141-376c-4316-acad-056197410827

### 2. Hardware & Ticket Generation Logic
This video illustrates the "Hybrid" verification flow. It shows how a digital request from the app triggers the physical barrier on the hardware model, creating a synchronized ticket in the database.

https://github.com/user-attachments/assets/43b844ab-b6d4-41ce-806e-8288803c1887

---

## System Architecture & Logic

The core innovation of this project is the **Two-Factor Physical Verification** system. To prevent remote operation, the user must interact with the app *and* the physical hardware simultaneously.

### The Entry Flow
The entry process is handled by the `HomeViewModel` on the client and the `requestParkingEntry` function on the cloud.

1.  **Digital Request:** The user taps **"Enter Parking"** in the app. The system checks if the user has an existing ticket or if the lot is full.
2.  **Time-Window Validation:** Upon success, the app initiates a **60-second countdown timer**.
3.  **Physical Confirmation:** The user must press the physical **Green Button** on the parking gate within this window.
4.  **Barrier Actuation:** The Raspberry Pi detects the button press and calls the `confirmParkingEntry` cloud function. This opens the barrier and creates a ticket with status `active`.
5.  **Spot Assignment:** As the car parks, infrared sensors connected to the Arduino detect presence. The system triggers `assignParkingSpot`, automatically linking the specific spot ID (e.g., `spot3`) to the user's ticket.

### The Exit Flow
1.  **Payment:** The user pays the accumulated fee via the app. The ticket status updates to `paid`.
2.  **Digital Request:** The user taps **"Open Exit Barrier"**. The system verifies payment occurred within the last 15 minutes.
3.  **Physical Confirmation:** A **60-second timer** starts. The user presses the physical **Red Button** at the exit.
4.  **Completion:** The barrier opens, and the ticket status updates to `completed`.

---

## Technical Implementation Details

### iOS Application (SwiftUI)
The mobile application is built using the MVVM design pattern for clean separation of logic and UI.

* **`HomeView.swift`**: Serves as the main dashboard. It dynamically updates the UI based on the user's state (e.g., showing the "Pay" button only when a ticket is active).
* **`AuthenticationManager.swift`**: Handles user sessions. It utilizes `DeviceAuthManager` to persist login states and `KeychainManager` to securely store credentials.
* **`ParkingModels.swift`**: Defines the data structures for `ParkingTicket`, `Barrier`, and `ParkingSpot`, ensuring type safety across the application.

### Cloud Backend (Node.js)
Hosted on Firebase Cloud Functions (Region: `europe-central2`), the backend manages the business logic.

* **`autoCloseBarrier`**: A Firestore trigger that monitors the `Barrier` collection. If a barrier is left open, this function automatically closes it after 5 seconds to enforce safety.
* **`toggleParkingLights`**: A scheduled function (Cron job) that automatically turns the parking lot lights **ON** at 18:00 and **OFF** at 06:00.

### Pricing Algorithm
Costs are calculated dynamically on the client side using the `ParkingPriceCalculator` utility. The tariff structure is as follows:

| Duration | Cost (RON) |
| :--- | :--- |
| **0 - 30 mins** | 6 Lei |
| **30 mins - 1 hour** | 10 Lei |
| **1 - 2 hours** | 18 Lei |
| **2 - 24 hours** | 50 Lei |
| **Over 24 hours** | 50 Lei / day |

---

## Hardware Configuration

The physical prototype simulates a 5-spot parking lot.

* **Computing:** Raspberry Pi 4 (Main Controller) and Arduino Uno (Sensor Hub).
* **Input:** 2x Push Buttons (Entry/Exit confirmation).
* **Output:** 2x Servo Motors (Barriers) and RGB LED Modules (Status Indicators).
* **Sensing:** 5x Infrared Obstacle Avoidance Sensors (one per spot).
* **Info:** 5x LEDs over each parking spot indicatin free spots.
