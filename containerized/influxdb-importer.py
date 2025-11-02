import json
import os
import threading
import time
from collections import deque
from flask import Flask, jsonify
import paho.mqtt.client as mqtt
import influxdb_client
from influxdb_client.client.write_api import SYNCHRONOUS
from influxdb_client import Point, WritePrecision
from datetime import datetime, timezone 

# --- Configuration ---
# MQTT_BROKER = 'lightinator.de'
# MQTT_PORT = 1883
# MQTT_USER = 'rgbww'
# MQTT_PASS = 'rgbwwdebug'
# Multi-level wildcard topic pattern
# MQTT_TOPIC = 'rgbww/+/monitor' 
# BUFFER_SIZE = 10
# HTTP_PORT = 8001

MQTT_BROKER=os.environ.get('MQTT_BROKER', 'lightinator.de')
MQTT_PORT=int(os.environ.get('MQTT_PORT', 1883))
MQTT_USER=os.environ.get('MQTT_USER', 'rgbww')
MQTT_PASS=os.environ.get('MQTT_PASS', 'rgbwwdebug')
MQTT_TOPIC=os.environ.get('MQTT_TOPIC', 'rgbww/+/monitor')

BUFFER_SIZE=int(os.environ.get('BUFFER_SIZE', 10))

HTTP_PORT = int(os.environ.get('HTTP_PORT', 8001))

# --- InfluxDB Configuration ---
# ----------------------------------------------------------------------
# INFLUX_URL = 'http://127.0.0.1:8086' # <-- SET YOUR INFLUXDB URL
# INFLUX_ORG = 'default'         # <-- SET YOUR INFLUXDB ORG ID
# INFLUX_BUCKET = 'rgbww'
# INFLUX_TOKEN = '0O3MlXDBJC_92vr50FjIgnCYpKKsf8woe1_WOf8iGY5BZWTiDWVIKCRDGx9JRTucZ-2JWLJfjgK0HeTHQDdXNA==' # <-- SET YOUR INFLUXDB ACCESS TOKEN
# WRITE_INTERVAL = 5                 # Seconds between write attempts
# ----------------------------------------------------------------------
INFLUX_URL = os.environ.get('INFLUX_URL', 'http://influxdb:8086')
INFLUX_ORG = os.environ.get('INFLUX_ORG', 'default')
INFLUX_BUCKET = os.environ.get('INFLUX_BUCKET', 'rgbww')
INFLUX_TOKEN = os.environ.get('INFLUX_TOKEN', '0O3MlXDBJC_92vr50FjIgnCYpKKsf8woe1_WOf8iGY5BZWTiDWVIKCRDGx9JRTucZ-2JWLJfjgK0HeTHQDdXNA==')
WRITE_INTERVAL= int(os.environ.get('WRITE_INTERVAL', 5))

# Buffer: single global queue of messages
buffer = deque(maxlen=BUFFER_SIZE * 100)

app = Flask(__name__)

# --- InfluxDB Client Setup ---
INFLUX_WRITE_API = None
try:
    INFLUX_CLIENT = influxdb_client.InfluxDBClient(
        url=INFLUX_URL, 
        token=INFLUX_TOKEN, 
        org=INFLUX_ORG
    )
    # Use SYNCHRONOUS mode for simpler error handling
    INFLUX_WRITE_API = INFLUX_CLIENT.write_api(write_options=SYNCHRONOUS)
    print("InfluxDB client initialized successfully.")
except Exception as e:
    print(f"Error initializing InfluxDB client: {e}. Please check your URL, Token, and Org. Write functionality disabled.")


# --- JSON FLATTENING FUNCTION ---
def flatten_json(y):
    """
    Recursively flattens a nested dictionary.
    Keys are joined by an underscore (e.g., 'parent_child').
    """
    out = {}

    def flatten(x, name=''):
        if isinstance(x, dict):
            for a in x:
                flatten(x[a], name + a + '_')
        elif isinstance(x, list):
            # Skip lists as they are not easily mapped to InfluxDB fields
            print(f"Warning: Skipping list field at key: {name.strip('_')}")
            pass 
        else:
            out[name[:-1]] = x

    flatten(y)
    return out


