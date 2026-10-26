# Docker on the A98Max+ (Armbian, kernel 6.12.64)

The Android kernel on this box cannot run Docker (no `PID_NS`, `MEMCG`, `CGROUP_DEVICE`, `CGROUP_PIDS`, `USER_NS`, ...). The Armbian kernel can. Tested on the
unit described in the README, 2 GB RAM, root on an SD card.

## What was checked first

In `/boot/config-6.12.64-current-sunxi64` every option on this list was `=y` or `=m`: namespaces (`PID/NET/IPC/UTS/USER`), `CGROUPS` with `PIDS`, `DEVICE`,
`CPUACCT`, `SCHED`, `MEMCG`, `CPUSETS`, `OVERLAY_FS`, `VETH`, `BRIDGE`, `BRIDGE_NETFILTER`, `NF_NAT`, `IP_NF_NAT`, `IP_NF_TARGET_MASQUERADE`,
`NETFILTER_XT_MATCH_ADDRTYPE`, `NETFILTER_XT_MATCH_CONNTRACK`, `SECCOMP_FILTER`, `POSIX_MQUEUE`. The system uses cgroup v2 with controllers
`cpuset cpu io memory hugetlb pids rdma`.

## Install (Docker's official apt repository, Debian bookworm, arm64)

```bash
sudo apt-get update && sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg iptables   # the image ships no iptables
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /tmp/docker.asc
gpg --show-keys --with-fingerprint /tmp/docker.asc      # must show 9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
sudo install -m 0644 /tmp/docker.asc /etc/apt/keyrings/docker.asc
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Installed: Docker Engine 29.9.2, Compose v5.6.1 (`docker info`: storage driver `overlayfs`, cgroup driver `systemd`, cgroup version 2). Both `docker` and `containerd` are enabled at boot.

## What was tested

```bash
docker run --rm hello-world                                                   # prints "Hello from Docker!"
docker run --rm --memory=64m --pids-limit=50 --cpus=0.5 alpine \
     sh -c 'cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/pids.max'                  # 67108864 and 50: limits are enforced
docker run --rm alpine wget -q -O- https://deb.debian.org/debian/dists/bookworm/InRelease | head -2   # NAT to the Internet works
```

Not tested: GPU/hardware video, `--network host` performance, long-running workloads, multi-container compose stacks, Docker on a 5 GHz-only link.

## Caveats

* **2 GB RAM** is shared with the kernel and zram; keep to a few light containers. 32-bit userspace images are fine, but arm64 images are the normal case here.
* **The SD card wears out.** `/var/lib/docker` lives on it. Container logs are unlimited by default; consider
  `/etc/docker/daemon.json` with `{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}` (not applied in the tested unit).
* Members of the `docker` group are root-equivalent (they can mount the host filesystem into a container). Armbian's first-login script creates that group
  and **adds the first user you create to it**, so on the tested unit that user already runs `docker` without `sudo`. If that is not what you want:
  `sudo gpasswd -d YOURUSER docker`.
* The kernel is pinned (the Wi-Fi modules are built for exactly 6.12.64): do not `armbian-upgrade` the kernel without rebuilding them.
