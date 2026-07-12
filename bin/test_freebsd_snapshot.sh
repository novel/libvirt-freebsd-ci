#!/bin/sh

set -e

FREEBSD_VERSION="${FREEBSD_VERSION:-16.0-CURRENT}"
IMG_NAME="FreeBSD-${FREEBSD_VERSION}-amd64-zfs.qcow2"
VM_NAME="freebsd16-current"
MOUNT_BASE="/mnt/freebsd"

CUR_DIR=$(dirname "${0}")

prepare_host() {
  modprobe nbd max_part=8
  modprobe zfs
}

download_image() {
  echo "Downloading the latest snapshot..."

  test -f "${IMG_NAME}" && rm -f "${IMG_NAME}"
  test -f "${IMG_NAME}.xz" && rm -f "${IMG_NAME}.xz"

  case "${FREEBSD_VERSION}" in
    *-CURRENT|*-STABLE)
      BASE_URL="https://download.freebsd.org/snapshots/VM-IMAGES/${FREEBSD_VERSION}/amd64/Latest"
      ;;
    *)
      BASE_URL="https://download.freebsd.org/releases/VM-IMAGES/${FREEBSD_VERSION}/amd64/Latest"
      ;;
  esac      
  wget "${BASE_URL}/${IMG_NAME}.xz"
  unxz "${IMG_NAME}.xz"
}

resize_image() {
  echo "Resizing image..."
  qemu-img resize "${IMG_NAME}" 15G
}

prepare_image() {
  echo "Preparing image..."
  qemu-nbd --connect=/dev/nbd0 "${IMG_NAME}"

  while test ! -b /dev/nbd0p4; do sleep 0.5; done
  zpool import -d /dev/nbd0p4 -R "${MOUNT_BASE}" zroot
  zfs mount zroot/ROOT/default
  zfs mount -a
  cat >> "${MOUNT_BASE}/boot/loader.conf" <<EOF
boot_multicons="YES"
boot_serial="YES"
console="comconsole"
vmm_load="YES"
nmdm_load="YES"
hw.vmm.vmx.use_apic_vid=0
EOF
  sed -i -E "s/hostname=\".+\"/hostname=\"${VM_NAME}\"/" "${MOUNT_BASE}/etc/rc.conf"
  echo 'sshd_enable="YES"' >> "${MOUNT_BASE}/etc/rc.conf"
  sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' "${MOUNT_BASE}/etc/ssh/sshd_config"
  sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' "${MOUNT_BASE}/etc/ssh/sshd_config"
  sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' "${MOUNT_BASE}/etc/ssh/sshd_config"
  sed -i -E 's/(pam_unix\.so.*)/\1 nullok/' "${MOUNT_BASE}/etc/pam.d/sshd"

  zfs unmount zroot/ROOT/default
  zfs unmount -a
  zpool export zroot
  qemu-nbd --disconnect /dev/nbd0
}

install_image() {
  echo "Installing image..."
  test -n "${IMG_NAME}"
  test -f "/var/lib/libvirt/images/${IMG_NAME}" && rm -f "/var/lib/libvirt/images/${IMG_NAME}"
  mv "${IMG_NAME}" "/var/lib/libvirt/images/"
}

create_vm() {
   echo "Creating VM..."
  virsh destroy "${VM_NAME}" 2>/dev/null || true
  virsh undefine "${VM_NAME}" 2>/dev/null || true

  virt-install \
    --name "${VM_NAME}" \
    --memory 8192 \
    --vcpus 4 \
    --disk "/var/lib/libvirt/images/${IMG_NAME},format=qcow2" \
    --import \
    --os-variant freebsd14.0 \
    --network bridge=virbr0,model=virtio \
    --graphics vnc \
    --serial pty \
    --console pty,target_type=serial \
    --noautoconsole 
}

bootstrap_vm() {
  echo "Waiting for VM to get an IP..."
  MAC=$(virsh domiflist "${VM_NAME}" | awk '/virbr0/ {print $5}')
  IP=""
  while [ -z "${IP}" ]; do
    sleep 2
    IP=$(virsh net-dhcp-leases default --mac "${MAC}" 2>/dev/null \
        | awk "/${VM_NAME}/ {print \$5}" | cut -d'/' -f1)
  done
  echo "VM is up at ${IP}"

  echo "Waiting for SSH to become available at ${IP}..."
  while ! ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    -o ConnectTimeout=2 root@"${IP}" true 2>/dev/null; do
    sleep 2
  done
  echo "SSH is up"

  SSH="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@${IP}"
  ${SSH} "ASSUME_ALWAYS_YES=yes IGNORE_OSVERSION=yes pkg update -f"
  ${SSH} "pkg install -y bastille"
  ${SSH} "bastille setup -y"
  ${SSH} "service pf start"
  ${SSH} "bastille bootstrap ${FREEBSD_VERSION}"
  # iasl is needed for bhyve!
  ${SSH} "cp /usr/sbin/iasl //usr/local/bastille/releases/${FREEBSD_VERSION}/usr/sbin/"
  ${SSH} "mkdir /usr/local/bastille/templates/novel"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${CUR_DIR}/devfs.rules" root@${IP}:/etc/
  scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${CUR_DIR}/libvirt-tck-git/" root@${IP}:/usr/local/bastille/templates/novel
}

run_tests() {
  ${SSH} "bastille create -V testrunnergit ${FREEBSD_VERSION} DHCP vtnet0"
  ${SSH} "bastille template testrunnergit novel/libvirt-tck-git"
  ${SSH} 'bastille cmd testrunnergit sh -c "cd /root/libvirt-tck && avocado --config avocado.config  run --xunit ./scripts/domain/*.t ./scripts/storage/*.t ./scripts/networks/*.t ./scripts/hooks/*.t" || true'
}

prepare_host
download_image
resize_image
prepare_image
install_image
create_vm
bootstrap_vm
run_tests
