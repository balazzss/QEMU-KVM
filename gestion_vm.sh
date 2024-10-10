#!/bin/bash

# Définition des variables
base_dir="/home/balazsverduyn"
network_dir="$base_dir/network"
launch_dir="$base_dir/launch_script"
vm_dir="$base_dir/vm"
iso_dir="base_dir/iso"

# Fonction pour installer une VM
install_vm() {
    echo "Lancement de l'installation de la VM..."

    #image_name=$(whiptail --inputbox "Entrer le nom de l'image de la VM :" 8 78 --title "Création de machine virtuelle QEMU/KVM" 3>&1 1>&2 2>&3)
    #img=$(whiptail --inputbox "Choisissez la taille du fichier img désiré" 8 78 --title "fichier image" 3>&1 1>&2 2>&3)
    #network_tap=$(whiptail --inputbox "Maintenant entrer l'interface par ex: tap0.1" 8 78 --title "Network" 3>&1 1>&2 2>&3)
    read -p "Entrer le nom de l'image de la VM : " image_name
    read -p "Choisissez la taille du fichier img désiré (en Go) : " img
    read -p "Maintenant entrer l'interface par ex: tap0.1 : " network_tap
    MACADDR1="34:$(dd if=/dev/urandom bs=512 count=1 2>/dev/null | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4:\5/')"

    # Fonction de nettoyage en cas d'échec
    cleanup () {
        echo "Nettoyage en cours..."
        sudo killall qemu-system-x86_64
        rm -f "$base_dir/vm/$image_name.img"
        rm -f "$network_dir/tap_$image_name.sh"
        rm -f "$launch_dir/load_$image_name.sh"
        echo "Nettoyage terminé."
        exit 1
    }

    # Vérifie les fichiers et répertoires nécessaires
    checkfiles () {
        [ -d "$network_dir" ] || mkdir "$network_dir"
        [ -f "$network_dir/tap_$image_name.sh" ] || touch "$network_dir/tap_$image_name.sh" && chmod +x "$network_dir/tap_$image_name.sh" && chown balazsverduyn: "$network_dir/tap_$image_name.sh"

        [ -d "$launch_dir" ] || mkdir "$launch_dir"
        [ -f "$launch_dir/load_$image_name.sh" ] || touch "$launch_dir/load_$image_name.sh" && chmod +x "$launch_dir/load_$image_name.sh" && chown balazsverduyn: "$launch_dir/load_$image_name.sh"
    }

    # Crée le script réseau
    network () {
        cat << EOL > "$network_dir/tap_$image_name.sh"
#!/bin/sh
ip link set "$network_tap" up
EOL
    }

    # Crée le script de lancement
    script () {
        cat << EOL > "$launch_dir/load_$image_name.sh"
#!/bin/sh

PSGREP=\$(ps aux | grep qemu-system-x86_64 | grep "$image_name".img)

if [ -z "\$PSGREP" ]; then
    qemu-system-x86_64 \\
    -enable-kvm \\
    -display curses \\
    -vga vmware \\
    -drive file="$base_dir/vm/$image_name.img",if=virtio \\
    -k fr-be \\
    -cpu host \\
    -smp 1 \\
    -m 512 \\
    -netdev tap,id=net0,ifname="$network_tap",script="$network_dir/tap_$image_name.sh",downscript=no \\
    -device virtio-net,netdev=net0,mac="$MACADDR1"
else
    echo "La machine virtuelle $image_name est en cours d'exécution."
    exit
fi
EOL
    }

    # Lancement de l'installation
    start_install () {
        qemu-img create -f qcow2 "$base_dir/vm/$image_name.img" "$img"G
        sudo chown balazsverduyn:balazsverduyn /home/balazsverduyn/vm/$image_name.img
        sudo qemu-system-x86_64 -enable-kvm -display curses -vga vmware -k fr-be -smp 2 -m 2048 -cdrom "$base_dir/iso/debian-12.5.0-amd64-netinst.iso" -boot d -hda "$base_dir/vm/$image_name.img"
    }

    main () {
        checkfiles || cleanup
        network || cleanup
        script || cleanup
        start_install || cleanup
    }
    main
    exit
}

