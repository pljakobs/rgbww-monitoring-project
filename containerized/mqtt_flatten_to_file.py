import json
import os
from paho.mqtt.client import Client

def flatten_json(y, prefix=''):
    out = {}
    def flatten(x, name=''):
        if isinstance(x, dict):
            for a in x:
                flatten(x[a], f'{name}{a}_')
        elif isinstance(x, list):
            for i, a in enumerate(x):
                flatten(a, f'{name}{i}_')
        else:
            out[name[:-1]] = x
    flatten(y, prefix)
    return out

MQTT_BROKER = 'lightinator.de'
MQTT_PORT = 1883
MQTT_USER = 'rgbww'
MQTT_PASS = 'rgbwwdebug'
MQTT_TOPIC = 'rgbww/+/monitor'
OUTPUT_DIR = 'mqtt_flattened_output'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def on_connect(client, userdata, flags, rc):
    print('Connected to MQTT broker')
    client.subscribe(MQTT_TOPIC)

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
    except Exception as e:
        print(f'Error decoding JSON: {e}')
        return
    # If payload is a list, process each device
    devices = payload['devices'] if isinstance(payload, dict) and 'devices' in payload else [payload]
    for device in devices:
        flat = flatten_json(device)
        device_id = str(flat.get('id', 'unknown'))
        out_path = os.path.join(OUTPUT_DIR, f'{device_id}.jsonl')
        with open(out_path, 'a') as f:
            f.write(json.dumps(flat) + '\n')
        print(f'Wrote data for device {device_id}')

if __name__ == '__main__':
    client = Client()
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(MQTT_BROKER, MQTT_PORT)
    client.loop_forever()

