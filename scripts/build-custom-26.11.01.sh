#!/usr/bin/env bash
# Build RR custom bootloader 26.11.01 from official 26.9.0 base image.
# Runs inside GitHub Actions ubuntu-latest as root. Produces and uploads the zip asset.
set -eu

VERSION="26.11.01"
BASE_VERSION="26.9.0"
VER_I915="1.6.18.56.261028.0"
I915_TAG="I915_6.18.56_LTS_261028.0"
I915_BASE="https://github.com/moetayuko/intel-gpu-i915-backports/releases/download/${I915_TAG}"
ASSET="rr26.11.01.img.zip"
WORKDIR="/root/rrbuild"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "===== [1/10] Download official base image ====="
curl -fL --retry 5 --retry-delay 3 -o "rr-${BASE_VERSION}.img.zip" \
  "https://github.com/RROrg/rr/releases/download/${BASE_VERSION}/rr-${BASE_VERSION}.img.zip"
unzip -q -o "rr-${BASE_VERSION}.img.zip"
ls -lh rr.img

echo "===== [2/10] Mount partitions by offset ====="
mkdir -p /mnt/rrp1 /mnt/rrp3
mount -o loop,offset=$((2048*512)) rr.img /mnt/rrp1
mount -o loop,offset=$((206848*512)) rr.img /mnt/rrp3
df -h /mnt/rrp1 /mnt/rrp3

echo "===== [3/10] Set version on p1 ====="
printf '%s' "${VERSION}" > /mnt/rrp1/RR_VERSION
cat /mnt/rrp1/RR_VERSION; echo

echo "===== [4/10] Patch initrd consts.sh ====="
rm -rf /tmp/rrinitrd && mkdir -p /tmp/rrinitrd
zstd -dc /mnt/rrp3/initrd-rr 2>/dev/null | cpio -idm -D /tmp/rrinitrd 2>/dev/null || true
sed -i "s/^RR_VERSION=.*/RR_VERSION=\"${VERSION}\"/" /tmp/rrinitrd/opt/rr/include/consts.sh
sed -i 's/^RR_RELEASE=.*/RR_RELEASE=""/' /tmp/rrinitrd/opt/rr/include/consts.sh
grep -E '^RR_VERSION|^RR_RELEASE' /tmp/rrinitrd/opt/rr/include/consts.sh
(cd /tmp/rrinitrd && find . -print0 2>/dev/null | cpio --null -o -H newc -R root:root 2>/dev/null | zstd -19 -T0 -f -c - > /tmp/initrd-rr.new) || true
cp /tmp/initrd-rr.new /mnt/rrp3/initrd-rr
ls -lh /mnt/rrp3/initrd-rr

echo "===== [5/10] Merge i915 modules into 16 platform packages ====="
PLATFORMS="epyc7002-7.1 epyc7002-7.2 epyc7002-7.3 epyc7002-7.4 epyc7003-7.4 epyc7003ntb-7.4 geminilakenk-7.2 geminilakenk-7.3 geminilakenk-7.4 icelaked-7.4 r1000nk-7.2 r1000nk-7.3 r1000nk-7.4 v1000nk-7.2 v1000nk-7.3 v1000nk-7.4"
for combo in ${PLATFORMS}; do
  modfile="${combo}-5.10.55.tgz"
  i915file="i915-dsm-${combo}-${VER_I915}.tar.gz"
  echo "-- ${combo}"
  curl -fL --retry 3 -o "${i915file}" "${I915_BASE}/${i915file}"
  w="modwork/${combo}"
  rm -rf "${w}" && mkdir -p "${w}"
  tar -xzf "/mnt/rrp3/modules/${modfile}" -C "${w}"
  t=$(mktemp -d)
  tar -xzf "${i915file}" -C "${t}"
  cp -f "${t}"/modules/*.ko "${w}"/
  rm -rf "${t}"
  (cd "${w}" && tar -czf "/tmp/${modfile}.new" .)
  cp "/tmp/${modfile}.new" "/mnt/rrp3/modules/${modfile}"
done

echo "===== [6/10] Merge i915 firmware ====="
rm -rf fwwork && mkdir -p fwwork
tar -xzf /mnt/rrp3/modules/firmware.tgz -C fwwork
curl -fL --retry 3 -o i915-fw.tar.gz "${I915_BASE}/i915-dsm-epyc7002-7.4-${VER_I915}.tar.gz"
t=$(mktemp -d)
tar -xzf i915-fw.tar.gz -C "${t}"
mkdir -p fwwork/i915
cp -f "${t}"/firmware/* fwwork/i915/
rm -rf "${t}"
(cd fwwork && tar -czf /tmp/firmware.tgz.new .)
cp /tmp/firmware.tgz.new /mnt/rrp3/modules/firmware.tgz

echo "===== [7/10] Replace hdddb with v3.7.140 ====="
curl -fL --retry 3 -o syno_hdd_db.sh \
  "https://raw.githubusercontent.com/007revad/Synology_HDD_db/v3.7.140/syno_hdd_db.sh"
curl -fL --retry 3 -o install.sh \
  "https://raw.githubusercontent.com/RROrg/rr-addons/main/hdddb/install.sh"
rm -rf hddwork && mkdir -p hddwork/root/usr/bin
cp install.sh hddwork/install.sh
cp syno_hdd_db.sh hddwork/root/usr/bin/hdddb.sh
grep -m1 'scriptver=' hddwork/root/usr/bin/hdddb.sh || true
(cd hddwork && tar -czf /tmp/hdddb-all.tgz .)
cp /tmp/hdddb-all.tgz /mnt/rrp3/addons/hdddb/all.tgz

echo "===== [8/10] Unmount ====="
sync
umount /mnt/rrp1 /mnt/rrp3

echo "===== [9/10] Package image and checksums ====="
mv rr.img "rr26.11.01.img"
zip -6 "${ASSET}" "rr26.11.01.img"
sha256sum "rr26.11.01.img" "${ASSET}" > "sha256sum-rr26.11.01.txt"
cat "sha256sum-rr26.11.01.txt"

echo "===== [10/10] Upload assets to release ====="
gh release upload "${VERSION}" \
  "${ASSET}" "sha256sum-rr26.11.01.txt" --clobber
echo "===== DONE ====="
