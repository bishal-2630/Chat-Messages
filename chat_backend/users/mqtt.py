import paho.mqtt.client as mqtt
import json
import uuid
import time

BROKER = 'broker.emqx.io'
PORT = 1883
CLIENT_ID = 'django_backend_publisher'

def publish_message(user_id, message_data):
    """
    Publishes a message to the user's specific topic.
    Topic: bishal_chat/user/{user_id}
    """
    try:
        # Create a unique client ID for each push
        unique_id = f"{CLIENT_ID}_{uuid.uuid4().hex[:6]}"
        client = mqtt.Client(unique_id)
        
        print(f"[MQTT] Connecting to {BROKER}...")
        client.connect(BROKER, PORT, 60)
        
        # Start loop to handle background networking
        client.loop_start()
        
        topic = f'bishal_chat/user/{user_id}'
        payload = json.dumps(message_data)
        
        print(f"[MQTT] Publishing to {topic}...")
        msg_info = client.publish(topic, payload, qos=1)
        
        # MANDATORY FOR VERCEL: Wait for the delivery to finish
        msg_info.wait_for_publish()
        
        # Give a small buffer for cleanup
        time.sleep(0.5)
        
        client.loop_stop()
        client.disconnect()
        print(f"[MQTT] Success! Delivered to {topic}")
        
    except Exception as e:
        print(f"[MQTT] FAILED: {str(e)}")