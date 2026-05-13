This branch (`waveshare-nano-hat`) targets a Waveshare **ESP32-S3-Nano** wired to a Waveshare **13.3" e-Paper HAT+ (E)** Spectra 6 display. The `main` branch is the original Seeed XIAO ePaper Display Board (EE02) port. The image-server is hardware-agnostic and shared by both.

The repo directory is still named `seeed_eink_board/` for historical reasons — not worth renaming.

References:
- ESP32-S3-Nano: https://www.waveshare.com/wiki/ESP32-S3-Nano
- HAT+ manual: https://www.waveshare.com/wiki/13.3inch_e-Paper_HAT+_(E)_Manual
- Waveshare reference driver: `../ESP32/EPD_13in3e.cpp` — our `display.cpp` init matches it byte-for-byte
- Arduino Nano ESP32 pin variant: https://github.com/espressif/arduino-esp32/blob/master/variants/arduino_nano_nora/pins_arduino.h

## Architecture

```
[Home Server]                  [ESP32-S3-Nano + 13.3" HAT+ (E)]
image_server.py                Arduino Firmware
      │                                │
      │◄──── GET /device_config ───────│ (sync time + schedule)
      │◄──── GET /hash ────────────────│ (change detection)
      │◄──── GET /image_packed ────────│ (960KB if hash changed)
      │                                │ Display → deep sleep
```

## Pin Mapping — HAT+ 10-pin cable → ESP32-S3-Nano

| HAT+ pin | Function     | Nano label | GPIO  |
|----------|--------------|------------|-------|
| VCC      | 3.3 V        | 3V3        | —     |
| GND      | GND          | GND        | —     |
| DIN      | SPI MOSI     | D11        | 38    |
| CLK      | SPI SCK      | D13        | 48    |
| CS_M     | Master CS    | D10        | 21    |
| CS_S     | Slave CS     | D9         | 18    |
| DC       | Data/Command | D8         | 17    |
| RST      | Reset        | D7         | 10    |
| BUSY     | Busy (in)    | D6         | 9     |
| PWR      | Power enable | D5         | 8     |

- BUSY: LOW = busy, HIGH = idle
- PWR: active-HIGH; driven LOW before deep sleep
- D2: user button (pull-up, hold during boot → config mode)
- A0/A1: optional external battery voltage divider (no on-board divider on this board)

## Display Details

1200×1600 dual UC8179-class controllers (master = top 600 rows, slave = bottom 600 rows after transpose). Buffer is 1600×1200 (960 000 bytes, 4 bpp, 2 px/byte). Image rotated 270° server-side for portrait-mounted display.

Spectra 6 hardware color codes: Black=0x00, White=0x01, Yellow=0x02, Red=0x03, Blue=0x05, Green=0x06

## Files

| File | Purpose |
|------|---------|
| `firmware/platformio.ini` | PlatformIO config (`board = arduino_nano_esp32`) |
| `firmware/src/config.h` | WiFi credentials + pin definitions (copy from `config.h.example`) |
| `firmware/src/config_manager.h` | NVS default server settings (host, port 8000, sleep, active hours) |
| `firmware/src/config_server.h/.cpp` | On-device web config UI |
| `firmware/src/display.h/.cpp` | Spectra 6 driver |
| `firmware/src/main.cpp` | WiFi, fetch, display, deep sleep, config mode |
| `image_server.py` | Flask server — image rotation, packed binary endpoint, schedule editor |
| `.eink_rotation_state.json` | Per-device rotation state (auto-generated, gitignored) |
| `Dockerfile` | Container image for the image server |
| `docker-compose.yml` | Traefik reverse proxy + image server |
| `.env.example` | Environment variable template for Docker deployment |

## Build Flags (`firmware/src/config.h`)

Standard use — just set `WIFI_SSID` / `WIFI_PASSWORD` and flash.

Optional flags:
- `BATTERY_MONITOR_ENABLED` — enable voltage reporting via `X-Battery-Voltage` header; requires external divider on A0. Set `BATTERY_SCALE = (R1+R2)/R2`.
- `STATIC_IP` / `STATIC_GATEWAY` / `STATIC_SUBNET` / `STATIC_DNS1` — skip DHCP, saves ~200–500 ms per wake
- `SIM_DISPLAY` — skip all SPI/GPIO/refresh (buffer still populated; good for server-side testing)
- `DEV_DISABLE_DEEP_SLEEP` — simulate sleep with a delay + soft reboot so USB stays connected; combine with `DEV_LOOP_DELAY_SECONDS=N`

Dev flags are best set via `platformio.ini` `build_flags` rather than editing `config.h`.

## Building & Flashing

```bash
cd firmware
cp src/config.h.example src/config.h   # fill in WIFI_SSID / WIFI_PASSWORD
pio run -t upload
```

## Image Server Endpoints

All endpoints accept `X-Device-MAC` (lowercase, no separators) to identify the device.

| Endpoint | Description |
|----------|-------------|
| `GET /image_packed` | 960 KB packed binary; advances rotation |
| `GET /hash` | 16-char MD5 of pending image (no state change) |
| `GET /device_config` | Server epoch + optional per-device schedule overrides |
| `GET /schedule` | Browser UI for schedule overrides |
| `POST /schedule/save` | Save a schedule override JSON |
| `POST /schedule/clear` | Delete a schedule override |
| `GET /current` | Rotation status JSON (all devices or one) |
| `GET /` | Status page with embedded schedule editors |

Schedule overrides live in `images/<mac>/device_config.json`, `images/default/device_config.json`, or `device_config.json` (global fallback). Keys: `refresh_interval_minutes`, `active_start_hour`, `active_end_hour`, `timezone_offset_minutes`.

## Multi-Device Image Directories

```
images/
├── default/            # fallback for unknown devices
├── d0cf1326f7e8/       # per-device (MAC, lowercase, no separators)
│   └── device_config.json   # optional per-device schedule override
└── device_config.json  # global schedule fallback
```

## Running the Server

```bash
uv sync
uv run python image_server.py    # http://0.0.0.0:8000
```

## Docker Deployment

```bash
cp .env.example .env              # set EINK_HOST=your.domain.com
touch eink_rotation_state.json
mkdir -p images/default
docker compose up -d
```

The compose stack runs the image server behind a Traefik v3 reverse proxy on port 80. HTTPS/Let's Encrypt and static IP options are commented in the respective files. The image server is not exposed directly — only Traefik's port 80 (and optionally 443) is published. Single gunicorn worker prevents concurrent state-file writes.
