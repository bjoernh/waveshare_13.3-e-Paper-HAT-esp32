# 13.3" Spectra 6 E-Ink Display Project (Waveshare ESP32-S3-Nano + HAT+)

Display images on a 13.3" Spectra 6 color e-ink display. This branch (`waveshare-nano-hat`) targets a Waveshare **ESP32-S3-Nano** wired to a Waveshare **13.3" e-Paper HAT+ (E)**. See the `main` branch for the original Seeed Studio XIAO ePaper Display Board (EE02) port.

## So what does this project do

Custom firmware on the ESP32-S3-Nano that:

1. Connects to your WiFi network
2. Wakes up from deep sleep to fetch an image from an image server you run locally or remotely
3. Displays the image on a Spectra 6 e-ink screen
4. Goes back to sleep to conserve battery
5. Skips wakeups during configurable quiet hours
6. Only refreshes the display when the image has actually changed

---

## What's required

- Python 3.13 or newer (or Docker)
- `uv` (for non-Docker setup)
- A Waveshare ESP32-S3-Nano
- A Waveshare 13.3" e-Paper HAT+ (E) (1600×1200 Spectra 6 panel)
- A 10-pin ribbon cable (or jumper wires) to connect the HAT+ to the Nano — see the pin table in `firmware/README.md`
- A momentary push-button wired from D2 to GND on the Nano (used to enter configuration mode)
- A USB-C data cable
- A 2.4 GHz WiFi network

---

## Step-by-Step Setup Guide

### Step 1: Install `uv`

If you do not already have `uv`, install it with:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Step 2: Download This Project

```bash
git clone <repository-url>
cd seeed_eink_board
```

Or download and extract the ZIP file from the repository.

### Step 3: Install Project Dependencies

```bash
uv sync
```

This may take a few minutes the first time as it downloads PlatformIO and the ESP32 toolchain.

### Step 4: Configure Your WiFi Credentials

Copy the example config file and edit it with your credentials:

```bash
cd firmware/src
cp config.h.example config.h
```

Edit `config.h` and set your WiFi network:

```cpp
#define WIFI_SSID "YourNetworkName"
#define WIFI_PASSWORD "YourPassword"
```

**Note:** The ESP32 only supports **2.4 GHz WiFi** (not 5 GHz).

### Step 5: Find Your Computer's IP Address

The board needs the IP address of the computer that will run `image_server.py`.

Linux:
```bash
hostname -I
```

macOS:
```bash
ipconfig getifaddr en0
```

### Step 6: Configure the Image Server Address

Edit `firmware/src/config_manager.h` and set your server's IP:

```cpp
#define DEFAULT_SERVER_HOST "192.168.x.y"
```

The other defaults should be fine to start:
- `DEFAULT_SERVER_PORT 8000`
- `DEFAULT_IMAGE_ENDPOINT "/image_packed"`
- `DEFAULT_SLEEP_MINUTES 15` — minutes between wakeups during active hours
- `DEFAULT_ACTIVE_START_HOUR 8` / `DEFAULT_ACTIVE_END_HOUR 20` — quiet hours window
- `DEFAULT_TIMEZONE_OFFSET_MINUTES 0` — minutes from UTC (e.g. `120` for CET, `-300` for EST)

The device can also pull schedule settings from the server at runtime, so these defaults only need to be good enough to get you started.

### Step 7: Build the Firmware

```bash
cd firmware
uv run pio run
```

The first build takes several minutes as it downloads the ESP32 compiler and libraries. You should see:
```
========================= [SUCCESS] Took XX.XX seconds =========================
```

### Step 8: Connect the ESP32-S3-Nano

1. Wire the HAT+ to the Nano per the pin table in `firmware/README.md` (DIN→D11, CLK→D13, CS_M→D10, CS_S→D9, DC→D8, RST→D7, BUSY→D6, PWR→D5, plus 3V3 and GND).
2. Connect the Nano to your computer via USB-C. **Charge-only cables won't work.**

Check the port:

Linux: `ls /dev/ttyACM*` — macOS: `ls /dev/cu.usb*`

You may need to press RESET on the board before uploading.

### Step 9: Flash the Firmware

**Linux:**
```bash
uv run pio run -t upload --upload-port /dev/ttyACM0
```

**macOS:**
```bash
uv run pio run -t upload --upload-port /dev/cu.usbmodem14101
```

### Step 10: Prepare Images

```bash
mkdir -p images/default
cp your_photo.jpg images/default/
```