@app.route('/metrics.json')
def metrics():
    """Flask endpoint to view buffered messages."""
    filtered = [msg for msg in list(buffer) if isinstance(msg, dict) and 'id' in msg]
    return jsonify({"devices": filtered})

# --- MQTT Functions ---
def on_connect(client, userdata, flags, rc):
    """Callback for when the client connects to the MQTT broker."""
    print('Connected to MQTT broker')
    print(f'Subscribing to topic pattern: {MQTT_TOPIC}')
    result1, mid1 = client.subscribe(MQTT_TOPIC)
    print(f'Subscribe result: {result1}, message id: {mid1}')
    # Subscribe to log topic
    log_topic = 'rgbww/+/log'
    result2, mid2 = client.subscribe(log_topic)
    print(f'Subscribing to topic pattern: {log_topic}')
    print(f'Subscribe result: {result2}, message id: {mid2}')

def on_message(client, userdata, msg):
    """Callback for when a message is received from the MQTT broker."""
    topic = msg.topic
    payload_str = msg.payload.decode()
    # Handle log messages
    if topic.endswith('/log'):
        # Extract <id> from topic
        parts = topic.split('/')
        if len(parts) >= 3:
            device_id = parts[1]
            # Write to InfluxDB measurement rgbww_log
            try:
                point = Point("rgbww_log").tag("id", device_id).field("message", str(payload_str)).time(time=datetime.now(timezone.utc), write_precision=WritePrecision.NS)
                INFLUX_WRITE_API.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=point)
                print(f"[LOG] Wrote log message for device {device_id}: {payload_str}")
            except Exception as e:
                print(f"[ERROR] Failed to write log message: {e}")
        else:
            print(f"[ERROR] Could not parse device id from topic: {topic}")
        return
    # Handle monitor messages (existing logic)
    try:
        payload = json.loads(payload_str)
        buffer.append(payload)
    except Exception as e:
        print(f'Error processing message: {e}')

def mqtt_thread():
    """Runs the MQTT client loop and periodically publishes bridge status."""
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
            # Publish to a neutral topic to avoid loops
            client.publish('bridge/status', json.dumps(status), qos=0, retain=False)
            time.sleep(10)

    threading.Thread(target=publish_status, daemon=True).start()
    client.loop_forever()


