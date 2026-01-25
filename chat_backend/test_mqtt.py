import sys
import json
from users.mqtt import publish_message

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_mqtt.py [user_id]")
        sys.exit(1)
    
    user_id = sys.argv[1]
    data = {
        'sender': 'System Test',
        'content': 'This is a test notification from Vercel!',
        'timestamp': 'now'
    }
    
    print(f"Triggering manual notification for User {user_id}...")
    publish_message(user_id, data)
    print("Done. Check the logs and your phone.")
