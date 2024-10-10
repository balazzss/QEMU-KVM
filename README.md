# QEMU-KVM
Installation de QEMU/KVM VM sur Debian 12 sans interface graphique

Pour utiliser ce programme, vous avez deux choix:

 1.  Utiliser le programme en lé téléchargeant 
 2.  Télécharger et installer install_gestion_vm.sh pour l'utiliser comme une commande avec des options

## 1. Download and install the install_gestion_vm.sh file
> wget https://raw.githubusercontent.com/balazzss/QEMU-KVM/refs/heads/main/gestion_vm.sh

## 2. Use the gestion_vm.sh file
> curl -L https://raw.githubusercontent.com/balazzss/QEMU-KVM/refs/heads/main/install_gestion_vm.sh | sudo bash

Une fois installé, il suffit de lancer:
> gestion_vm -h
Puis vous découvrirez les options:

-i  Installer une VM
-r Supprimer une VM
-m Lister les VM actives
-l Lister les interfaces tap actives
-t Lister les interfaces des vm même éteintes
-h Afficher cette aide



