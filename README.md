# Working Container

A long-lived, SSH-accessible development container that gives each developer a personal "working VM" on a shared GPU host. It ships a full CUDA toolchain, GPU passthrough, a working Docker-in-Docker daemon, and a per-user setup script, so a developer can `ssh` in and immediately build, run containers, and train on the host's GPUs.

# Features

- **CUDA base image** — built on `nvidia/cuda:13.0.2-cudnn-devel-ubuntu24.04` (unminimized), so compilers, headers, and cuDNN are available out of the box.
- **GPU passthrough** — the host's NVIDIA devices are exposed directly to the container, and `nvidia-container-toolkit` is installed *inside* it so nested containers can request GPUs too.
- **Docker-in-Docker** — a full Docker CE install (with buildx and compose) runs under supervisor; `/var/lib/docker` is declared as a `VOLUME` (ext4-backed, required for DinD) and cgroup v2 nesting is enabled at startup.
- **SSH entry point** — `sshd` runs under supervisor alongside `dockerd` (supervisord is PID 1, so `docker stop` shuts both down cleanly) and port `22` is exposed; map it to a per-user host port so each developer gets their own entry point.
- **Extra exposed port range** — a block of host ports is published per container for dev servers, notebooks, and ad-hoc services started inside.
- **Persistent home** — `/home` is bind-mounted from the host, so user data survives container recreation and image upgrades.
- **Per-user provisioning** — `setup-scripts/create-user.sh` creates the account, adds it to `docker` and `sudo`, and installs [uv](https://docs.astral.sh/uv/) and [nvm](https://github.com/nvm-sh/nvm) (Node 22 LTS) in the user's shell.
- **Preinstalled dev toolchain** — `build-essential`, `cmake`, `git`, `tmux`/`byobu`, `ffmpeg`, `jq`, `rsync`, `vim`/`nano`, plus common networking utilities (`dnsutils`, `net-tools`, `netcat`, `ping`).

# Security model

Every user of these containers must be trusted as much as `root` on the host. Docker-in-Docker requires `--privileged`, which disables the isolation between the container and the host (all capabilities, all devices, no seccomp/AppArmor profile), and each developer is `root`-equivalent inside their container via `sudo` and the `docker` group. A developer can therefore escape to the host, read other users' bind-mounted homes, and reach every other container. This is fine for a trusted team sharing a workstation; it is not a multi-tenant isolation boundary.

# Setup

The build context is the directory holding the Dockerfile and the two script folders.

```
working-container/
├── Dockerfile
├── image-scripts/
│   ├── logger.sh          # log helpers sourced by startup.sh
│   ├── modprobe           # modprobe shim, needed by dockerd in DinD
│   ├── startup.sh         # entrypoint: enables cgroup v2 nesting, execs supervisord as PID 1
│   └── supervisor/
│       ├── dockerd.conf   # supervisor program definition for dockerd
│       └── sshd.conf      # supervisor program definition for sshd
└── setup-scripts/
    └── create-user.sh     # per-user provisioning, run after the container is up
```

Build the image.

```bash
docker build . \
  --platform linux/amd64 \
  -f Dockerfile \
  -t working-vm:1.0
```

Run one container per developer. `--privileged` is required for Docker-in-Docker, and the host needs the NVIDIA container runtime installed. Pick a unique SSH port and port range per user, and adjust the `--device` list, `--shm-size`, and GPU flags to the host.

```bash
user=<user>
port_ssh=18022
port_range="18023-18099"

docker run \
  --privileged \
  --name working-vm-${user}-1.0 \
  -p ${port_ssh}:22 -p "${port_range}:${port_range}" \
  --runtime=nvidia \
  --gpus all \
  --device=/dev/nvidia-uvm \
  --device=/dev/nvidia-uvm-tools \
  --device=/dev/nvidia-modeset \
  --device=/dev/nvidiactl \
  --device=/dev/nvidia0 \
  --device=/dev/nvidia1 \
  --tmpfs /tmp:exec \
  --shm-size=63gb \
  -v /home/working-vms/${user}/:/home/ \
  --restart unless-stopped \
  -d working-vm:1.0
```

Optionally cap the resources each container can consume by adding `--memory=63gb --cpus=32`.

Create the developer's account inside the running container.

```bash
docker exec -it working-vm-${user}-1.0 bash /root/setup-scripts/create-user.sh ${user}
```

They can then connect over SSH on the port you published.

```bash
ssh -p ${port_ssh} ${user}@<host>
```
