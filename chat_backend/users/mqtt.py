import paho.mqtt.client as mqtt
import json
import uuid
import threading
import time

BROKER = 'broker.hivemq.com'
PORT = 1883
CLIENT_ID_PREFIX = 'bishal_django_pub'

def _do_publish(topic, payload, unique_id):
    """
    Synchronous inner function to handle connection and publication.
    """
    client = mqtt.Client(client_id=unique_id)
    
    try:
        print(f"[MQTT-BACKEND v7] [Thread: {unique_id}] Connecting to {BROKER}:{PORT}...")
        # Set a 5-second timeout for the initial connection
        client.connect(BROKER, PORT, keepalive=60)
        
        # Start the loop to handle internal MQTT state
        client.loop_start()
        
        print(f"[MQTT-BACKEND v7] [Thread: {unique_id}] Publishing to {topic}...")
        publish_info = client.publish(topic, payload, qos=0)
        
        # Wait for delivery with a timeout
        wait_success = publish_info.wait_for_publish(timeout=5)
        
        if wait_success:
            print(f"[MQTT-BACKEND v7] [Thread: {unique_id}] SUCCESS: Delivered to {topic}")
        else:
            print(f"[MQTT-BACKEND v7] [Thread: {unique_id}] WARNING: Publish timeout after 5s for {topic}")
            
        # Clean shutdown
        client.loop_stop()
        client.disconnect()
        
    except Exception as e:
        print(f"[MQTT-BACKEND v7] [Thread: {unique_id}] FAILURE: {str(e)} during publish to {topic}")
    finally:
        # Final cleanup safety check
        try:
            if client.is_connected():
                client.disconnect()
        except:
            pass

def publish_message(user_id, message_data):
    """
    Publishes a message to the user's specific topic (Asynchronously).
    Topic: bishal_chat/user/{user_id}
    """
    topic = f'bishal_chat/user/{user_id}'
    payload = json.dumps(message_data)
    
    # Create a unique client ID for this specific publication attempt
    unique_id = f"{CLIENT_ID_PREFIX}_{uuid.uuid4().hex[:6]}"
    
    print(f"[MQTT-BACKEND v7] Main thread starting background task for {topic}...")
    
    # Run in background thread so Django doesn't wait for network I/O
    thread = threading.Thread(
        target=_do_publish, 
        args=(topic, payload, unique_id), 
        daemon=True
    )
    thread.start()