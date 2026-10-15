#!/usr/bin/env bash
# =============================================================================
#  hw-report.sh  -  censimento hardware di UNA macchina Linux
#  Parte di windows-status, cartella scripts/censimento. Vedi docs/15.
# =============================================================================
#  COSA FA. Legge l'hardware e la configurazione di base della macchina su cui
#  gira e scrive un testo con le stesse sezioni, con gli stessi nomi e nello
#  stesso ordine, del gemello hw-report-windows.ps1: due macchine di famiglie
#  diverse si affiancano sezione per sezione.
#
#  CENSIRE NON E' FOTOGRAFARE. Il censimento guarda molte macchine una volta
#  sola, con un file solo e senza installare niente; lo snapshot del progetto
#  guarda una macchina molte volte e ne tiene lo storico. Sono due mestieri
#  diversi e qui si fa il primo.
#
#  QUALSIASI LINUX. Nessuna distribuzione e' data per scontata: gestore di
#  pacchetti, gestore dei servizi e firewall vengono riconosciuti al volo, e
#  ogni comando assente lascia la sua riga vuota invece di fermare il giro.
#
#  ANONIMO PER DEFAULT. Seriali, UUID, hostname e nomi utente escono come
#  pseudonimi stabili; i MAC conservano le prime tre coppie, cioe' il
#  produttore; gli IPv4 conservano la rete e perdono l'ultimo numero. Lo stesso
#  valore sulla stessa macchina da' sempre lo stesso pseudonimo, quindi due
#  censimenti restano confrontabili. Con --identificativi esce tutto in chiaro:
#  quell'output contiene dati reali e non va mai dentro un repository.
#
#  SOLA LETTURA. Non installa e non modifica niente. Senza root mancano i dati
#  SMBIOS (dmidecode) e lo SMART dei dischi: l'intestazione lo dichiara.
#
#  USO
#    sudo bash hw-report.sh
#    sudo bash hw-report.sh --label SRV-03 --out /var/tmp/censimento
#    sudo bash hw-report.sh --identificativi --out ./hw-reale.txt
#    sudo bash hw-report.sh --sections CPU,MEMORIA,DISCHI --stdout
#    sudo bash hw-report.sh --software --pattern 'postgres|nginx'
#    bash hw-report.sh --list
# =============================================================================

set -u

VERSIONE="2.0"
TUTTE="IDENTITA SISTEMA CPU MEMORIA DISCHI RETE GPU PERIFERICHE ALIMENTAZIONE"

DESTINAZIONE=""
VERSO_SCHERMO=0
ETICHETTA=""
ANONIMO=1
SALE="censimento"
SEZIONI=""
SOFTWARE=0
PATTERN=""

aiuto() {
  sed -n '3,36p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
}

elenco_sezioni() {
  echo "Sezioni del censimento, ordine fisso e comune a hw-report-windows.ps1:"
  for s in $TUTTE; do echo "  $s"; done
  echo "  SOFTWARE        solo con --software"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --out|-o)          DESTINAZIONE="${2:-}"; shift 2 ;;
    --stdout)          VERSO_SCHERMO=1; shift ;;
    --label|-l)        ETICHETTA="${2:-}"; shift 2 ;;
    --identificativi)  ANONIMO=0; shift ;;
    --salt)            SALE="${2:-}"; shift 2 ;;
    --sections|-s)     SEZIONI="$(echo "${2:-}" | tr ',a-z' ' A-Z')"; shift 2 ;;
    --software)        SOFTWARE=1; shift ;;
    --pattern|-p)      PATTERN="${2:-}"; shift 2 ;;
    --list)            elenco_sezioni; exit 0 ;;
    --help|-h)         aiuto; exit 0 ;;
    *) echo "Opzione non riconosciuta: $1 (--help per l'uso)" >&2; exit 2 ;;
  esac
done

[ -z "$SEZIONI" ] && SEZIONI="$TUTTE"
if [ "$SOFTWARE" -eq 1 ]; then
  case " $SEZIONI " in *" SOFTWARE "*) : ;; *) SEZIONI="$SEZIONI SOFTWARE" ;; esac
fi