Images are automatically resized and dithered to the 6-color palette. Multiple images rotate on each refresh. Supported formats: JPEG, PNG, HEIC, WebP.

Optional: add a schedule override file so the display only wakes during the hours you care about:

```bash
cp device_config.example.json images/default/device_config.json
```

The same file can live in `images/<mac-address>/device_config.json` for a specific board. You can also edit schedules from the browser at `http://YOUR_SERVER_IP:8000/schedule` (or the embedded editors on the main status page).

### Step 11: Start the Image Server

**Option A — run directly:**
```bash
uv run python image_server.py
```

**Option B — Docker (recommended for always-on deployment):**
```bash
cp .env.example .env        # set EINK_HOST=your.domain.com or LAN IP
touch eink_rotation_state.json
docker compose up -d
```

The Docker stack runs the image server behind a Traefik v3 reverse proxy on port 80. For HTTPS with Let's Encrypt, uncomment the marked lines in `docker-compose.yml` and set `ACME_EMAIL` in `.env`.

After starting, open `http://YOUR_SERVER_IP:8000/` (or your domain). The status page shows:

- Connected devices and their last-seen IP
- Battery voltage per device (if battery monitoring is enabled)
- Current image for each device
- Embedded schedule editors for global, default, and per-device overrides

### Step 12: Test the Display

Press **RESET** on the ESP32-S3-Nano. The device will:
1. Connect to WiFi
2. Sync time and schedule overrides from `/device_config`
3. Check `/hash` — download `/image_packed` only if the image changed
4. Refresh the display (20–30 seconds of flickering)
5. Enter deep sleep

**Congratulations!** Your e-ink display should be showing your image.

---

## Monitoring serial output

The ESP32 sends debug output over USB (115200 baud). Most useful for troubleshooting.

```bash
screen /dev/ttyACM0 115200
# or
cd firmware && uv run pio device monitor --port /dev/ttyACM0 --baud 115200
```

The USB serial device disappears during deep sleep. This loop reattaches on each wakeup:

```bash
cd firmware
while true; do
  uv run pio device monitor --port /dev/ttyACM0 --baud 115200
  sleep 1
done
```

### Normal operation output

```
========================================
Waveshare ESP32-S3-Nano + 13.3" HAT+ (E)
========================================
Boot count: 1

NORMAL OPERATION MODE

Battery: ADC=2413, voltage=4.21V
Connecting to WiFi: YourNetwork
Connected! IP: 192.168.x.y
Syncing device config from server...
Checking image hash at: http://192.168.x.y:8000/hash
Last known hash: (none)
Server hash: 942d3cfc05c8fa41
Image changed - will download new image
Fetching image from: http://192.168.x.y:8000/image_packed
Downloaded 960000 bytes in 10395 ms
Spectra6: Starting display refresh...
Spectra6: Refresh complete in 28432 ms
Entering deep sleep for 15 minutes...
```

When the image hasn't changed:
```
Server hash: 942d3cfc05c8fa41
Image unchanged - skipping download
Entering deep sleep for 15 minutes...
```

---

## Changing Settings Without Reflashing

### Entering Configuration Mode

1. Hold the **user button** (D2 → GND)
2. While holding it, press and release **RESET**
3. Keep holding for ~1 second, then release

The device will connect to WiFi and print its IP, or fall back to creating a hotspot called **"EInk-Setup"** (connect and go to `http://192.168.4.1`).

### Configurable settings

- **Server Host** — IP or domain name
- **Server Port** — default 8000
- **Image Endpoint** — default `/image_packed`
- **Refresh Interval** — minutes between wakeups
- **Active Start / End Hour** — local quiet-hours window
- **Timezone Offset** — minutes from UTC

Click **Save Configuration**, then **Reboot Device**.

---

## Multiple boards with different image collections

Each board is identified by its MAC address (sent via `X-Device-MAC` header on every request).

### Directory structure

```
images/
├── default/                    # Fallback for unknown devices
│   ├── image1.jpg
│   └── device_config.json      # Optional default schedule override
├── d0cf1326f7e8/               # Per-device directory (MAC, no separators)
│   ├── photo1.jpg
│   └── device_config.json      # Optional per-device schedule override
└── device_config.json          # Global schedule fallback
```

### Finding your board's MAC address

Enter configuration mode (hold D2 during reset). The **Device Info** section on the config page shows the MAC address. Use it (lowercase, no colons) as the directory name.

