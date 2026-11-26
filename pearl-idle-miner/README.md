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
For `MODE=pergpu`: cgroup v2 and `bpftool` (Ubuntu: `linux-tools-common` + `linux-tools-$(uname -r)`) – without them the script falls
back to the env index, which can be wrong.
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
Vast starts every rental container with the NVIDIA runtime and `NVIDIA_VISIBLE_DEVICES` set to a GPU
index – but **that index does not always match the physical GPU**. On two 2-GPU hosts a container with
`NVIDIA_VISIBLE_DEVICES=1` was really on the GPU that `nvidia-smi` calls 0 (Vast's own occupancy view
agreed with the physical card, not with the env). An idle renter uses no VRAM, so nothing else shows it.

The reliable source is the container's **cgroup v2 device filter**: the eBPF program Docker attaches
lists exactly which `/dev/nvidiaN` (char major 195, minor N) the container may open. The script reads it
with `bpftool cgroup list` + `bpftool prog dump xlated` and maps minor N to a GPU via
`/proc/driver/nvidia/gpus/*/information` (Device Minor + PCI bus id). Only the host side is read –
nothing is run inside the renter's container.

A GPU counts as **busy** if any of these is true:
1. A running/paused/restarting container may open it according to its cgroup device filter.
2. Fallback when that cannot be decided (container only "created", no `bpftool`, a rule allowing all
   GPUs …): the container has it in `NVIDIA_VISIBLE_DEVICES` (index or UUID); `all`, empty or unknown
   values mark **every** GPU busy, and so do two containers claiming the same index.
3. There are as many GPU containers as GPUs – then **every** GPU is busy.
4. A process other than SRBMiner uses it (`nvidia-smi --query-compute-apps`, matched by PCI bus id).
5. More than `VRAM_BUSY_MIB` (default 100) MiB of its memory is in use while our miner is not running on it.

Extra safety:
- **Any** `docker create/start` still kills **all** miners and resets **all** clocks immediately,
  also in `MODE=pergpu`. Idle GPUs are only restarted after `IDLE_SEC` seconds without new events –
  except right after one of Vast's own test containers (`vastai/test*`) is destroyed: then they restart
  immediately. Vast runs its bandwidth test up to ~13 times an hour on an idle machine (~5 s each);
  this cut the downtime per test from ~22 s to ~7 s.
- SRBMiner runs with `CUDA_DEVICE_ORDER=PCI_BUS_ID`, so `--gpu-id N` is the same GPU as `nvidia-smi -i N`
  (CUDA's default ordering is "fastest first" and can differ from nvidia-smi).
- A guard checks every 2 s which GPU each SRBMiner process is actually running on (by PCI bus id).
  If one is on a GPU it was not started on, or on a busy GPU, all miners are stopped and it is logged.

Nothing else from the renter's container is read (only `NVIDIA_VISIBLE_DEVICES` and its cgroup device filter).

`MODE=pergpu` (mine on the idle GPU of a partly rented host) now runs on 17 hosts. It is still not the
default – test it on one host and watch `journalctl -t pearl-idle-miner` before rolling it out.

## Disclaimer
Use at your own risk. Check the terms of service of your marketplace before mining on hosted hardware.
The miner is stopped on every container start, but you are responsible for your hosts and renters.
SRBMiner-Multi includes a developer fee set by its author.

License: MIT.