remove_vm () {
    echo "Lancement de la suppression de la VM..."

    # Demander le nom de l'image de la VM à supprimer
    read -p "Entrer le nom de l'image de la VM à supprimer : " image_name

    # Vérification que le nom de l'image n'est pas vide
    if [ -z "$image_name" ]; then
        echo "Erreur : Aucun nom d'image fourni."
        exit 1
    fi

    # Supprimer le script de lancement si il existe
    if [ -f "$launch_dir/load_$image_name.sh" ]; then
        sudo rm "$launch_dir/load_$image_name.sh"
        echo "Le script de lancement $launch_dir/load_$image_name.sh a été supprimé."
    else
        echo "Avertissement : Le script de lancement $launch_dir/load_$image_name.sh n'existe pas."
    fi

    # Supprimer le script réseau si il existe
    if [ -f "$network_dir/tap_$image_name.sh" ]; then
        sudo rm "$network_dir/tap_$image_name.sh"
        echo "Le script réseau $network_dir/tap_$image_name.sh a été supprimé."
    else
        echo "Avertissement : Le script réseau $network_dir/tap_$image_name.sh n'existe pas."
    fi

    # Supprimer le fichier image de la VM si il existe
    if [ -f "$vm_dir/$image_name.img" ]; then
        sudo rm "$vm_dir/$image_name.img"
        echo "Le fichier image $vm_dir/$image_name.img a été supprimé."
    else
        echo "Avertissement : Le fichier image $vm_dir/$image_name.img n'existe pas."
    fi

    echo "Suppression de la VM $image_name terminée."
    exit 0
}


# Fonction pour monitorer les VMs actives
monitor_vm () {

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'

    VM_LIST=$(ps -ef | grep qemu-system-x86_64 | grep -v grep)

    if [ -z "$VM_LIST" ]; then
        echo "Aucune machine virtuelle n'est actuellement active."
    else
        echo "Informations des machines virtuelles actives :"
        echo "$VM_LIST" | while read -r line; do
            VM_NAME=$(echo "$line" | grep -oP '(?<=file=)[^,]+')
            VM_NAME=$(basename "$VM_NAME" .img)
            SMP=$(echo "$line" | grep -oP '(?<=-smp )\d+')
            MEMORY=$(echo "$line" | grep -oP '(?<=-m )\d+')
            TAP=$(echo "$line" | grep -oP '(?<=ifname=)[^,]+')
            MAC=$(echo "$line" | grep -oP '(?<=mac=)[^,]+')

            echo "----------------------------------"
            echo -e "VM: ${RED}$VM_NAME${NC}"
            echo -e "Nombre de SMP: ${GREEN}$SMP${NC}"
            echo -e "Mémoire: ${GREEN}$MEMORY${NC}"
            echo -e "Interface TAP: ${GREEN}$TAP${NC}"
            echo -e "Adresse MAC: ${GREEN}$MAC${NC}"
            echo "----------------------------------"
        done
    fi
}

list_active_tap () {
    RED='\033[0;31m'
    # Réinitialiser la couleur
    NC='\033[0m'

    # Liste les interfaces réseau TAP
    TAP_INTERFACES=$(ip link show | grep -oP 'tap[0-9]+(\.[0-9]+)?')

    if [ -z "$TAP_INTERFACES" ]; then
        echo "Aucune interface TAP détectée."
        exit 1
    fi

    # Liste les machines virtuelles actives avec leurs interfaces réseau
    VM_LIST=$(ps -ef | grep qemu-system-x86_64 | grep -v grep)

    echo "Vérification des interfaces TAP et des VMs associées :"
    echo "------------------------------------------------------"

    for TAP in $TAP_INTERFACES; do
        # Cherche si l'interface TAP est utilisée par une VM spécifique
        VM_USED=$(echo "$VM_LIST" | grep "ifname=$TAP")

        if [ -z "$VM_USED" ]; then
            echo "L'interface $TAP n'est utilisée par aucune VM."
        else
            # Extrait le nom du fichier image (nom de la VM)
            VM_NAME=$(echo "$VM_USED" | grep -oP '(?<=file=)[^,]+')
            VM_NAME=$(basename "$VM_NAME" .img)

            # Extrait l'adresse MAC associée à l'interface TAP
            MAC=$(echo "$VM_USED" | grep -oP '(?<=mac=)[^,]+')

            # Affiche les informations de la VM qui utilise cette interface
            echo -e "L'interface ${RED}$TAP${NC} est utilisée par la VM ${RED}$VM_NAME${NC} (MAC: ${RED}$MAC${NC})"
        fi
        echo "------------------------------------------------------"
    done

}

