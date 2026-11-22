#!/usr/bin/env bash
# Build RR custom bootloader 26.11.01 from official 26.9.0 base image.
# Runs inside GitHub Actions ubuntu-latest as root.
set -euo pipefail

VERSION="26.11.01"
BASE_VERSION="26.9.0"
VER_I915="1.6.18.56.261028.0"
I915_TAG="I915_6.18.56_LTS_261028.0"
I915_BASE="https://github.com/moetayuko/intel-gpu-i915-backports/releases/download/${I915_TAG}"
ASSET="rr-${VERSION}.img.zip"
IMG_NAME="rr-${VERSION}.img"
WORKDIR="/root/rrbuild"

log() { echo "===== $* ====="; }

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

log "[1/10] Download official base image"
curl -fL --retry 5 --retry-all-errors --retry-delay 3 -o "rr-${BASE_VERSION}.img.zip" \
  "https://github.com/RROrg/rr/releases/download/${BASE_VERSION}/rr-${BASE_VERSION}.img.zip"
unzip -q -o "rr-${BASE_VERSION}.img.zip"
ls -lh rr.img

log "[2/10] Attach loop with partscan and mount partitions"
LOOP=$(losetup -fP --show rr.img)
echo "loop device: ${LOOP}"
partprobe "${LOOP}" 2>/dev/null || true
for i in $(seq 1 10); do
  [ -b "${LOOP}p3" ] && break
  sleep 1
done
ls -l "${LOOP}"p* 2>/dev/null || true
[ -b "${LOOP}p1" ] && [ -b "${LOOP}p3" ] || { echo "ERROR: partition devices not found"; exit 1; }
mkdir -p /mnt/rrp1 /mnt/rrp3
mount "${LOOP}p1" /mnt/rrp1
mount "${LOOP}p3" /mnt/rrp3
df -h /mnt/rrp1 /mnt/rrp3

log "[3/10] Set version on p1"
printf '%s' "${VERSION}" > /mnt/rrp1/RR_VERSION
cat /mnt/rrp1/RR_VERSION; echo

log "[4/10] Patch initrd consts.sh"
rm -rf /tmp/rrinitrd && mkdir -p /tmp/rrinitrd
zstd -dc /mnt/rrp3/initrd-rr | cpio -idm -D /tmp/rrinitrd >/dev/null 2>&1 || true
[ -f /tmp/rrinitrd/opt/rr/include/consts.sh ] || { echo "ERROR: consts.sh not extracted"; exit 1; }
sed -i "s/^RR_VERSION=.*/RR_VERSION=\"${VERSION}\"/" /tmp/rrinitrd/opt/rr/include/consts.sh
sed -i 's/^RR_RELEASE=.*/RR_RELEASE=""/' /tmp/rrinitrd/opt/rr/include/consts.sh
grep -E '^RR_VERSION|^RR_RELEASE' /tmp/rrinitrd/opt/rr/include/consts.sh
cp /mnt/rrp3/initrd-rr /tmp/initrd-rr.orig
(cd /tmp/rrinitrd && find . -print0 2>/dev/null | cpio --null -o -H newc -R root:root 2>/dev/null | zstd -19 -T0 -f -c - > /tmp/initrd-rr.new) || true
[ -s /tmp/initrd-rr.new ] || { echo "ERROR: initrd repack failed"; exit 1; }
cp /tmp/initrd-rr.new /mnt/rrp3/initrd-rr
ls -lh /tmp/initrd-rr.orig /mnt/rrp3/initrd-rr

log "[5/10] Merge i915 modules into 16 platform packages"
PLATFORMS="epyc7002-7.1 epyc7002-7.2 epyc7002-7.3 epyc7002-7.4 epyc7003-7.4 epyc7003ntb-7.4 geminilakenk-7.2 geminilakenk-7.3 geminilakenk-7.4 icelaked-7.4 r1000nk-7.2 r1000nk-7.3 r1000nk-7.4 v1000nk-7.2 v1000nk-7.3 v1000nk-7.4"
for combo in ${PLATFORMS}; do
  modfile="${combo}-5.10.55.tgz"
  i915file="i915-dsm-${combo}-${VER_I915}.tar.gz"
  [ -f "/mnt/rrp3/modules/${modfile}" ] || { echo "ERROR: missing ${modfile}"; exit 1; }
  curl -fL --retry 5 --retry-all-errors --retry-delay 2 -o "${i915file}" "${I915_BASE}/${i915file}"
  w="modwork/${combo}"
  rm -rf "${w}" && mkdir -p "${w}"
  tar -xzf "/mnt/rrp3/modules/${modfile}" -C "${w}"
  t=$(mktemp -d)
  tar -xzf "${i915file}" -C "${t}"
  [ -d "${t}/modules" ] || { echo "ERROR: no modules dir in ${i915file}"; exit 1; }
  cp -f "${t}"/modules/*.ko "${w}"/
  rm -rf "${t}"
  (cd "${w}" && tar -czf "/tmp/${modfile}.new" .)
  cp "/tmp/${modfile}.new" "/mnt/rrp3/modules/${modfile}"
  echo "-- ${combo} OK"
done

log "[6/10] Merge i915 firmware"
rm -rf fwwork && mkdir -p fwwork
tar -xzf /mnt/rrp3/modules/firmware.tgz -C fwwork
curl -fL --retry 5 --retry-all-errors --retry-delay 2 -o i915-fw.tar.gz "${I915_BASE}/i915-dsm-epyc7002-7.4-${VER_I915}.tar.gz"
t=$(mktemp -d)
tar -xzf i915-fw.tar.gz -C "${t}"
mkdir -p fwwork/i915
cp -f "${t}"/firmware/* fwwork/i915/
rm -rf "${t}"
(cd fwwork && tar -czf /tmp/firmware.tgz.new .)
cp /tmp/firmware.tgz.new /mnt/rrp3/modules/firmware.tgz

log "[7/10] Replace hdddb with v3.7.140"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 -o syno_hdd_db.sh \
  "https://raw.githubusercontent.com/007revad/Synology_HDD_db/v3.7.140/syno_hdd_db.sh"
curl -fL --retry 5 --retry-all-errors --retry-delay 2 -o install.sh \
  "https://raw.githubusercontent.com/RROrg/rr-addons/main/hdddb/install.sh"
grep -m1 'scriptver=' syno_hdd_db.sh
rm -rf hddwork && mkdir -p hddwork/root/usr/bin
cp install.sh hddwork/install.sh
cp syno_hdd_db.sh hddwork/root/usr/bin/hdddb.sh
(cd hddwork && tar -czf /tmp/hdddb-all.tgz .)
cp /tmp/hdddb-all.tgz /mnt/rrp3/addons/hdddb/all.tgz
ls -lh /mnt/rrp3/addons/hdddb/all.tgz

log "[8/10] Unmount"
sync
umount /mnt/rrp1 /mnt/rrp3
losetup -d "${LOOP}"

log "[9/10] Package image and checksums"
mv rr.img "${IMG_NAME}"
zip -6 "${ASSET}" "${IMG_NAME}"
sha256sum "${IMG_NAME}" "${ASSET}" > "sha256sum-${VERSION}.txt"
cat "sha256sum-${VERSION}.txt"

log "[10/10] Upload assets to release"
cd "${GITHUB_WORKSPACE:-.}"
gh release upload "${VERSION}" "${WORKDIR}/${ASSET}" "${WORKDIR}/sha256sum-${VERSION}.txt" --repo nanxi9899/rr --clobber
echo "===== DONE ====="
