import paho.mqtt.publish as publish
import json
import uuid
import threading

BROKER = 'broker.hivemq.com'
PORT = 1883

def _do_publish(topic, payload):
    """
    Synchronous inner function using the proven publish.single method.
    """
    try:
        print(f"[MQTT-BACKEND v7] Attempting to publish to {topic} via HiveMQ...")
        publish.single(
            topic, 
            payload=payload, 
            qos=0, 
            hostname=BROKER, 
            port=PORT
        )
        print(f"[MQTT-BACKEND v7] SUCCESS: Delivered message to {topic}")
    except Exception as e:
        print(f"[MQTT-BACKEND v7] FAILURE: Could not deliver to {topic}. Error: {str(e)}")

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
