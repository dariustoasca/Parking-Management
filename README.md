# <img src="https://github.com/user-attachments/assets/a0d4e94b-3c4a-442d-9f7d-31bc228a3093" height="45" style="vertical-align:bottom"/> Smart Parking System

## Project Overview

This project is an Internet of Things (IoT) solution designed to modernize parking management. It replaces traditional paper tickets with a fully digital system controlled via an iOS mobile app. The system integrates a cloud backend with physical hardware to manage access, real-time spot monitoring, and payments.

The solution consists of three main components:
1.  **iOS App:** A SwiftUI application for users.
2.  **Backend:** Firebase Cloud Functions and Firestore Database for backend.
3.  **Hardware:** A physical model powered by Raspberry Pi and Arduino with sensors and servo motors.

---

## App Demos

### 1. Application Walkthrough
This covers the complete interface within the iOS app, including secure login, dashboard, navigation, and the payment process for a parking ticket.

https://github.com/user-attachments/assets/24c76141-376c-4316-acad-056197410827

### 2. Hardware & Ticket Generation Logic
This video is simulating the physical button presses. It shows how a request from the app triggers the physical barrier on the hardware model, creating a ticket in the database.

https://github.com/user-attachments/assets/43b844ab-b6d4-41ce-806e-8288803c1887

---

## System Architecture

The project's entry/exit logic is the **Two-Factor Physical Verification** system.  This prevents remote operation by requiring users to interact with the app and the physical hardware at the same time.

### The Entry Flow
The entry process is handled by the `HomeViewModel` on the client and the `requestParkingEntry` function on the cloud.

1.  **Digital Request:** The user taps **"Enter Parking"** in the app. The system checks if the user has an existing ticket or if the lot is full.
2.  **Time-Window Validation:** Upon success, the app initiates a **60s timer**.
3.  **Physical Confirmation:** The user must press the physical button on the parking gate within this timeframe.
4.  **Barrier Actuation:** The Raspberry Pi detects the button press and calls the `confirmParkingEntry` cloud function. This opens the barrier and creates a ticket with status `active`.
5.  **Spot Assignment:** As the car parks, infrared sensors connected to the Arduino detect presence. The system triggers `assignParkingSpot`, automatically linking the specific spot ID (e.g., `spot3`) to the user's ticket.

### The Exit Flow
1.  **Payment:** The user pays the calculated price via the app. The ticket status updates to `paid`.
2.  **Exit Request:** The user taps **"Open Exit Barrier"**. The system verifies payment occurred within the last 15 minutes.
3.  **Physical Confirmation:** A **60s timer** starts. The user presses the physical button at the exit.
4.  **Completion:** The barrier opens, and the ticket status updates to `completed`.

---

## Implementation Details

### iOS Application (SwiftUI)
The mobile application is built using Swift and SwiftUI 

* **`HomeView.swift`**: Is the main dashboard. It dynamically updates the UI based on the user's state (e.g., showing the "Open Barrier" button only after a ticket is paied).
* **`AuthenticationManager.swift`**: Handles user sessions. It utilises `DeviceAuthManager` to persist login states and `KeychainManager` to securely store credentials.
* **`ParkingModels.swift`**: Defines `ParkingTicket`, `Barrier`, and `ParkingSpot`.

### Cloud Backend (Node.js)
Hosted on Firebase Cloud Functions (Region: `europe-central2`), the backend manages the logic.

* **`autoCloseBarrier`**: A Firestore trigger that monitors the `Barrier` collection. If a barrier is left open, this function automatically closes it after 5 seconds.
* **`toggleParkingLights`**: A scheduled function that automatically turns the parking lot lights **ON** at 18:00 and **OFF** at 06:00.

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
* **Info:** 5x LEDs over each parking spot indicating free spots.
