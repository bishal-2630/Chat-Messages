import paho.mqtt.publish as publish
import json
import uuid
import threading

BROKER = 'broker.emqx.io'
PORT = 1883
CLIENT_ID = 'django_backend_publisher'

def _do_publish(topic, payload, unique_id):
    try:
        publish.single(
            topic, 
            payload=payload, 
            qos=1, 
            hostname=BROKER, 
            port=PORT, 
            client_id=unique_id                                                                                                                            
        )
        print(f"[MQTT] SUCCESS: Delivered message to {topic}")
    except Exception as e:
        print(f"[MQTT] FAILURE: Could not deliver to {topic}. Error: {str(e)}")

def publish_message(user_id, message_data):
    """
    Publishes a message to the user's specific topic (Asynchronously).
    Topic: bishal_chat/user/{user_id}
    """
    topic = f'bishal_chat/user/{user_id}'
    payload = json.dumps(message_data)
    unique_id = f"{CLIENT_ID}_{uuid.uuid4().hex[:6]}"
    
    # Run in background thread so Django doesn't wait for MQTT
    threading.Thread(target=_do_publish, args=(topic, payload, unique_id), daemon=True).start()
    print(f"[MQTT] Background publish started for {topic}")