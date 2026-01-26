import sys
import json
import paho.mqtt.publish as publish

BROKER = 'broker.emqx.io'
PORT = 1883

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_mqtt.py [user_id]")
        sys.exit(1)
    
    user_id = sys.argv[1]
    topic = f'bishal_chat/user/{user_id}'
    # topic = 'bishal_chat/global_test'
    
    data = {
        'type': 'new_message',
        'sender': 'System Test',
        'content': 'This is a test notification from Vercel!',
        'timestamp': 'now',
        'sender_id': 9999
    }
    
    print(f"Triggering SYNC notification for User {user_id} on {topic}...")
    try:
        publish.single(
            topic, 
            payload=json.dumps(data), 
            hostname=BROKER, 
            port=PORT,
            qos=0
        )
        print("[MQTT] SUCCESS! Message delivered to broker.")
        print("Done. Check the logs and your phone.")
    except Exception as e:
        print(f"[MQTT] FAILED: {str(e)}")