# --- INFLUXDB WRITER THREAD (WITH STRICT INTEGER ENFORCEMENT) ---
def influxdb_writer_thread():
    """Pulls messages from the buffer, FLATTENS, converts to InfluxDB Points, and writes them."""
    if not INFLUX_WRITE_API:
        print("InfluxDB Write API is not available. Writer thread exiting.")
        return

    # --- THIS IS THE CRITICAL FIX FOR YOUR SCHEMA ---
    # List of field keys that MUST be stored as integers in InfluxDB
    INTEGER_ONLY_FIELDS = ['uptime', 'freeHeap', 'id', 'time', 'mdns_received', 'mdns_replies']
    
    print(f"Starting InfluxDB writer thread. Target bucket: {INFLUX_BUCKET}")
    while True:
        messages_to_process = [] 
        
        try:
            if not buffer:
                time.sleep(WRITE_INTERVAL)
                continue

            # Safely extract all messages currently in the buffer
            while buffer:
                 messages_to_process.append(buffer.popleft()) 

            # 1. Flatten and Convert to InfluxDB Point objects
            points = []
            for message in messages_to_process:
                # Flatten the JSON message to handle nested objects
                flattened_message = flatten_json(message)
                
                device_id_raw = flattened_message.get('id', flattened_message.get('deviceid'))
                try:
                    device_id = int(device_id_raw)
                except (ValueError, TypeError):
                    continue

                # The MEASUREMENT IS DEFINED HERE: rgbww_light_state
                point = Point("rgbww_debug_data").tag("device", device_id)
                
                # Iterate over the FLATTENED message
                for key, value in flattened_message.items():
                    # Skip common base metadata keys
                    if key in ['id', 'deviceid', 'time', 'mac', 'timestamp_ms']: 
                        continue

                    # --- Robust Type Casting Logic ---
                    converted_value = None
                    
                    try:
                        # Check if the value is numerical or can be converted to numerical
                        if isinstance(value, (int, float)):
                            float_val = float(value)
                        elif isinstance(value, str) and (value.replace('.', '', 1).isdigit() and value.count('.') < 2):
                            # This handles "123" and "123.45" but not "1.2.3"
                            float_val = float(value)
                        else:
                            # Not numerical, use original value (e.g., string, boolean)
                            converted_value = value
                            
                        # If we successfully got a float_val, apply conversion rules
                        if converted_value is None:
                            if key in INTEGER_ONLY_FIELDS:
                                # Cast to int for fields like uptime
                                converted_value = int(float_val)
                            else:
                                # Otherwise, use the float value
                                converted_value = float_val
                                
                    except ValueError:
                        # If any part of the conversion failed, skip the field
                        continue 
                        
                    point.field(key, converted_value)
                
                if point._fields: 
                    # Use nanosecond precision
                    point.time(time=datetime.now(timezone.utc), write_precision=WritePrecision.NS)
                    points.append(point)

            if not points:
                # No valid data to write
                messages_to_process.clear() 
                time.sleep(WRITE_INTERVAL)
                continue
            
            # 2. Write the points
            print(f"Attempting to write {len(points)} points to InfluxDB...")
            INFLUX_WRITE_API.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=points)
            
            print(f"Successfully wrote {len(points)} points to InfluxDB.")
            messages_to_process.clear()

        except influxdb_client.rest.ApiException as api_e:
            print(f"InfluxDB API Error: Status {api_e.status}. Reason: {api_e.reason}. Body: {api_e.body}")
            if api_e.status == 401:
                 print("!!! AUTHENTICATION ERROR (401). Check INFLUX_TOKEN, ORG, and URL in configuration. !!!")
            
        except Exception as e:
            print(f"Unexpected error in InfluxDB writer thread: {e}")
            
        finally:
            # Re-add any messages that failed the write attempt back to the buffer
            for msg in messages_to_process:
                buffer.appendleft(msg) 
                
            time.sleep(WRITE_INTERVAL)

if __name__ == '__main__':
    # Install dependencies check
    try:
        import paho.mqtt
        import flask
        import influxdb_client 
    except ImportError:
        import pip
        print("Installing dependencies: paho-mqtt, flask, influxdb-client")
        pip.main(['install', 'paho-mqtt', 'flask', 'influxdb-client'])
        
    buffer.clear()
    
    # Start the MQTT thread
    threading.Thread(target=mqtt_thread, daemon=True).start()
    
    # Start the InfluxDB writer thread
    threading.Thread(target=influxdb_writer_thread, daemon=True).start() 
    
    # Start the Flask app
    app.run(host='0.0.0.0', port=HTTP_PORT)
import json
import threading
import time
from collections import deque
from flask import Flask, jsonify
import paho.mqtt.client as mqtt
import influxdb_client
from influxdb_client.client.write_api import SYNCHRONOUS
from influxdb_client import Point, WritePrecision
from datetime import datetime, timezone 

# --- Configuration ---
MQTT_BROKER = 'lightinator.de'
MQTT_PORT = 1883
MQTT_USER = 'rgbww'
MQTT_PASS = 'rgbwwdebug'
# Multi-level wildcard topic pattern
MQTT_TOPIC = 'rgbww/+/monitor' 
BUFFER_SIZE = 10
HTTP_PORT = 8001

# --- InfluxDB Configuration ---
# ----------------------------------------------------------------------
INFLUX_URL = 'http://127.0.0.1:8086' # <-- SET YOUR INFLUXDB URL
INFLUX_ORG = 'default'         # <-- SET YOUR INFLUXDB ORG ID
INFLUX_BUCKET = 'rgbww'
INFLUX_TOKEN = '0O3MlXDBJC_92vr50FjIgnCYpKKsf8woe1_WOf8iGY5BZWTiDWVIKCRDGx9JRTucZ-2JWLJfjgK0HeTHQDdXNA==' # <-- SET YOUR INFLUXDB ACCESS TOKEN
WRITE_INTERVAL = 5                 # Seconds between write attempts
# ----------------------------------------------------------------------

