# Flutter MQTT Background Service Implementation

This project now includes a self-hosted push notification system using MQTT and a background service (Android only support for full background).

## Features
- **Background Service**: Runs continuously in the background using `flutter_background_service`.
- **MQTT Connectivity**: Connects to an MQTT broker to listen for messages.
- **Local Notifications**: Displays a system notification when a message is received.

## Setup & Configuration

### 1. MQTT Broker
The current implementation uses a public test broker: `broker.emqx.io`.
To use your own broker (e.g., Mosquitto, EMQX), update `lib/services/mqtt_service.dart`:

```dart
final String broker = 'YOUR_BROKER_IP_OR_URL';
final int port = 1883; // Check your broker port
final String topic = 'test/topic'; // Change as needed
```

### 2. Testing
1. Run the app on an Android device (Physical device recommended for background services).
   ```bash
   flutter run
   ```
2. Accept the notification permission request.
3. Close the app (or put it in background).
4. Send an MQTT message to the topic `test/topic`.
   - You can use an MQTT client on your PC (like MQTT Explorer) or command line:
     ```bash
     # Example using mosquitto_pub
     mosquitto_pub -h broker.emqx.io -t "test/topic" -m "Hello from Background!"
     ```
5. You should see a notification on your device.

## Important Notes
- **iOS**: Background execution is strictly limited on iOS. This implementation mainly targets Android for "Self-Hosted Push". iOS typically requires APNs for reliable push notifications.
- **Battery Optimization**: Some Android manufacturers aggressively kill background services. You may need to disable battery optimization for this app in system settings.
