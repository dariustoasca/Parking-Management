# <img src="https://github.com/user-attachments/assets/a0d4e94b-3c4a-442d-9f7d-31bc228a3093" height="40" style="vertical-align:bottom"/> Smart Parking System

## Project Overview

This project is an Internet of Things (IoT) solution designed to modernize parking management. It replaces traditional paper tickets with a fully digital system controlled via an iOS mobile app. The system integrates a cloud backend with physical hardware to manage access, real-time spot monitoring, and payments.

The solution consists of three main components:
1.  **iOS App:** A SwiftUI application for users.
2.  **Backend:** Firebase Cloud Functions and Firestore Database for backend.
3.  **Hardware:** A physical model powered by Raspberry Pi and Arduino with sensors and servo motors.

---

## App Demos

### 1. App Walkthrough
This covers the complete interface within the iOS app, including secure login, dashboard, navigation, and the payment process for a parking ticket.

https://github.com/user-attachments/assets/24c76141-376c-4316-acad-056197410827

### 2. Full Project Demo
This is a complete demo from entry of the parking to exit

https://github.com/user-attachments/assets/55dc975f-2da3-4a0e-9215-93aa5b67a352

### 3. Full Parking Case
Here is a demo if the parking is fully occupied, as shown in the demo, the open barrier button does not appear anymore

https://github.com/user-attachments/assets/02c96b7d-4b2d-4c5e-9561-5cbd3a1e8b1c

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
* **Output:** 2x Servo Motors (Barriers) and RGB LED Modules (Status Indicators).
* **Sensing:** 7x Infrared Obstacle Avoidance Sensors (one per spot and for barriers)
* **Info:** 5x LEDs over each parking spot indicating free spots.
* One Relay connected to some batteries controls the night time lighting

### Some Photos from the Development Phase
![1](https://github.com/user-attachments/assets/d96f22c5-e892-4d64-b745-6789841b0ee5)
![2](https://github.com/user-attachments/assets/7df72a3d-ca36-465e-9fac-9c27cc6f48e4)
![3](https://github.com/user-attachments/assets/1ab64a60-cf60-4575-92dd-f53e24e6708f)
![4](https://github.com/user-attachments/assets/e77b58a9-6a4d-4842-bbb2-ac315040fa8d)
![5](https://github.com/user-attachments/assets/2afa4be7-95ae-41a3-a02b-88a7175084cf)
![6](https://github.com/user-attachments/assets/4487e2e4-fb16-496d-a2ae-84f1c2ea7cc6)
![IMG_7103](https://github.com/user-attachments/assets/28cf02f8-4497-4c05-b1ac-a01e1e5d2622)