# Buffer: single global queue of messages
buffer = deque(maxlen=BUFFER_SIZE * 100)

app = Flask(__name__)

# --- InfluxDB Client Setup ---
INFLUX_WRITE_API = None
try:
    INFLUX_CLIENT = influxdb_client.InfluxDBClient(
        url=INFLUX_URL, 
        token=INFLUX_TOKEN, 
        org=INFLUX_ORG
    )
    # Use SYNCHRONOUS mode for simpler error handling
    INFLUX_WRITE_API = INFLUX_CLIENT.write_api(write_options=SYNCHRONOUS)
    print("InfluxDB client initialized successfully.")
except Exception as e:
    print(f"Error initializing InfluxDB client: {e}. Please check your URL, Token, and Org. Write functionality disabled.")


# --- JSON FLATTENING FUNCTION ---
def flatten_json(y):
    """
    Recursively flattens a nested dictionary.
    Keys are joined by an underscore (e.g., 'parent_child').
    """
    out = {}

    def flatten(x, name=''):
        if isinstance(x, dict):
            for a in x:
                flatten(x[a], name + a + '_')
        elif isinstance(x, list):
            # Skip lists as they are not easily mapped to InfluxDB fields
            print(f"Warning: Skipping list field at key: {name.strip('_')}")
            pass 
        else:
            out[name[:-1]] = x

    flatten(y)
    return out


@app.route('/metrics.json')
def metrics():
    """Flask endpoint to view buffered messages."""
    filtered = [msg for msg in list(buffer) if isinstance(msg, dict) and 'id' in msg]
    return jsonify({"devices": filtered})

# --- MQTT Functions ---
def on_connect(client, userdata, flags, rc):
    """Callback for when the client connects to the MQTT broker."""
    print('Connected to MQTT broker')
    print(f'Subscribing to topic pattern: {MQTT_TOPIC}')
    result, mid = client.subscribe(MQTT_TOPIC)
    print(f'Subscribe result: {result}, message id: {mid}')

def on_message(client, userdata, msg):
    """Callback for when a message is received from the MQTT broker."""
    try:
        payload = json.loads(msg.payload.decode())
        buffer.append(payload)
    except Exception as e:
        print(f'Error processing message: {e}')

def mqtt_thread():
    """Runs the MQTT client loop and periodically publishes bridge status."""
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
            # Publish to a neutral topic to avoid loops
            client.publish('bridge/status', json.dumps(status), qos=0, retain=False)
            time.sleep(10)

    threading.Thread(target=publish_status, daemon=True).start()
    client.loop_forever()


