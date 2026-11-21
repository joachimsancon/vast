# pearl-idle-miner

Mine **Pearl (PRL)** with [SRBMiner-Multi](https://github.com/doktor83/SRBMiner-Multi) on a
**Vast.ai host only while its GPUs are idle** – and get out of the way instantly when a renter
(or one of Vast's own tests) starts a container.

- Starts mining after the host has been completely idle for 20 s (no containers, no other GPU processes)
- Watches Docker events: any `docker create/start` **kills the miner and resets GPU clocks in ~0.3 s**,
  before the renter's container uses the GPU
- Locks GPU core/memory clocks **only while its own miner runs** – renters always get a stock GPU
- Multi-GPU aware (one SRBMiner per GPU); default `MODE=all` only mines when *all* GPUs are idle
- Always runs the **latest SRBMiner** release from GitHub, verified against GitHub's SHA256 digest
- Runs the miner as an unprivileged user; logs per GPU in `/var/log/srbminer-gpuN.log`

## Why not Vast's built-in "default job" (idle job)?
It works, but while a default job runs, **the machine disappeared from the "available" search in the
Vast console** in our tests (it still showed as rentable in the API). That costs rentals. Running the
miner on the host keeps the machine looking completely idle. Vast skips its periodic bandwidth test while
a default job runs; with this script the tests still run – the miner simply stops for them.

## Install
```bash
git clone https://github.com/joachimsancon/vast.git
cd vast/pearl-idle-miner
sudo ./install.sh
sudo nano /etc/pearl-idle-miner.conf      # set WALLET (and clocks)
sudo systemctl enable --now pearl-idle-miner
```
Requirements: Linux host with NVIDIA driver (`nvidia-smi`), Docker, `curl`, `sha256sum`, systemd.
Tested on Ubuntu 22.04/24.04 Vast hosts.

## Logs
```bash
tail -F /var/log/srbminer-gpu0.log          # miner console (use -F, the file is recreated on restart)
journalctl -t pearl-idle-miner -f           # start/stop events and reasons
```

## Tuning (locked clocks, memory at 810 MHz, SRBMiner 3.8.9, PearlHash)
Efficiency matters more than raw hashrate when electricity costs money. Measured on our hosts:

| GPU | Core clock | Power | Hashrate | TH/W |
|---|---|---|---|---|
| RTX 4070 Ti Super | 2100 MHz | 109 W | 141 TH/s | **1.30** |
| RTX 4060 Ti | 2300 MHz | 81 W | 80 TH/s | 0.99 |
| RTX 4060 Ti | 2100 MHz | 65 W | 73 TH/s | 1.12 |
| RTX 4060 Ti | 1800 MHz | 54 W | 62 TH/s | **1.15** |
| RTX 3060 | 1600 MHz | 85 W | 46 TH/s | 0.54 |
| RTX 3060 | 1100 MHz | 43 W | 31 TH/s | **0.73** |
| RTX 3060 | 900 MHz | 34 W | 26 TH/s | 0.75 |

Notes: on RTX 50-series the memory clock lock made no measurable power difference. GTX 10/16-series
are not worth it for Pearl. Change `LGC`/`LMC` in the config – it is picked up live.

## How it decides a GPU is busy
A GPU is busy if a running container has it in `NVIDIA_VISIBLE_DEVICES` (index, UUID or `all`), or if
any process other than SRBMiner is using it (`nvidia-smi --query-compute-apps`). Nothing else from the
renter's container is read.

## Disclaimer
Use at your own risk. Check the terms of service of your marketplace before mining on hosted hardware.
The miner is stopped on every container start, but you are responsible for your hosts and renters.
SRBMiner-Multi includes a developer fee set by its author.

License: MIT.
