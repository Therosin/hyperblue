# Hyperblue local development.
#
#   just build        # rootless: bluebuild build -> localhost/hyperblue:latest
#   just shell        # rootless: inspect the image you just built
#   just build-qcow2  # needs sudo: bootc-image-builder -> output/qcow2/disk.qcow2
#   just spawn-vm     # boot that disk image with systemd-vmspawn
#
# The image itself is always built by BlueBuild, exactly like CI does with
# .github/workflows/build.yml. Only the disk-image step needs root, because
# bootc-image-builder mounts loop devices.

image_name := "hyperblue"
recipe := "recipes/recipe.yml"
default_tag := "latest"
local_image := "localhost/" + image_name + ":" + default_tag
bib_image := "quay.io/centos-bootc/bootc-image-builder:latest"

[private]
default:
    @just --list

# Build the image locally with BlueBuild (rootless podman)
[group('Build')]
build push="0":
    #!/usr/bin/env bash
    set -euo pipefail
    cmd=(bluebuild build {{ recipe }})
    if [[ "{{ push }}" == "1" ]]; then
        cmd+=(--push)
    fi
    "${cmd[@]}"

# Validate the recipe without building
[group('Build')]
validate:
    bluebuild validate {{ recipe }}

# Render the Containerfile BlueBuild generates for the recipe
[group('Build')]
generate:
    bluebuild generate {{ recipe }} -o Containerfile
    echo "Wrote Containerfile"

# Open a shell in the locally built image
[group('Build')]
shell:
    #!/usr/bin/env bash
    set -euo pipefail
    podman image exists {{ local_image }} ||
        { echo "{{ local_image }} not found; run 'just build' first" >&2; exit 1; }
    exec podman run --rm -it --entrypoint /bin/bash {{ local_image }}

# Build the image and turn it into a qcow2 disk image (requires sudo)
[group('Build VM image')]
build-qcow2: (vm-image "qcow2" "disk_config/disk.toml")

# Build the image and turn it into a raw disk image (requires sudo)
[group('Build VM image')]
build-raw: (vm-image "raw" "disk_config/disk.toml")

# Rebuild the disk image without rebuilding the container image (requires sudo)
[group('Build VM image')]
rebuild-qcow2: (bib "qcow2" "disk_config/disk.toml")

# Rebuild the raw disk image without rebuilding the container image (requires sudo)
[group('Build VM image')]
rebuild-raw: (bib "raw" "disk_config/disk.toml")

# Run a virtual machine from the qcow2 disk image (qemux/qemu, browser console)
[group('Run VM')]
run-vm-qcow2: && (_run-vm "qcow2")

# Run a virtual machine from the raw disk image (qemux/qemu, browser console)
[group('Run VM')]
run-vm-raw: && (_run-vm "raw")

# Run a virtual machine with systemd-vmspawn
[group('Run VM')]
spawn-vm rebuild="0" type="qcow2" ram="6G" cpus="2" console="gui":
    #!/usr/bin/env bash
    set -euo pipefail
    image_file="output/{{ type }}/disk.{{ type }}"
    if [[ "{{ rebuild }}" == "1" || ! -f $image_file ]]; then
        just "rebuild-{{ type }}"
    fi
    exec systemd-vmspawn \
        -M "{{ image_name }}" \
        --console="{{ console }}" \
        --cpus="{{ cpus }}" \
        --ram="$(numfmt --from=iec {{ ram }})" \
        --network-user-mode \
        --vsock=false \
        --pass-ssh-key=false \
        -i "$image_file"

# Check that the recipe, Justfiles and shell scripts are well-formed
[group('Utility')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    bluebuild validate {{ recipe }}
    just --unstable --fmt --check -f Justfile
    if ! command -v shellcheck >/dev/null; then
        echo "shellcheck not found; install it to lint the shell scripts" >&2
        exit 1
    fi
    just _shell-scripts | xargs -r shellcheck

# Format the Justfile and shell scripts in place
[group('Utility')]
fix:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt -f Justfile
    if ! command -v shfmt >/dev/null; then
        echo "shfmt not found; install it to format the shell scripts" >&2
        exit 1
    fi
    just _shell-scripts | xargs -r shfmt --write

# Remove build artefacts and generated files
[group('Utility')]
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf _build* output build Containerfile
    podman rmi -f {{ local_image }} 2>/dev/null || true

# List the shell scripts tracked in git (used by check/fix)
[group('Utility')]
[private]
_shell-scripts:
    #!/usr/bin/env bash
    set -euo pipefail
    git ls-files '*.sh' 'config/files/usr/bin/*' 'config/files/usr/libexec/hyperblue/*' \
        | grep -v -e '\.png$' -e 'README' || true

# Put the locally built image in rootful podman, where bootc-image-builder can see it
[group('Utility')]
[private]
_load-rootful:
    #!/usr/bin/env bash
    set -euo pipefail
    sudoif() { if ((UID == 0)); then "$@"; else sudo "$@"; fi; }
    podman image exists {{ local_image }} ||
        { echo "{{ local_image }} not found; run 'just build' first" >&2; exit 1; }
    user_id=$(podman image inspect {{ local_image }} | jq -r '.[0].Id')
    root_id=$(sudoif podman image inspect {{ local_image }} 2>/dev/null | jq -r '.[0].Id' || true)
    if [[ $user_id == "$root_id" ]]; then
        exit 0
    fi
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    sudoif env TMPDIR="$work" podman image scp \
        "$(id -u)@localhost::{{ local_image }}" "root@localhost::{{ local_image }}"

[group('Utility')]
[private]
vm-image type config: build && (bib type config)

# Turn an image already in rootful podman into a bootable disk image
[group('Utility')]
[private]
bib type config:
    #!/usr/bin/env bash
    set -euo pipefail
    just _load-rootful
    out=$(mktemp -d ./_build-bib.XXXXXXXXXX)
    sudo podman run --rm --privileged --pull=newer --net=host \
        --security-opt label=type:unconfined_t \
        -v "$PWD/{{ config }}:/config.toml:ro" \
        -v "$out:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        {{ bib_image }} \
        --type {{ type }} --rootfs btrfs \
        {{ local_image }}
    mkdir -p output
    sudo mv -f "$out"/* output/
    sudo rmdir "$out"
    sudo chown -R "$(id -u):$(id -g)" output
    echo "Disk image: output/{{ type }}/disk.{{ type }}"

[group('Utility')]
[private]
_run-vm type:
    #!/usr/bin/env bash
    set -euo pipefail
    image_file="output/{{ type }}/disk.{{ type }}"
    if [[ ! -f $image_file ]]; then
        just "build-{{ type }}"
    fi
    port=8006
    while ss -tunalp | grep -q ":${port} "; do
        port=$((port + 1))
    done
    echo "Connect to http://localhost:${port}"
    (sleep 20 && xdg-open "http://localhost:${port}" >/dev/null 2>&1) &
    exec podman run --rm --privileged --pull=newer \
        --publish "127.0.0.1:${port}:8006" \
        --env "CPU_CORES=4" \
        --env "RAM_SIZE=8G" \
        --env "DISK_SIZE=64G" \
        --env "TPM=Y" \
        --env "GPU=Y" \
        --device=/dev/kvm \
        --volume "$PWD/${image_file}:/boot.{{ type }}" \
        docker.io/qemux/qemu