# --- INFLUXDB WRITER THREAD (WITH STRICT INTEGER ENFORCEMENT) ---
def influxdb_writer_thread():
    """Pulls messages from the buffer, FLATTENS, converts to InfluxDB Points, and writes them."""
    if not INFLUX_WRITE_API:
        print("InfluxDB Write API is not available. Writer thread exiting.")
        return

    # --- THIS IS THE CRITICAL FIX FOR YOUR SCHEMA ---
    # List of field keys that MUST be stored as integers in InfluxDB
    INTEGER_ONLY_FIELDS = ['uptime', 'freeHeap', 'id', 'time', 'mdns_received', 'mdns_replies']
    
    print(f"Starting InfluxDB writer thread. Target bucket: {INFLUX_BUCKET}")
    while True:
        messages_to_process = [] 
        
        try:
            if not buffer:
                time.sleep(WRITE_INTERVAL)
                continue

            # Safely extract all messages currently in the buffer
            while buffer:
                 messages_to_process.append(buffer.popleft()) 

            # 1. Flatten and Convert to InfluxDB Point objects
            points = []
            for message in messages_to_process:
                # Flatten the JSON message to handle nested objects
                flattened_message = flatten_json(message)
                
                device_id_raw = flattened_message.get('id', flattened_message.get('deviceid'))
                try:
                    device_id = int(device_id_raw)
                except (ValueError, TypeError):
                    continue

                # The MEASUREMENT IS DEFINED HERE: rgbww_light_state
                point = Point("rgbww_debug_data").tag("device", device_id)
                
                # Iterate over the FLATTENED message
                for key, value in flattened_message.items():
                    # Skip common base metadata keys
                    if key in ['id', 'deviceid', 'time', 'mac', 'timestamp_ms']: 
                        continue

                    # --- Robust Type Casting Logic ---
                    converted_value = None
                    
                    try:
                        # Check if the value is numerical or can be converted to numerical
                        if isinstance(value, (int, float)):
                            float_val = float(value)
                        elif isinstance(value, str) and (value.replace('.', '', 1).isdigit() and value.count('.') < 2):
                            # This handles "123" and "123.45" but not "1.2.3"
                            float_val = float(value)
                        else:
                            # Not numerical, use original value (e.g., string, boolean)
                            converted_value = value
                            
                        # If we successfully got a float_val, apply conversion rules
                        if converted_value is None:
                            if key in INTEGER_ONLY_FIELDS:
                                # Cast to int for fields like uptime
                                converted_value = int(float_val)
                            else:
                                # Otherwise, use the float value
                                converted_value = float_val
                                
                    except ValueError:
                        # If any part of the conversion failed, skip the field
                        continue 
                        
                    point.field(key, converted_value)
                
                if point._fields: 
                    # Use nanosecond precision
                    point.time(time=datetime.now(timezone.utc), write_precision=WritePrecision.NS)
                    points.append(point)

            if not points:
                # No valid data to write
                messages_to_process.clear() 
                time.sleep(WRITE_INTERVAL)
                continue
            
            # 2. Write the points
            print(f"Attempting to write {len(points)} points to InfluxDB...")
            INFLUX_WRITE_API.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=points)
            
            print(f"Successfully wrote {len(points)} points to InfluxDB.")
            messages_to_process.clear()

        except influxdb_client.rest.ApiException as api_e:
            print(f"InfluxDB API Error: Status {api_e.status}. Reason: {api_e.reason}. Body: {api_e.body}")
            if api_e.status == 401:
                 print("!!! AUTHENTICATION ERROR (401). Check INFLUX_TOKEN, ORG, and URL in configuration. !!!")
            
        except Exception as e:
            print(f"Unexpected error in InfluxDB writer thread: {e}")
            
        finally:
            # Re-add any messages that failed the write attempt back to the buffer
            for msg in messages_to_process:
                buffer.appendleft(msg) 
                
            time.sleep(WRITE_INTERVAL)

if __name__ == '__main__':
    # Install dependencies check
    try:
        import paho.mqtt
        import flask
        import influxdb_client 
    except ImportError:
        import pip
        print("Installing dependencies: paho-mqtt, flask, influxdb-client")
        pip.main(['install', 'paho-mqtt', 'flask', 'influxdb-client'])
        
    buffer.clear()
    
    # Start the MQTT thread
    threading.Thread(target=mqtt_thread, daemon=True).start()
    
    # Start the InfluxDB writer thread
    threading.Thread(target=influxdb_writer_thread, daemon=True).start() 
    
    # Start the Flask app
    app.run(host='0.0.0.0', port=HTTP_PORT)
import json
import threading
import time
from collections import deque
from flask import Flask, jsonify
import paho.mqtt.client as mqtt
import influxdb_client
from influxdb_client.client.write_api import SYNCHRONOUS
from influxdb_client import Point, WritePrecision
from datetime import datetime, timezone 

# --- Configuration ---
MQTT_BROKER = 'lightinator.de'
MQTT_PORT = 1883
MQTT_USER = 'rgbww'
MQTT_PASS = 'rgbwwdebug'
# Multi-level wildcard topic pattern
MQTT_TOPIC = 'rgbww/+/monitor' 
BUFFER_SIZE = 10
HTTP_PORT = 8001

