import paho.mqtt.publish as publish
import json
import uuid

BROKER = 'broker.emqx.io'
PORT = 1883
CLIENT_ID = 'django_backend_publisher'

def publish_message(user_id, message_data):
    """
    Publishes a message to the user's specific topic.
    Topic: bishal_chat/user/{user_id}
    """
    topic = f'bishal_chat/user/{user_id}'
    payload = json.dumps(message_data)
    
    # Use a unique client ID to avoid collisions
    unique_id = f"{CLIENT_ID}_{uuid.uuid4().hex[:6]}"
    
    try:
        print(f"[MQTT] Attempting to deliver to {topic}...")
        
        # publish.single handles connection, loop, publish, and disconnection automatically
        publish.single(
            topic, 
            payload=payload, 
            qos=1, 
            hostname=BROKER, 
            port=PORT, 
            client_id=unique_id
        )
        
        print(f"[MQTT] Success! Delivered to {topic}")
        
    except Exception as e:
        print(f"[MQTT] FAILED to deliver to {topic}: {str(e)}")