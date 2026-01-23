class ApiConstants {
  // 1. Find your computer's IP address (e.g., 192.168.1.5)
  // 2. Replace '10.0.2.2' with that IP address below:
  static const String host = '192.168.1.76'; 
  static const String baseUrl = 'http://$host:8000/api';
  
  // MQTT settings
  static const String mqttBroker = 'broker.emqx.io';
  static const int mqttPort = 1883;
}
