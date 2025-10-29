message_count = 0
error_count = 0
device_ids = set()
device_message_times = {}

# MQTT callbacks
def on_connect(client, userdata, flags, rc):
    print('Connected to MQTT broker')
    client.subscribe(MQTT_TOPIC)

def on_message(client, userdata, msg):
    global message_count, error_count, device_ids
    message_count += 1
    payload_str = msg.payload.decode()
    print(f"[DEBUG] Raw JSON from MQTT: {payload_str}")
    try:
        payload = json.loads(payload_str)
    except Exception as e:
        error_count += 1
        print(f"[ERROR] BAD JSON: {payload_str}")
        print(f"[ERROR] Exception: {e}")
        publish_stats(client)
        return
    # If payload is a list, process each device
    devices = payload['devices'] if isinstance(payload, dict) and 'devices' in payload else [payload]
    now = time.time()
    for device in devices:
        print(f"[DEBUG] Parsed device: {device}")
        if 'id' in device:
            device_ids.add(device['id'])
            # Track message times for each device
            if device['id'] not in device_message_times:
                device_message_times[device['id']] = []
            device_message_times[device['id']].append(now)
        # Use relative time from device object, add to START_EPOCH
        rel_time = int(device.get('time', 0))
        timestamp = (START_EPOCH + rel_time) * 1000000000  # nanoseconds
        # Build and write InfluxDB point
        def to_int(val):
            try:
                return int(float(val))
            except (ValueError, TypeError):
                return 0

        point = Point("rgbww_metrics") \
            .tag("deviceid", str(to_int(device.get('id')))) \
            .field("id", to_int(device.get('id'))) \
            .field("time", to_int(device.get('time', 0))) \
            .field("uptime", to_int(device.get('uptime', 0))) \
            .field("freeHeap", to_int(device.get('freeHeap', 0)))
        if 'mDNS' in device:
            for k, v in device['mDNS'].items():
                point.field(f"mdns_{k}", to_int(v))
        if 'mDNS' in device:
            for k, v in device['mDNS'].items():
                point.field(f"mdns_{k}", v)
        point.time(timestamp, write_precision='ns')
        print(f"[DEBUG] INFLIUXDB_HOST: {INFLUXDB_HOST}")
        print(f"[DEBUG] INFLUXDB_BUCKET: {INFLUXDB_BUCKET}")
        print(f"[DEBUG] INFLUXDB_ORG: {INFLUXDB_ORG}")
        print(f"[DEBUG] INFLUXDB_TOKEN: {INFLUXDB_TOKEN}")
        print(f"[DEBUG] Writing point: {point}")
        write_api.write(bucket=INFLUXDB_BUCKET, record=point)
    publish_stats(client)

import json
import paho.mqtt.client as mqtt
import threading
import time
from datetime import datetime

# InfluxDB config
import os
from influxdb_client import InfluxDBClient, Point
INFLUXDB_HOST = os.environ.get('INFLUXDB_HOST', 'http://influxdb:8086')
INFLUXDB_ORG = os.environ.get('INFLUXDB_ORG', 'default')
INFLUXDB_BUCKET = os.environ.get('INFLUXDB_BUCKET', 'rgbww')
INFLUXDB_TOKEN = os.environ.get('RGBWW_TOKEN', '...')
print(f"[DEBUG] initialize InfluxdbClient   {INFLUXDB_HOST},{INFLUXDB_BUCKET},{INFLUXDB_ORG},{INFLUXDB_TOKEN}")
influx_client = InfluxDBClient(url=INFLUXDB_HOST, token=INFLUXDB_TOKEN, org=INFLUXDB_ORG)
write_api = influx_client.write_api()

# MQTT config
MQTT_BROKER = 'lightinator.de'
MQTT_PORT = 1883
MQTT_USER = 'rgbww'
MQTT_PASS = 'rgbwwdebug'
MQTT_TOPIC = 'rgbww/+/monitor'

# Common starting point for timestamps
START_TIME = datetime.utcnow()
START_EPOCH = int(START_TIME.timestamp())

# MQTT callbacks
def on_connect(client, userdata, flags, rc):
    print('Connected to MQTT broker')
    client.subscribe(MQTT_TOPIC)
def publish_stats(client):
    # Calculate average posts per minute for each device
    device_rates = []
    for device_id, times in device_message_times.items():
        if len(times) < 2:
            avg_rate = 0.0
        else:
            # Only consider messages in the last 10 minutes
            cutoff = time.time() - 600
            recent_times = [t for t in times if t >= cutoff]
            if len(recent_times) < 2:
                avg_rate = 0.0
            else:
                duration = recent_times[-1] - recent_times[0]
                avg_rate = (len(recent_times) - 1) / (duration / 60) if duration > 0 else 0.0
        device_rates.append({"id": device_id, "avg_posts_per_min": round(avg_rate, 2)})
    stats = {
        "messages": message_count,
        "errors": error_count,
        "distinct_device_ids": len(device_ids),
        "device_rates": device_rates
    }
    payload = json.dumps(stats)
    print(f"Publishing stats to rgbww/importer: {payload}")
    result = client.publish("rgbww/importer", payload)
    print(f"Publish result: {result}")

if __name__ == '__main__':
    message_count = 0
    error_count = 0
    device_ids = set()
    client = mqtt.Client()
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(MQTT_BROKER, MQTT_PORT)
    client.loop_forever()
