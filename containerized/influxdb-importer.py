
import json
import requests
import paho.mqtt.client as mqtt
import time
from datetime import datetime

# InfluxDB config
INFLUXDB_URL = 'http://influxdb:8086/api/v2/write?bucket=rgbww&org=default'
INFLUXDB_TOKEN = 'your-influxdb-token'
HEADERS = {'Authorization': f'Token {INFLUXDB_TOKEN}', 'Content-Type': 'text/plain'}

# MQTT config
MQTT_BROKER = 'lightinator.de'
MQTT_PORT = 1883
MQTT_USER = 'rgbww'
MQTT_PASS = 'rgbwwdebug'
MQTT_TOPIC = 'rgbww/#'

# Common starting point for timestamps
START_TIME = datetime.utcnow()
START_EPOCH = int(START_TIME.timestamp())

# Line protocol helper
def to_line_protocol(device, timestamp):
    tags = f"deviceid={device.get('id')}"
    fields = []
    for k, v in device.items():
        if isinstance(v, (int, float)):
            fields.append(f"{k}={v}")
    if 'mDNS' in device:
        for k, v in device['mDNS'].items():
            if isinstance(v, (int, float)):
                fields.append(f"mdns_{k}={v}")
    return f"rgbww_metrics,{tags} {','.join(fields)} {timestamp}"

# MQTT callbacks
def on_connect(client, userdata, flags, rc):
    print('Connected to MQTT broker')
    client.subscribe(MQTT_TOPIC)

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        # If payload is a list, process each device
        devices = payload['devices'] if isinstance(payload, dict) and 'devices' in payload else [payload]
        for device in devices:
            # Use relative time from device object, add to START_EPOCH
            rel_time = int(device.get('time', 0))
            timestamp = (START_EPOCH + rel_time) * 1000000000  # nanoseconds
            line = to_line_protocol(device, timestamp)
            print(f"Writing to InfluxDB: {line}")
            requests.post(INFLUXDB_URL, headers=HEADERS, data=line)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    client = mqtt.Client()
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(MQTT_BROKER, MQTT_PORT)
    client.loop_forever()
