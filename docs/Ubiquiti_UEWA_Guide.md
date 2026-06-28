# Ubiquiti Enterprise Wireless Admin (UEWA) Advanced Guide

This guide serves as a comprehensive reference for UniFi enterprise wireless deployments, Layer-3 adoption architectures, and high-density WLAN optimizations based on the Ubiquiti Academy training program.

---

## 1. Wireless Fundamentals & Cell Planning

### Key Metrics:
- **EIRP (Equivalent Isotropically Radiated Power)**: The total radiated power leaving the AP antenna:
  $$\text{EIRP (dBm)} = \text{Transmit Power (dBm)} + \text{Antenna Gain (dBi)}$$
- **Signal-to-Noise Ratio (SNR)**: The difference between received signal strength (RSSI) and the noise floor:
  $$\text{SNR (dB)} = \text{Signal (dBm)} - \text{Noise Floor (dBm)}$$
- **SLA Requirements**: Signal levels of **`-50 dBm`** are considered excellent, while signals lower than **`-75 dBm`** are weak and lead to packet fragmentation and retransmissions. High-density networks require a minimum SNR of **`>=24 dB`** across all clients.

### Channel Planning:
- **2.4 GHz Band**: Only use non-overlapping channels **`1, 6, and 11`** at **`20 MHz`** channel width. Bandwidth bonding (HT40) should not be used on 2.4 GHz as it overlaps neighboring channels and increases Co-Channel Interference (CCI).
- **5 GHz Band**: Supports up to 24 non-overlapping channels. Keep channel widths at **`20 MHz`** (or max `40 MHz` with clean spectrum) to maximize channel reuse and reduce noise.

---

## 2. Layer-3 Device Adoption Blueprints
Layer-3 adoption allows UniFi controllers to manage devices across different subnets, routing domains, or public clouds.

### Method A: DHCP Option 43 (Recommended for Enterprise)
UniFi APs request Option 43 in their DHCP discovery packets. The DHCP server responds with the hex-encoded IP of the UniFi Controller.
- **Hex encoding format**: `0x01` (Sub-option ID) + `0x04` (Length of IP) + Hex representation of IP address bytes.
- **Example Calculation**: Controller IP = `192.0.2.10`
  - `192` = `C0`
  - `0`   = `00`
  - `2`   = `02`
  - `10`  = `0A`
  - Result Payload = `0x0104c000020a`
- **MikroTik RouterOS Config**:
  ```routeros
  /ip dhcp-server option add code=43 name=unifi-opt43 value=0x0104c000020a
  /ip dhcp-server network set [find address=192.0.2.0/24] dhcp-option=unifi-opt43
  ```

### Method B: DNS Hostname Adoption
UniFi APs attempt to resolve the default hostname `unifi` on boot. Pointing `unifi` to the controller IP on the local DNS server triggers adoption.
- **dnsmasq config**:
  ```hosts
  192.0.2.10  unifi
  ```

### Method C: SSH Manual set-inform
1. Establish SSH connection: `ssh ubnt@<ap_ip_address>` (default: `ubnt`/`ubnt`).
2. Run inform CLI:
   ```bash
   set-inform http://192.0.2.10:8080/inform
   ```
3. Adopt the device in the UniFi Controller UI.
4. **CRITICAL**: Re-run the set-inform command after adoption to complete the binding:
   ```bash
   set-inform http://192.0.2.10:8080/inform
   ```

---

## 3. High-Density (HD) WLAN Optimization

### A. Minimum RSSI Tuning
Prevents low-signal "sticky" clients from remaining connected to far-away APs, consuming unnecessary airtime:
- **Configuration**: Set Minimum RSSI threshold to **`-75 dBm`** (or `-80 dBm` for coverage scenarios) on the AP radios.
- **Mechanism**: The AP monitors client RSSI. If it drops below the threshold, the AP sends a de-authentication frame (soft kick). The client is forced to scan and associate with a closer AP.

### B. Airtime Fairness (ATF)
- Prevents slow/legacy clients (e.g. 802.11b/g) from consuming disproportionate amounts of airtime, which degrades performance for fast clients (802.11ac/ax).
- **Mechanism**: ATF divides the wireless channel time into equal slots, giving fast clients more capacity during their allocated time slot.

### C. Band Steering
- **Mechanism**: Detects dual-band client probe requests and actively steers 5 GHz-capable devices to the 5 GHz band. This leaves the 2.4 GHz band clear for legacy, long-range, or low-power IoT devices.
