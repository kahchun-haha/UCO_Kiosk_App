# ♻️ UMinyak Kiosk App
**Smart System for Collecting and Recycling Used Cooking Oil (UCO)**

UMinyak Kiosk App is a full-stack smart recycling system designed to encourage proper disposal of used cooking oil through **QR-based kiosk deposits**, **real-time monitoring**, and **automated collection task management**.

This project was developed as a **Final Year Project (FYP)** at **Universiti Malaya**, demonstrating end-to-end integration of **mobile apps, IoT hardware, cloud backend, and a web admin dashboard**.

---

## ✨ Key Features

### 👤 Public Users (Mobile App)
- Secure login using Firebase Authentication
- Generate **time-limited QR codes** for kiosk validation
- View recycling history and deposited weight
- Locate nearby kiosks and check tank capacity in real time

### 🛢️ Smart Kiosk (IoT)
- QR validation to authorize deposit session (**no physical lock**)
- Weight measurement using load cell (HX711)
- Automatic fill-level updates to Firestore
- Event-driven triggers for collection tasks

### 👷 Collection Agents (Mobile App)
- Auto-assigned collection tasks based on **zone & shift**
- Real-time task status (pending / in progress / completed)
- Upload proof photo after oil collection
- Task completion updates kiosk state

### 🖥️ Admin Dashboard (Web)
- Monitor kiosk status and fill levels
- Manage users, agents, and kiosks
- View deposits, tasks, and analytics
- Manual task reassignment (admin-only)

---

## 🏗️ System Architecture Overview

<div align="center">
  <img src="/screenshots/hta.png" width="700"/>
</div>

The system integrates:
- Flutter mobile app (users & agents)
- ESP32-based kiosk (sensors & QR scanner)
- Firebase backend (Firestore, Auth, Cloud Functions)
- React admin dashboard

---

## 🔁 Core System Flows

### 🔐 QR-Based Deposit Flow
<div align="center">
  <a href="/screenshots/flow_deposit.png">
    <img src="/screenshots/flow_deposit.png" height="360">
  </a>
  <br/>
  <sub>Click to view full-size diagram</sub>
</div>

1. User generates a time-limited QR code from the mobile app  
2. Kiosk validates the QR session (active & not expired)  
3. Kiosk enters **ready-to-deposit mode**  
4. Load cell detects oil deposit  
5. Deposit record is stored in Firestore  
6. Kiosk fill level is updated  
7. Threshold crossing triggers collection task creation  

---

### 🚚 Automated Collection Flow
<div align="center">
  <a href="/screenshots/flow_collection.png">
    <img src="/screenshots/flow_collection.png" height="360">
  </a>
  <br/>
  <sub>Click to view full-size diagram</sub>
</div>

- Collection task is automatically created when fill level crosses threshold
- Duplicate active tasks are prevented
- Task is auto-assigned to a **duty agent by zone & shift**
- Pending tasks are reassigned during shift handover (scheduled or manual)

---

## 📱 Mobile App Screens (User)

<div align="center">

<table>
<tr>
<th>Login</th>
<th>Home Dashboard</th>
<th>QR Code Session</th>
</tr>
<tr>
<td><img src="/screenshots/mobile_login.png" width="220"></td>
<td><img src="/screenshots/mobile_home.png" width="220"></td>
<td><img src="/screenshots/mobile_qr.png" width="220"></td>
</tr>
</table>

<br/>

<table>
<tr>
<th>Kiosk Status</th>
<th>Recycling History</th>
</tr>
<tr>
<td><img src="/screenshots/mobile_kiosk_status.png" width="220"></td>
<td><img src="/screenshots/mobile_history.png" width="220"></td>
</tr>
</table>

</div>

---

## 👷 Agent App Screens

<div align="center">

<table>
<tr>
<th>Task List</th>
<th>Task Detail</th>
<th>Proof Upload</th>
<th>Completed Tasks</th>
</tr>
<tr>
<td><img src="/screenshots/agent_tasks.png" width="220"></td>
<td><img src="/screenshots/agent_task_detail.png" width="220"></td>
<td><img src="/screenshots/agent_upload_proof.png" width="220"></td>
<td><img src="/screenshots/agent_completed.png" width="220"></td>
</tr>
</table>

</div>

> The task detail screen uses **state-based UI**:  
> before proof upload → after proof upload → completion enabled.

---

## 🖥️ Admin Dashboard Screens

| Feature | Screenshot |
|------|-----------|
| Dashboard Overview | ![](/screenshots/admin_dashboard.png) |
| Kiosk Management | ![](/screenshots/admin_kiosks.png) |
| Deposit Records | ![](/screenshots/admin_deposits.png) |
| Analytics | ![](/screenshots/admin_analytics.png) |

---

## 🛠️ Physical Hardware Prototype

<div align="center">
  <img src="/screenshots/hardware.png" width="550"/>
</div>

The kiosk prototype includes:
- ESP32 microcontroller
- HX711 load cell for weight measurement
- Ultrasonic sensor for tank monitoring
- OLED display for system status
- QR scanner for user validation

---

## 🧠 Firestore Data Model

<div align="center">
  <img src="/screenshots/erd_firestore.png" width="700"/>
</div>

Main collections:
- users
- kiosks
- deposits
- collectionTasks
- collectionLogs

---

## ⚙️ Technology Stack

**Frontend**
- Flutter (Dart)
- React.js (Admin Dashboard)

**Backend**
- Firebase Firestore
- Firebase Authentication
- Firebase Cloud Functions
- Firebase Cloud Scheduler
- Firebase Storage

**IoT**
- ESP32
- HX711 Load Cell
- Ultrasonic Sensor
- OLED Display

---

## 🎓 Academic Context

This project was developed as a **Final Year Project (FYP)** at **Universiti Malaya**, focusing on:
- Smart sustainability systems
- IoT–cloud integration
- Event-driven backend automation
- Real-world operational workflows
