import paho.mqtt.client as mqtt
import json
import threading

BROKER = 'broker.emqx.io'
PORT = 1883
CLIENT_ID = 'django_backend_publisher'

def publish_message(user_id, message_data):
    """
    Publishes a message to the user's specific topic.
    Topic: chat/user/{user_id}
    """
    def _publish():
        try:
            # Use a unique client ID for each push to avoid collisions
            import uuid
            unique_id = f"{CLIENT_ID}_{uuid.uuid4().hex[:6]}"
            client = mqtt.Client(unique_id)
            client.connect(BROKER, PORT, 60)
            
            topic = f'chat/user/{user_id}'
            payload = json.dumps(message_data)
            
            # Use QoS 1 for more reliable delivery
            client.publish(topic, payload, qos=1)
            client.disconnect()
            print(f"MQTT: Published to {topic} with CID {unique_id}")
        except Exception as e:
            print(f"MQTT Error: {e}")

    # Run in a separate thread to avoid blocking the request
    threading.Thread(target=_publish).start()
