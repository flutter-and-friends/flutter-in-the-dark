# fitd25

This is the official application for the Flutter in the Dark 2025 event. It's a Flutter application designed to manage and display a live coding challenge to a live audience.

## Features

The application has two main components:

### Challenge View

This is the view for the audience and the challengers/players. It includes:

*   Display of the current challenge and the remaining time.
*   A flashy countdown overlay for when a challenge is about to start or end.
*   Display of the challenger's name.
*   A waiting message when the timer expires.

### Admin View

This is the view for the event administrators. It allows them to:

*   See a list of all challengers and their status.
*   Block and unblock challengers' screens.
*   Clear the list of challengers.

## Backend

This application uses Firebase for its backend, including:

*   **Cloud Firestore:** To store challenge data and challenger status.
*   **Firebase Authentication:** To manage admin users.

## Getting Started

To run this application, make sure you have followed the setup instructions in the root [README.md](../README.md) file.

Then, you can run the application using the following commands:

```bash
cd apps/fitd25
flutter run
```
