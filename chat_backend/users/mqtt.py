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
            client = mqtt.Client(CLIENT_ID)
            client.connect(BROKER, PORT, 60)
            
            topic = f'chat/user/{user_id}'
            payload = json.dumps(message_data)
            
            client.publish(topic, payload)
            client.disconnect()
            print(f"MQTT: Published to {topic}")
        except Exception as e:
            print(f"MQTT Error: {e}")

    # Run in a separate thread to avoid blocking the request
    threading.Thread(target=_publish).start()