list_vm_tap() {
    # Dossier contenant les fichiers
    network_folder="/home/balazsverduyn/network"

    # Codes de couleur
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m' # Pas de couleur

    # Parcourir tous les fichiers tap_nomdevm
    for file in "$network_folder"/tap_*; do
        if [[ -f $file ]]; then
            # Extraire le nom de la VM à partir du nom de fichier (en supposant que c'est après "tap_")
            filename=$(basename "$file")
            vm=$(echo "$filename" | cut -d'_' -f2)

            # Afficher le nom de la VM en vert
            echo -e "VM:${GREEN}$vm${NC} utilise les interfaces suivantes :"

            # Parcourir le contenu du fichier pour trouver et afficher les interfaces tap
            while read -r line; do
                # Extraire l'interface tap de la ligne
                interface=$(echo "$line" | grep -o "tap[0-9\.]*")
                if [[ -n $interface ]]; then
                    # Afficher l'interface en rouge
                    echo -e "  - Interface: ${RED}$interface${NC}"
                fi
            done < "$file"
        fi
    done
}

# Fonction pour générer une adresse MAC
mac_gen () {
    curl -L https://raw.githubusercontent.com/balazzss/macaddress_gen/main/macaddr.sh | bash
    exit
}


# Menu principal
#while true; do
display_menu() {
    echo "--------- Menu ---------"
    echo "1. Installer une VM"
    echo "2. Supprimer une VM"
    echo "3. Liste les VM actives"
    echo "4. Liste les interfaces TAP actives"
    echo "5. Liste les interfaces TAP utilisés par les VM (même éteintes)"
    echo "6. Génération d'adresse MAC"
    echo "7. Quitter"
    read -rp "Choisissez une option (1-7) : " choice

    case $choice in
        1) install_vm ;;
        2) remove_vm ;;
        3) monitor_vm ;;
        4) list_active_tap ;;
        5) list_vm_tap ;;
        6) mac_gen ;;
        7) echo "Au revoir !" && exit ;;
        *) echo "Choix invalide. Veuillez sélectionner une option valide (1-6)." ;;
    esac
}

while getopts "irmlth" option; do
    case $option in
        i) install_vm ;;    # Option -i pour installer une VM
        r) remove_vm ;;     # Option -r pour supprimer une VM
        m) monitor_vm ;;    # Option -m pour monitorer les VM actives
        l) list_active_tap ;;    # Option -m pour monitorer les VM actives
        t) list_vm_tap ;;
        h)                  # Option -h pour afficher l'aide
            echo "Usage: gestion_vm [options]"
            echo "-i  Installer une VM"
            echo "-r  Supprimer une VM"
            echo "-m  Lister les VM actives"
            echo "-l  Lister les interfaces tap actives"
            echo "-t  Lister les interfaces des vm même éteintes"
            echo "-h  Afficher cette aide"
            exit 0
            ;;
        *)                  # En cas d'option invalide
            echo "Option invalide. Utilisez -h pour afficher l'aide."
            exit 1
            ;;
    esac
done
# Si aucune option n'est passée, afficher le menu
if [ $OPTIND -eq 1 ]; then
    display_menu
fi