for s in $SEZIONI; do
  case " $TUTTE SOFTWARE " in
    *" $s "*) : ;;
    *) echo "Sezione non riconosciuta: $s (--list per vederle)" >&2; exit 2 ;;
  esac
done

usa() { case " $SEZIONI " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
ha()  { command -v "$1" >/dev/null 2>&1; }
root() { [ "$(id -u)" -eq 0 ]; }

if root; then PRIVILEGI="root (censimento completo)"
else PRIVILEGI="utente standard (PARZIALE: mancano SMBIOS e SMART)"; fi

# --- anonimizzazione ---------------------------------------------------------

# Valori che non identificano nessuno: li scrivono i produttori quando il campo
# e' rimasto vuoto in fabbrica.
# In coda i nomi di account generici: non identificano nessuno, e sostituirli
# sfigurerebbe le etichette italiane di questo stesso censimento (un account
# chiamato utente colpirebbe la parola "utente").
INUTILI="to be filled by o.e.m.|default string|none|n/a|not specified|not available|system serial number|base board serial number|chassis serial number|0123456789|unknown|standard|utente|utenti|user|users|admin|administrator|amministratore|guest|ospite|public|default|sistema|system|root|nobody"

VAL=""   # valori reali, uno per riga
PSE=""   # pseudonimi corrispondenti, uno per riga

pseudonimo() { # $1 valore, $2 tipo
  local h=""
  if   ha sha256sum; then h="$(printf '%s' "$SALE|$2|$1" | sha256sum | cut -c1-8)"
  elif ha md5sum;    then h="$(printf '%s' "$SALE|$2|$1" | md5sum    | cut -c1-8)"
  elif ha cksum;     then h="$(printf '%s' "$SALE|$2|$1" | cksum | awk '{printf "%08x", $1}')"
  else                    h="00000000"; fi
  printf '<%s-%s>' "$2" "$h"
}

registra() { # $1 valore, $2 tipo
  [ "$ANONIMO" -eq 1 ] || return 0
  local v
  v="$(printf '%s' "${1:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$v" ] && return 0
  # Sotto i quattro caratteri la sostituzione globale colpirebbe parole comuni.
  [ "${#v}" -lt 4 ] && return 0
  printf '%s' "$v" | grep -qiE "^($INUTILI)$" && return 0
  case "
$VAL" in *"
$v
"*) return 0 ;; esac
  VAL="$VAL$v
"
  PSE="$PSE$(pseudonimo "$v" "$2")
"
}

registra_righe() { # $1 tipo; legge valori da stdin, uno per riga
  local tipo="$1" x
  while IFS= read -r x; do registra "$x" "$tipo"; done
}

raccogli_identificativi() {
  [ "$ANONIMO" -eq 1 ] || return 0
  registra "$(hostname 2>/dev/null)" host
  registra "$(hostname -f 2>/dev/null)" host
  registra "$(cat /etc/machine-id 2>/dev/null)" uuid
  if root && ha dmidecode; then
    registra "$(dmidecode -s system-serial-number 2>/dev/null | head -1)" sn
    registra "$(dmidecode -s system-uuid 2>/dev/null | head -1)" uuid
    registra "$(dmidecode -s baseboard-serial-number 2>/dev/null | head -1)" sn
    registra "$(dmidecode -s chassis-serial-number 2>/dev/null | head -1)" sn
    dmidecode -t memory 2>/dev/null |
      sed -n 's/^[[:space:]]*Serial Number:[[:space:]]*//p' | registra_righe sn
  fi
  ha lsblk && lsblk -dno SERIAL 2>/dev/null | registra_righe sn
  getent passwd 2>/dev/null | awk -F: '$3>=1000 && $3<65534 {print $1}' | registra_righe utente
}

# MAC e IPv4 non si sostituiscono per valore ma si mascherano: del MAC resta il
# produttore, dell'IPv4 resta la rete. Loopback, rotta di default, maschere e
# multicast restano leggibili perche' non identificano nessuna macchina.
MASCHERA_AWK='
function mac(l,   o, p, m, s) {
  o = ""
  while (match(l, MACRE)) {
    p = substr(l, 1, RSTART-1); m = substr(l, RSTART, RLENGTH); l = substr(l, RSTART+RLENGTH)
    s = substr(m, 3, 1)
    o = o p substr(m, 1, 8) s "XX" s "XX" s "XX"
  }
  return o l
}
function ip(l,   o, p, m, a, n) {
  o = ""
  while (match(l, IPRE)) {
    p = substr(l, 1, RSTART-1); m = substr(l, RSTART, RLENGTH); l = substr(l, RSTART+RLENGTH)
    if (m ~ /^127[.]/ || m == "0.0.0.0" || m ~ /^255[.]255[.]/ || m ~ /^(22[4-9]|23[0-9])[.]/)
      o = o p m
    else { n = split(m, a, "."); o = o p a[1] "." a[2] "." a[3] ".x" }
  }
  return o l
}
BEGIN { H = "[0-9A-Fa-f][0-9A-Fa-f]"
        MACRE = H "[:-]" H "[:-]" H "[:-]" H "[:-]" H "[:-]" H
        IPRE  = "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" }
{ print ip(mac($0)) }
'

sanifica() { # legge il censimento da stdin, lo restituisce anonimizzato
  if [ "$ANONIMO" -eq 0 ]; then cat; return 0; fi
  local testo ordine v p
  testo="$(cat)"
  # Dal piu' lungo al piu' corto: un seriale contenuto in un altro non deve
  # essere sostituito per primo e spezzare quello che lo contiene.
  ordine="$(printf '%s' "$VAL" | paste -d'	' - <(printf '%s' "$PSE") 2>/dev/null |
            awk -F'	' 'NF==2 && length($1)>0 {print length($1)"	"$1"	"$2}' |
            sort -rn | cut -f2-)"
  while IFS='	' read -r v p; do
    [ -z "${v:-}" ] && continue
    testo="${testo//"$v"/$p}"
  done <<EOFSOST
$ordine
EOFSOST
  printf '%s\n' "$testo" | awk "$MASCHERA_AWK"
}

# --- impalcatura -------------------------------------------------------------

sep() {
  printf '\n============================================================\n'
  printf '== %s\n' "$1"
  printf '============================================================\n'
}

se_c_e() { # $1 comando richiesto, resto: comando da eseguire
  local c="$1"
  if ha "$c"; then shift; "$@" 2>/dev/null || echo "  comando fallito: $c"
  else echo "  $c non installato su questa macchina"; fi
}

gestore_pacchetti() {
  if   ha dpkg-query; then echo dpkg
  elif ha rpm;        then echo rpm
  elif ha pacman;     then echo pacman
  elif ha apk;        then echo apk
  else                     echo nessuno; fi
}

# --- corpo -------------------------------------------------------------------

corpo() {

HOST_REALE="$(hostname 2>/dev/null || echo sconosciuto)"
if   [ -n "$ETICHETTA" ];  then NOME_MACCHINA="$ETICHETTA"
elif [ "$ANONIMO" -eq 1 ]; then NOME_MACCHINA="$(pseudonimo "$HOST_REALE" host)"
else                            NOME_MACCHINA="$HOST_REALE"; fi

if [ "$ANONIMO" -eq 1 ]; then MODO="anonimo (pseudonimi stabili; --identificativi per il chiaro)"
else MODO="IDENTIFICATIVI IN CHIARO - contiene dati reali, non versionare"; fi

echo '============================================================'
echo '== CENSIMENTO HARDWARE'
echo '============================================================'
echo "strumento  : hw-report.sh v$VERSIONE (windows-status, scripts/censimento)"
echo "piattaforma: Linux"
echo "macchina   : $NOME_MACCHINA"
echo "data       : $(date -Is 2>/dev/null || date)"
echo "modo       : $MODO"
echo "privilegi  : $PRIVILEGI"
echo "sezioni    : $(echo $SEZIONI | tr ' ' ',')"
echo "nota       : censimento di hardware e configurazione di base, una macchina"
echo "             alla volta; non tiene storico e non confronta nel tempo."

if usa IDENTITA; then
  sep "IDENTITA"
  echo "hostname   : $HOST_REALE"
  echo "dominio    : $(hostname -d 2>/dev/null)"
  echo "uptime     : $(uptime -p 2>/dev/null || uptime 2>/dev/null)"
  [ -r /etc/os-release ] && grep -E '^(NAME|VERSION|ID|VERSION_ID)=' /etc/os-release
  echo "kernel     : $(uname -r 2>/dev/null)  arch: $(uname -m 2>/dev/null)"
  echo "init       : $(ps -p1 -o comm= 2>/dev/null)"
  if [ -d /sys/firmware/efi ]; then echo "firmware   : UEFI"; else echo "firmware   : BIOS/Legacy"; fi
  if   [ -f /.dockerenv ]; then echo "container  : si (docker)"
  elif grep -qa 'container=lxc' /proc/1/environ 2>/dev/null; then echo "container  : si (lxc)"
  else echo "container  : no, o non determinabile"; fi
  echo "virtuale   : $(systemd-detect-virt 2>/dev/null || echo 'non determinabile')"
fi

if usa SISTEMA; then
  sep "SISTEMA / SCHEDA MADRE / FIRMWARE"
  if ha dmidecode && root; then
    echo "--- prodotto ---"
    dmidecode -t system 2>/dev/null | grep -E 'Manufacturer|Product Name|Version|Serial|UUID|Family'
    echo "--- scheda madre ---"
    dmidecode -t baseboard 2>/dev/null | grep -E 'Manufacturer|Product Name|Version|Serial'
    echo "--- firmware ---"
    dmidecode -t bios 2>/dev/null | grep -E 'Vendor|Version|Release Date|Revision'
    echo "--- telaio ---"
    dmidecode -t chassis 2>/dev/null | grep -E 'Manufacturer|Type|Serial'
  else
    echo "  dmidecode assente o privilegi insufficienti: ripiego su /sys/class/dmi"
    for f in sys_vendor product_name product_version product_serial board_vendor \
             board_name board_serial bios_vendor bios_version bios_date chassis_type; do
      [ -r "/sys/class/dmi/id/$f" ] && printf '%-18s: %s\n' "$f" "$(cat "/sys/class/dmi/id/$f" 2>/dev/null)"
    done
  fi
fi

if usa CPU; then
  sep "CPU"
  se_c_e lscpu lscpu
  echo "--- flag rilevanti ---"
  grep -o -m1 -E 'vmx|svm|aes|avx512[a-z]*|avx2|avx|sse4_2' /proc/cpuinfo 2>/dev/null | sort -u | tr '\n' ' '; echo
  echo "--- virtualizzazione ---"
  if grep -qE '(vmx|svm)' /proc/cpuinfo 2>/dev/null
  then echo "VT-x/AMD-V : esposta al sistema"
  else echo "VT-x/AMD-V : non esposta (disattivata nel firmware, o assente)"; fi
fi

if usa MEMORIA; then
  sep "MEMORIA"
  se_c_e free free -h
  echo "--- banchi installati ---"
  if ha dmidecode && root; then
    dmidecode -t memory 2>/dev/null |
      grep -E 'Size|Type:|Speed|Locator|Manufacturer|Part Number|Rank' | grep -v 'No Module'
    echo "--- slot ---"
    echo "slot totali   : $(dmidecode -t memory 2>/dev/null | grep -c '^Memory Device$')"
    echo "slot occupati : $(dmidecode -t memory 2>/dev/null | grep -E '^[[:space:]]*Size:' | grep -vc 'No Module')"
    dmidecode -t 16 2>/dev/null | grep -E 'Maximum Capacity|Number Of Devices'
  else
    echo "  dmidecode assente o privilegi insufficienti: i banchi non sono leggibili"
  fi
fi

if usa DISCHI; then
  sep "DISCHI"
  se_c_e lsblk lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL,ROTA,TRAN
  echo "--- geometria ---"
  if root && ha fdisk; then fdisk -l 2>/dev/null | grep -E 'Disk /dev/|Disklabel|^/dev/'
  else echo "  fdisk assente o privilegi insufficienti"; fi
  echo "--- volumi ---"
  se_c_e df df -hT -x tmpfs -x devtmpfs
  echo "--- affidabilita (SMART, richiede root) ---"
  if ha smartctl && root; then
    for d in /dev/sd? /dev/nvme?n1 /dev/hd? /dev/vd?; do
      [ -b "$d" ] || continue
      echo "### $d"
      smartctl -i -H "$d" 2>/dev/null | grep -E 'Model|Serial|Firmware|Capacity|Rotation|SMART overall|Sector'
      smartctl -A "$d" 2>/dev/null | grep -iE 'Power_On_Hours|Reallocated|Wear|Percentage_Used|Total_LBAs_Written|Temperature'
    done
  else
    echo "  smartctl assente o privilegi insufficienti"
  fi
  echo "--- LVM / RAID ---"
  ha pvs && pvs 2>/dev/null
  ha vgs && vgs 2>/dev/null
  ha lvs && lvs 2>/dev/null
  [ -r /proc/mdstat ] && cat /proc/mdstat 2>/dev/null
  echo "--- montaggi dichiarati ---"
  grep -vE '^[[:space:]]*#|^[[:space:]]*$' /etc/fstab 2>/dev/null
  echo "--- swap ---"
  se_c_e swapon swapon --show
fi

if usa RETE; then
  sep "RETE"
  if ha ip; then ip -br a 2>/dev/null; else se_c_e ifconfig ifconfig -a; fi
  echo "--- rotte ---"
  if ha ip; then ip r 2>/dev/null; else se_c_e route route -n; fi
  echo "--- interfacce: MAC, driver, velocita ---"
  if [ -d /sys/class/net ]; then
    for i in $(ls /sys/class/net 2>/dev/null | grep -v '^lo$'); do
      drv="$(basename "$(readlink -f "/sys/class/net/$i/device/driver" 2>/dev/null)" 2>/dev/null)"
      echo "### $i  mac=$(cat "/sys/class/net/$i/address" 2>/dev/null)  driver=${drv:-sconosciuto}"
      ha ethtool && ethtool "$i" 2>/dev/null | grep -E 'Speed|Duplex|Link detected'
    done
  fi
  echo "--- DNS ---"
  ha resolvectl && resolvectl status 2>/dev/null | grep -E 'DNS Servers|Current DNS' | head -5
  grep -v '^#' /etc/resolv.conf 2>/dev/null | grep -v '^$'
fi

if usa GPU; then
  sep "GPU / VIDEO"
  if ha lspci; then lspci -nnk 2>/dev/null | grep -iA2 -E 'vga|3d controller|display controller'
  else echo "  lspci non installato su questa macchina"; fi
  echo "--- connettori video ---"
  if [ -d /sys/class/drm ]; then
    for c in /sys/class/drm/*/status; do
      [ -r "$c" ] || continue
      echo "$(basename "$(dirname "$c")") : $(cat "$c" 2>/dev/null)"
    done
  fi
fi

if usa PERIFERICHE; then
  sep "BUS E PERIFERICHE"
  echo "--- PCI ---"
  se_c_e lspci lspci -nn
  echo "--- USB ---"
  se_c_e lsusb lsusb
  echo "--- dispositivi rimovibili ---"
  ha lsblk && lsblk -o NAME,RM,TYPE,SIZE,MODEL 2>/dev/null | awk 'NR==1 || $2==1'
fi

if usa ALIMENTAZIONE; then
  sep "ALIMENTAZIONE / TERMICO"
  trovata=0
  for b in /sys/class/power_supply/*; do
    [ -d "$b" ] || continue
    trovata=1
    echo "### $(basename "$b")  tipo=$(cat "$b/type" 2>/dev/null)  stato=$(cat "$b/status" 2>/dev/null)  carica=$(cat "$b/capacity" 2>/dev/null)"
  done
  [ "$trovata" -eq 0 ] && echo "  nessuna alimentazione esposta: macchina fissa, o modulo assente"
  echo "--- temperature ---"
  trovata=0
  for z in /sys/class/thermal/thermal_zone*; do
    [ -r "$z/temp" ] || continue
    trovata=1
    echo "$(cat "$z/type" 2>/dev/null) : $(awk '{printf "%.1f", $1/1000}' "$z/temp" 2>/dev/null) C"
  done
  [ "$trovata" -eq 0 ] && echo "  nessuna zona termica esposta"
fi

if usa SOFTWARE; then
  sep "CONTESTO SOFTWARE"
  echo "Sezione opzionale: serve a riconoscere il RUOLO della macchina, non a"
  echo "inventariarne il software. Nessun prodotto e' dato per scontato: cio'"
  echo "che interessa si chiede con --pattern."
  [ -n "$PATTERN" ] && echo "filtro     : $PATTERN"
  echo "--- servizi attivi ---"
  if ha systemctl; then
    echo "in esecuzione : $(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l)"
    [ -n "$PATTERN" ] && systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null |
      awk '{print $1}' | grep -iE "$PATTERN"
  elif ha rc-status; then rc-status --servicelist 2>/dev/null | head -40
  elif ha service;   then service --status-all 2>/dev/null | head -40
  else echo "  gestore dei servizi non riconosciuto"; fi
  echo "--- porte in ascolto ---"
  if   ha ss;      then ss -tulpn 2>/dev/null
  elif ha netstat; then netstat -tulpn 2>/dev/null
  else echo "  ne' ss ne' netstat disponibili"; fi
  echo "--- firewall ---"
  if   ha ufw && root;          then ufw status verbose 2>/dev/null
  elif ha firewall-cmd;         then firewall-cmd --list-all 2>/dev/null
  elif ha nft && root;          then nft list ruleset 2>/dev/null | head -40
  elif ha iptables && root;     then iptables -S 2>/dev/null | head -40
  else echo "  nessun firewall riconosciuto, o privilegi insufficienti"; fi
  echo "--- pacchetti ---"
  gp="$(gestore_pacchetti)"
  echo "gestore    : $gp"
  case "$gp" in
    dpkg)   echo "installati : $(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)"
            [ -n "$PATTERN" ] && dpkg-query -W -f '${Package} ${Version}\n' 2>/dev/null | grep -iE "$PATTERN" ;;
    rpm)    echo "installati : $(rpm -qa 2>/dev/null | wc -l)"
            [ -n "$PATTERN" ] && rpm -qa 2>/dev/null | grep -iE "$PATTERN" ;;
    pacman) echo "installati : $(pacman -Q 2>/dev/null | wc -l)"
            [ -n "$PATTERN" ] && pacman -Q 2>/dev/null | grep -iE "$PATTERN" ;;
    apk)    echo "installati : $(apk info 2>/dev/null | wc -l)"
            [ -n "$PATTERN" ] && apk info 2>/dev/null | grep -iE "$PATTERN" ;;
    *)      echo "  gestore di pacchetti non riconosciuto" ;;
  esac
  echo "--- account non di sistema ---"
  getent passwd 2>/dev/null | awk -F: '$3>=1000 && $3<65534 {print $1"  uid="$3"  shell="$7}'
fi

sep "FINE"
}

# --- esecuzione --------------------------------------------------------------

raccogli_identificativi
TESTO="$(corpo | sanifica)"

if [ "$VERSO_SCHERMO" -eq 1 ]; then
  printf '%s\n' "$TESTO"
  exit 0
fi

HOST_REALE="$(hostname 2>/dev/null || echo sconosciuto)"
if   [ -n "$ETICHETTA" ];  then NOME="$ETICHETTA"
elif [ "$ANONIMO" -eq 1 ]; then NOME="$(pseudonimo "$HOST_REALE" host | tr -d '<>')"
else                            NOME="$HOST_REALE"; fi
NOME="$(printf '%s' "$NOME" | sed 's/[^A-Za-z0-9_.-]/-/g')"
PREDEFINITO="hw-$NOME-$(date +%Y%m%d).txt"

if   [ -z "$DESTINAZIONE" ]; then PERCORSO="./$PREDEFINITO"
elif [ -d "$DESTINAZIONE" ]; then PERCORSO="$DESTINAZIONE/$PREDEFINITO"
else                              PERCORSO="$DESTINAZIONE"; fi

CARTELLA="$(dirname "$PERCORSO")"
[ -d "$CARTELLA" ] || mkdir -p "$CARTELLA"

printf '%s\n' "$TESTO" > "$PERCORSO"

echo "Censimento scritto in: $PERCORSO"
[ "$ANONIMO" -eq 0 ] && echo "ATTENZIONE: output con identificativi reali. Non versionarlo e non condividerlo senza valutarlo."
root || echo "Nota: eseguito senza root, il censimento e' parziale."
exit 0
