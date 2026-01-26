import paho.mqtt.publish as publish
import json
import uuid
import threading
import time

BROKER = 'broker.hivemq.com'
PORT = 1883

def _do_publish(topic, payload):
    print(f"[MQTT-THREAD] Entering _do_publish for {topic}")
    try:
        unique_pub_id = f"bishal_django_pub_{uuid.uuid4().hex[:6]}"
        print(f"[MQTT-THREAD] Attempting publish.single to {topic} (ID: {unique_pub_id})...")
        publish.single(
            topic, 
            payload=payload, 
            qos=0, 
            hostname=BROKER, 
            port=PORT,
            client_id=unique_pub_id
        )
        print(f"[MQTT-THREAD] SUCCESS for {topic} at {time.strftime('%H:%M:%S')}")
    except Exception as e:
        print(f"[MQTT-THREAD] ERROR for {topic}: {str(e)}")
    finally:
        print(f"[MQTT-THREAD] Exiting thread for {topic}")

def publish_message(user_id, message_data):
    """
    Publishes a message to the user's specific topic (Asynchronously).
    Topic: bishal_chat/user/{user_id}
    """
    topic = f'bishal_chat/user/{user_id}'
    payload = json.dumps(message_data)
    
    print(f"[MQTT-BACKEND v7] Spawning background thread for {topic}...")
    
    # Run in background thread so Django doesn't wait for network
    threading.Thread(
        target=_do_publish, 
        args=(topic, payload), 
        daemon=True
    ).start()