# --- InfluxDB Configuration ---
# ----------------------------------------------------------------------
INFLUX_URL = 'http://127.0.0.1:8086' # <-- SET YOUR INFLUXDB URL
INFLUX_ORG = 'default'         # <-- SET YOUR INFLUXDB ORG ID
INFLUX_BUCKET = 'rgbww'
INFLUX_TOKEN = '0O3MlXDBJC_92vr50FjIgnCYpKKsf8woe1_WOf8iGY5BZWTiDWVIKCRDGx9JRTucZ-2JWLJfjgK0HeTHQDdXNA==' # <-- SET YOUR INFLUXDB ACCESS TOKEN
WRITE_INTERVAL = 5                 # Seconds between write attempts
# ----------------------------------------------------------------------

# Buffer: single global queue of messages
buffer = deque(maxlen=BUFFER_SIZE * 100)

app = Flask(__name__)

# --- InfluxDB Client Setup ---
INFLUX_WRITE_API = None
try:
    INFLUX_CLIENT = influxdb_client.InfluxDBClient(
        url=INFLUX_URL, 
        token=INFLUX_TOKEN, 
        org=INFLUX_ORG
    )
    # Use SYNCHRONOUS mode for simpler error handling
    INFLUX_WRITE_API = INFLUX_CLIENT.write_api(write_options=SYNCHRONOUS)
    print("InfluxDB client initialized successfully.")
except Exception as e:
    print(f"Error initializing InfluxDB client: {e}. Please check your URL, Token, and Org. Write functionality disabled.")


# --- JSON FLATTENING FUNCTION ---
def flatten_json(y):
    """
    Recursively flattens a nested dictionary.
    Keys are joined by an underscore (e.g., 'parent_child').
    """
    out = {}

    def flatten(x, name=''):
        if isinstance(x, dict):
            for a in x:
                flatten(x[a], name + a + '_')
        elif isinstance(x, list):
            # Skip lists as they are not easily mapped to InfluxDB fields
            print(f"Warning: Skipping list field at key: {name.strip('_')}")
            pass 
        else:
            out[name[:-1]] = x

    flatten(y)
    return out


@app.route('/metrics.json')
def metrics():
    """Flask endpoint to view buffered messages."""
    filtered = [msg for msg in list(buffer) if isinstance(msg, dict) and 'id' in msg]
    return jsonify({"devices": filtered})

# --- MQTT Functions ---
def on_connect(client, userdata, flags, rc):
    """Callback for when the client connects to the MQTT broker."""
    print('Connected to MQTT broker')
    print(f'Subscribing to topic pattern: {MQTT_TOPIC}')
    result, mid = client.subscribe(MQTT_TOPIC)
    print(f'Subscribe result: {result}, message id: {mid}')

def on_message(client, userdata, msg):
    """Callback for when a message is received from the MQTT broker."""
    try:
        payload = json.loads(msg.payload.decode())
        buffer.append(payload)
    except Exception as e:
        print(f'Error processing message: {e}')

def mqtt_thread():
    """Runs the MQTT client loop and periodically publishes bridge status."""
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
            # Publish to a neutral topic to avoid loops
            client.publish('bridge/status', json.dumps(status), qos=0, retain=False)
            time.sleep(10)

    threading.Thread(target=publish_status, daemon=True).start()
    client.loop_forever()


