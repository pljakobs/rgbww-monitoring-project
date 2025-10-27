import json
import threading
import time
from collections import defaultdict, deque
from flask import Flask, jsonify
import paho.mqtt.client as mqtt

# Configuration
MQTT_BROKER = 'lightinator.de'
MQTT_PORT = 1883
MQTT_USER = 'rgbww'  # <-- set your username
MQTT_PASS = 'rgbwwdebug'  # <-- set your password
MQTT_TOPIC = 'rgbww/#'
BUFFER_SIZE = 10  # Number of messages to buffer per device
HTTP_PORT = 8001


# Buffer: single global queue of messages
buffer = deque(maxlen=BUFFER_SIZE * 100)  # 100 devices * 10 messages each

app = Flask(__name__)

@app.route('/metrics.json')
def metrics():
    # Only return elements that have an 'id' field (valid device messages)
    filtered = [msg for msg in list(buffer) if isinstance(msg, dict) and 'id' in msg]
    return jsonify({"devices": filtered})

# MQTT callbacks
def on_connect(client, userdata, flags, rc):
    print('Connected to MQTT broker')
    print(f'Subscribing to topic pattern: {MQTT_TOPIC}')
    result, mid = client.subscribe(MQTT_TOPIC)
    print(f'Subscribe result: {result}, message id: {mid}')

def on_message(client, userdata, msg):
    try:
        print(f'Received MQTT message on topic: {msg.topic}')
        print(f'Raw payload: {msg.payload}')
        # Discard messages from rgbww/bridge/* topics
        if msg.topic.startswith('rgbww/bridge'):
            print('Discarding bridge status/config message')
            return
        payload = json.loads(msg.payload.decode())
        print(f'Parsed JSON: {payload}')
        buffer.append(payload)
    except Exception as e:
        print(f'Error processing message: {e}')

def mqtt_thread():
    client = mqtt.Client(client_id="mqtt_json_bridge")
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(MQTT_BROKER, MQTT_PORT)

    def publish_status():
        while True:
            status = {
                'messages_received': len(buffer),
                'devices': len(set(msg.get('deviceid', msg.get('id')) for msg in buffer)),
                'messages_queued': {}
            }
            # Only publish to 'bridge/status', never to 'rgbww/bridge/status'
            client.publish('bridge/status', json.dumps(status), qos=0, retain=False)
            time.sleep(10)

    threading.Thread(target=publish_status, daemon=True).start()
    client.loop_forever()

if __name__ == '__main__':
    buffer.clear()  # Clear buffer to remove any old status/config messages
    threading.Thread(target=mqtt_thread, daemon=True).start()
    app.run(host='0.0.0.0', port=HTTP_PORT)

# Install dependencies
try:
    import paho.mqtt
    import flask
except ImportError:
    import pip
    pip.main(['install', 'paho-mqtt', 'flask'])