---

## Optional features

### Static IP

Skips DHCP on every wakeup (~200–500 ms saved). Uncomment and fill in `config.h`:

```cpp
#define STATIC_IP       "192.168.x.y"
#define STATIC_GATEWAY  "192.168.x.1"
#define STATIC_SUBNET   "255.255.255.0"
#define STATIC_DNS1     "192.168.x.1"
```

### Battery monitoring

The ESP32-S3-Nano has no on-board voltage divider. Wire your own between the battery rail and A0 (optionally switched by A1), then in `config.h`:

```cpp
#define BATTERY_MONITOR_ENABLED 1
#define BATTERY_SCALE  2.0f   // (R1 + R2) / R2 for your divider
```

Voltage is reported to the server via `X-Battery-Voltage` and shown on the status page:

| Voltage | Status |
|---------|--------|
| > 4.2 V | Full / USB power |
| 3.7 V   | ~50% |
| < 3.3 V | Low — charge soon |
| < 3.0 V | Empty |

### Development flags

Set these in `platformio.ini` `build_flags` (not in `config.h`):

- `-DDEV_DISABLE_DEEP_SLEEP` — replaces deep sleep with a delay + soft reboot so USB stays connected; combine with `-DDEV_LOOP_DELAY_SECONDS=30`
- `-DSIM_DISPLAY` — skips all SPI/GPIO/refresh calls so you can test the WiFi and download logic without stressing the panel

---

## Troubleshooting

### "No such file or directory: /dev/ttyACM0"

1. Try a different USB cable — charge-only cables are the most common cause
2. Press RESET — the device may be in deep sleep
3. Check the port name: `ls /dev/ttyACM*` (Linux) or `ls /dev/cu.usb*` (macOS)

### WiFi won't connect

- Network must be **2.4 GHz**
- Verify `config.h` has correct SSID and password, then reflash

### "HTTP GET failed, code: -1"

1. Confirm `image_server.py` is running (or the Docker container is up)
2. Check `DEFAULT_SERVER_HOST` in `config_manager.h` matches the server's IP
3. Firewall: allow port 8000
4. Test: `curl http://YOUR_SERVER_IP:8000/hash`

### Image updates feel slow

- Full panel refresh takes 20–30 seconds — this is normal for e-ink
- The server quantizes large source images on first access; subsequent requests use the cache
- HEIC files are slower to process than JPEG/PNG

### Image is rotated incorrectly

The server applies a 270° rotation for portrait-mounted displays (board at the bottom). Change the `img.rotate(270, ...)` call in `image_server.py` if your mount orientation differs.

---

## File Structure

```
seeed_eink_board/
├── README.md
├── image_server.py           # Flask server — image rotation, packed binary, schedule editor
├── Dockerfile                # Container image for the image server
├── docker-compose.yml        # Traefik reverse proxy + image server
├── .env.example              # Environment variable template for Docker
├── images/                   # Per-device image directories
│   ├── default/
│   └── <mac-address>/
├── device_config.json        # Global schedule fallback (optional)
├── firmware/
│   ├── platformio.ini        # Build config (board = arduino_nano_esp32)
│   ├── README.md
│   └── src/
│       ├── config.h.example  # Copy to config.h and fill in credentials
│       ├── config_manager.h  # Default server settings
│       ├── display.h/.cpp    # Spectra 6 dual-controller driver
│       ├── config_server.h/.cpp  # On-device web config UI
│       └── main.cpp          # WiFi, fetch, display, sleep, config mode
└── pyproject.toml
```

---

## How It Works

```
1.  ESP32 wakes from deep sleep
2.  (Optional) Read battery voltage via external divider on A0
3.  Connect to WiFi (DHCP or static IP)
4.  GET /device_config  — sync server epoch + optional schedule overrides
5.  If outside active window → sleep until active_start_hour
6.  GET /hash           — 16-char MD5, no rotation advance
7.  If hash matches stored hash → sleep (no download)
8.  GET /image_packed   — 960 KB packed 4bpp binary
9.  Write buffer to display via dual-controller SPI
10. Store new hash in RTC memory
11. Enter deep sleep for refresh_interval_minutes
12. Repeat
```

All requests carry `X-Device-MAC`; `X-Battery-Voltage` is added only when `BATTERY_MONITOR_ENABLED` is defined.

---

## Credits

- Firmware display driver inspired by [esphome-bigink](https://github.com/acegallagher/esphome-bigink)