# --- INFLUXDB WRITER THREAD (WITH STRICT INTEGER ENFORCEMENT) ---
def influxdb_writer_thread():
    """Pulls messages from the buffer, FLATTENS, converts to InfluxDB Points, and writes them."""
    if not INFLUX_WRITE_API:
        print("InfluxDB Write API is not available. Writer thread exiting.")
        return

    # --- THIS IS THE CRITICAL FIX FOR YOUR SCHEMA ---
    # List of field keys that MUST be stored as integers in InfluxDB
    INTEGER_ONLY_FIELDS = ['uptime', 'freeHeap', 'id', 'time', 'mdns_received', 'mdns_replies']
    
    print(f"Starting InfluxDB writer thread. Target bucket: {INFLUX_BUCKET}")
    while True:
        messages_to_process = [] 
        
        try:
            if not buffer:
                time.sleep(WRITE_INTERVAL)
                continue

            # Safely extract all messages currently in the buffer
            while buffer:
                 messages_to_process.append(buffer.popleft()) 

            # 1. Flatten and Convert to InfluxDB Point objects
            points = []
            for message in messages_to_process:
                # Flatten the JSON message to handle nested objects
                flattened_message = flatten_json(message)
                
                device_id_raw = flattened_message.get('id', flattened_message.get('deviceid'))
                try:
                    device_id = int(device_id_raw)
                except (ValueError, TypeError):
                    continue

                # The MEASUREMENT IS DEFINED HERE: rgbww_light_state
                point = Point("rgbww_debug_data").tag("device", device_id)
                
                # Iterate over the FLATTENED message
                for key, value in flattened_message.items():
                    # Skip common base metadata keys
                    if key in ['id', 'deviceid', 'time', 'mac', 'timestamp_ms']: 
                        continue

                    # --- Robust Type Casting Logic ---
                    converted_value = None
                    
                    try:
                        # Check if the value is numerical or can be converted to numerical
                        if isinstance(value, (int, float)):
                            float_val = float(value)
                        elif isinstance(value, str) and (value.replace('.', '', 1).isdigit() and value.count('.') < 2):
                            # This handles "123" and "123.45" but not "1.2.3"
                            float_val = float(value)
                        else:
                            # Not numerical, use original value (e.g., string, boolean)
                            converted_value = value
                            
                        # If we successfully got a float_val, apply conversion rules
                        if converted_value is None:
                            if key in INTEGER_ONLY_FIELDS:
                                # Cast to int for fields like uptime
                                converted_value = int(float_val)
                            else:
                                # Otherwise, use the float value
                                converted_value = float_val
                                
                    except ValueError:
                        # If any part of the conversion failed, skip the field
                        continue 
                        
                    point.field(key, converted_value)
                
                if point._fields: 
                    # Use nanosecond precision
                    point.time(time=datetime.now(timezone.utc), write_precision=WritePrecision.NS)
                    points.append(point)

            if not points:
                # No valid data to write
                messages_to_process.clear() 
                time.sleep(WRITE_INTERVAL)
                continue
            
            # 2. Write the points
            print(f"Attempting to write {len(points)} points to InfluxDB...")
            INFLUX_WRITE_API.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=points)
            
            print(f"Successfully wrote {len(points)} points to InfluxDB.")
            messages_to_process.clear()

        except influxdb_client.rest.ApiException as api_e:
            print(f"InfluxDB API Error: Status {api_e.status}. Reason: {api_e.reason}. Body: {api_e.body}")
            if api_e.status == 401:
                 print("!!! AUTHENTICATION ERROR (401). Check INFLUX_TOKEN, ORG, and URL in configuration. !!!")
            
        except Exception as e:
            print(f"Unexpected error in InfluxDB writer thread: {e}")
            
        finally:
            # Re-add any messages that failed the write attempt back to the buffer
            for msg in messages_to_process:
                buffer.appendleft(msg) 
                
            time.sleep(WRITE_INTERVAL)

if __name__ == '__main__':
    # Install dependencies check
    try:
        import paho.mqtt
        import flask
        import influxdb_client 
    except ImportError:
        import pip
        print("Installing dependencies: paho-mqtt, flask, influxdb-client")
        pip.main(['install', 'paho-mqtt', 'flask', 'influxdb-client'])
        
    buffer.clear()
    
    # Start the MQTT thread
    threading.Thread(target=mqtt_thread, daemon=True).start()
    
    # Start the InfluxDB writer thread
    threading.Thread(target=influxdb_writer_thread, daemon=True).start() 
    
    # Start the Flask app
    app.run(host='0.0.0.0', port=HTTP_PORT)
