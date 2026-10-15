#!/usr/bin/env bash
# Caratterizzazione hardware completa - output confrontabile fra macchine
# Uso: sudo bash hw-report.sh > /tmp/hw-$(hostname).txt 2>&1
set -u
sep(){ printf '\n============================================================\n== %s\n============================================================\n' "$1"; }

sep "IDENTITA"
echo "hostname   : $(hostname)"
echo "data       : $(date -Is)"
echo "uptime     : $(uptime -p 2>/dev/null)"
cat /etc/os-release 2>/dev/null | grep -E '^(NAME|VERSION)='
echo "kernel     : $(uname -r)  arch: $(uname -m)"
echo "init       : $(ps -p1 -o comm=)"
[ -d /sys/firmware/efi ] && echo "boot       : UEFI" || echo "boot       : BIOS/Legacy"

sep "SISTEMA / MOTHERBOARD / BIOS"
dmidecode -t system   2>/dev/null | grep -E 'Manufacturer|Product Name|Version|Serial|UUID'
dmidecode -t baseboard 2>/dev/null | grep -E 'Manufacturer|Product Name|Version|Serial'
dmidecode -t bios     2>/dev/null | grep -E 'Vendor|Version|Release Date'

sep "CPU"
lscpu
echo "--- flags rilevanti ---"
grep -o -m1 -E 'vmx|svm|aes|avx2?|sse4_2' /proc/cpuinfo | sort -u | tr '\n' ' '; echo

sep "MEMORIA"
free -h
echo "--- banchi installati ---"
dmidecode -t memory 2>/dev/null | grep -E 'Size|Type:|Speed|Locator|Manufacturer|Part Number|Rank' | grep -v 'No Module'

sep "DISCHI"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL,ROTA,TRAN
echo "--- partizionamento ---"
fdisk -l 2>/dev/null | grep -E 'Disk /dev/|Disklabel|^/dev/'
echo "--- utilizzo ---"
df -hT -x tmpfs -x devtmpfs
echo "--- SMART ---"
for d in /dev/sd? /dev/nvme?n1; do
  [ -b "$d" ] || continue
  echo "### $d"
  smartctl -i -H "$d" 2>/dev/null | grep -E 'Model|Serial|Firmware|Capacity|Rotation|SMART overall|Sector'
  smartctl -A "$d" 2>/dev/null | grep -iE 'Power_On_Hours|Reallocated|Wear|Percentage_Used|Total_LBAs_Written'
done
echo "--- LVM / RAID ---"
pvs 2>/dev/null; vgs 2>/dev/null; lvs 2>/dev/null
cat /proc/mdstat 2>/dev/null
echo "--- fstab ---"
grep -vE '^\s*#|^\s*$' /etc/fstab
echo "--- swap ---"
swapon --show

sep "RETE"
ip -br a
echo "--- routing ---"
ip r
echo "--- MAC / driver / velocita ---"
for i in $(ls /sys/class/net | grep -v lo); do
  echo "### $i  mac=$(cat /sys/class/net/$i/address)  driver=$(basename $(readlink -f /sys/class/net/$i/device/driver 2>/dev/null) 2>/dev/null)"
  ethtool "$i" 2>/dev/null | grep -E 'Speed|Duplex|Link detected'
done
echo "--- DNS ---"
resolvectl status 2>/dev/null | grep -E 'DNS Servers|Current DNS' | head -5
cat /etc/resolv.conf 2>/dev/null | grep -v '^#'

sep "GPU / PCI"
lspci -nn | grep -iE 'vga|3d|display'
echo "--- PCI completo ---"
lspci -nn

sep "USB"
lsusb 2>/dev/null

sep "SOFTWARE RILEVANTE"
echo "--- servizi attivi ---"
systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}'
echo "--- porte in ascolto ---"
ss -tulpn 2>/dev/null
echo "--- firewall ---"
ufw status verbose 2>/dev/null
echo "--- docker ---"
docker ps -a 2>/dev/null || echo "docker assente"
echo "--- postgres / odoo ---"
systemctl list-units --no-pager --no-legend 2>/dev/null | grep -iE 'odoo|postgres'
ls -1 /etc/odoo* /opt/odoo* 2>/dev/null
sudo -u postgres psql -lAt 2>/dev/null | cut -d'|' -f1

sep "UTENTI"
getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1" uid="$3" home="$6" shell="$7}'

sep "PACCHETTI (conteggio + veeam)"
dpkg -l 2>/dev/null | grep -c '^ii'
dpkg -l 2>/dev/null | grep -iE 'veeam|blksnap'

sep "FINE"
