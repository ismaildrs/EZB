#!/bin/bash

# Error Codes
ERROR_OPTION_NON_EXISTANTE=100
ERROR_PARAMETRE_OBLIGATOIRE_MANQUANT=101
ERROR_ERREUR_INCONNUE=102
ERROR_ECRITURE_FICHIER_JOURNAL=103
ERROR_EXECUTION_SCRIPT_NON_ROOT=104
ERROR_OPTION_P_NON_C=105
ERROR_OPTION_NON_VALIDE=106
ERROR_MANUEL_SOURCE_N_OMISSION=107
ERROR_AUTOMATIQUE_SOURCE_N_F_OMISSION=108
ERROR_FICHIER_SPECIFIE_INEXISTANT=109
ERROR_COMPRESSION_DOSSIER=110
ERROR_ENVOI_FICHIER_DRIVE=111
ERROR_FREQUENCE_SAUV_AUTO_NON_VALIDE=112
ERROR_AUCUNE_METHODE_SAUV_SPECIFIEE=113

# Info Codes
INFO_UPLOAD_SUCCESS=400
INFO_UPLOAD_SUCCESS_MESSAGE="Toutes les opérations d'upload vers Google Drive ont été effectuées avec succès."


# Variables
manual_backup=false
automatic_backup=false
source_file=""
file_name=""
compress=false
frequency=""
log_dir="/var/log"
restore=false
password=""

lgfile="/var/log/history.log"

# pour afficher help menu
show_help() {
    echo "Usage: sudo backup [options]"
    echo "-m, --manual         Effectue une sauvegarde manuelle"
    echo "-a, --automatic      Effectue une sauvegarde automatique"
    echo "-s, --source         Source du fichier/dossier à sauvegarder"
    echo "-n, --name           Nom du fichier sur Google Drive"
    echo "-c, --compress       Compression du fichier de sauvegarde"
    echo "-p, --password       Mot de passe pour la compression (nécessite -c)"
    echo "-f, --frequency      Fréquence de la sauvegarde automatique (ex: daily, weekly)"
    echo "-l, --log            Log file"
    echo "-h, --help           Affiche man"
}

# Error Messages
error_message() {
    local error_code=$1
    case $error_code in
        $ERROR_OPTION_NON_EXISTANTE)
            echo "Option saisie non existante."
            ;;
        $ERROR_PARAMETRE_OBLIGATOIRE_MANQUANT)
            echo "Paramètre obligatoire manquant."
            ;;
        $ERROR_ERREUR_INCONNUE)
            echo "Erreur inconnue."
            ;;
        $ERROR_ECRITURE_FICHIER_JOURNAL)
            echo "Erreur lors de l'écriture dans le fichier journal."
            ;;
        $ERROR_EXECUTION_SCRIPT_NON_ROOT)
            echo "Le script doit être exécuté avec sudo ou en tant qu'utilisateur root."
            ;;
        $ERROR_OPTION_P_NON_C)
            echo "L'option -p ne peut être utilisée que si l'option -c est spécifiée."
            ;;
        $ERROR_OPTION_NON_VALIDE)
            echo "Option non valide."
            ;;
        $ERROR_MANUEL_SOURCE_N_OMISSION)
            echo "Pour une sauvegarde manuelle, les options -s et -n sont obligatoires."
            ;;
        $ERROR_AUTOMATIQUE_SOURCE_N_F_OMISSION)
            echo "Pour une sauvegarde automatique, les options -s, -n et -f sont obligatoires."
            ;;
        $ERROR_FICHIER_SPECIFIE_INEXISTANT)
            echo "Le fichier spécifié n'existe pas."
            ;;
        $ERROR_COMPRESSION_DOSSIER)
            echo "Erreur de la compression du dossier."
            ;;
        $ERROR_ENVOI_FICHIER_DRIVE)
            echo "Erreur lors de l'envoi du fichier vers Google Drive."
            ;;
        $ERROR_FREQUENCE_SAUV_AUTO_NON_VALIDE)
            echo "Fréquence de sauvegarde automatique non valide. Les options valides sont 'daily' ou 'weekly'."
            ;;
        $ERROR_AUCUNE_METHODE_SAUV_SPECIFIEE)
            echo "Aucune méthode de sauvegarde spécifiée. Veuillez choisir 'manual' ou 'automatic'."
            ;;
        *)
            echo "Erreur inconnue: $error_code"
            ;;
    esac
}

# Function to handle errors
handle_error() {
    local error_code=$1
    local error_message=$(error_message "$error_code")
    log_info "$error_message" "ERREUR" "$error_code"
    echo "Erreur ($error_code) : $error_message"
    exit 1
}

# pour afficher et sauvegarder les erreurs
log_info() {
    local log_message="$1"
    local log_type="$2"
    local error_code="$3"

    if [[ -n $log_dir ]]; then
        timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
        username=$(whoami)
        if [[ $log_type == "ERREUR" ]]; then
            echo "$timestamp : $username : $log_type ($error_code) : $log_message" >> "$log_dir/history.log"
        else
            echo "$timestamp : $username : $log_type ($error_code) : $log_message" >> "$log_dir/history.log" || { echo "Erreur lors de l'écriture dans le fichier journal."; exit 1; }
        fi
    fi
}

# Check if the user is root for specific options
if [ "$(id -u)" -ne 0 ] && [ "$1" == "-m" ]; then
    handle_error "$ERROR_EXECUTION_SCRIPT_NON_ROOT"
fi
if [ "$(id -u)" -ne 0 ] && [ "$1" == "-a" ] ; then
    handle_error "$ERROR_EXECUTION_SCRIPT_NON_ROOT"
fi

# Check if at least one option is provided
if [ "$#" -eq 0 ]; then
    handle_error "$ERROR_OPTION_NON_EXISTANTE"
fi

# Verify options
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -m|--manual)
            manual_backup=true
            shift
            ;;
        -a|--automatic)
            automatic_backup=true
            shift
            ;;
        -s|--source)
            source_file="$2"
            shift 2
            ;;
        -n|--name)
            file_name="$2"
            shift 2
            ;;
        -c|--compress)
            compress=true
            shift
            ;;
        -p|--password)
            if [ "$compress" = true ]; then
                password="$2"
                shift 2
            else
                handle_error "$ERROR_OPTION_P_NON_C"
            fi
            ;;
        -f|--frequency)
            frequency="$2"
            shift 2
            ;;
        -l|--log)
            sudo cat "$lgfile"
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            handle_error "$ERROR_OPTION_NON_VALIDE"
            ;;
    esac
done

# Check backup options
if $manual_backup && [[ -z $source_file || -z $file_name ]]; then
    handle_error "$ERROR_MANUEL_SOURCE_N_OMISSION"
fi

if $automatic_backup && [[ -z $source_file || -z $file_name || -z $frequency ]]; then
    handle_error "$ERROR_AUTOMATIQUE_SOURCE_N_F_OMISSION"
fi

# Check if specified file exists
if ! find "$source_file" > /dev/null 2>&1; then
    handle_error "$ERROR_FICHIER_SPECIFIE_INEXISTANT"
fi

# changer le token
ACCESS_TOKEN="ya29.a0AXooCgseo1_Oq6Ah2DjTjvgnfVHQBgGP3OSGU7_-bd4qh6Ks0PDzRVgfuasF_aKJNGkSH42GgLBvdydodXTRgp5canLkYNBM88C820mNPK3N6uyzECJbGc5kaAAPHY3__CLQXKomQRKlAsCbIAC8UIKDufd21ceUz8UwaCgYKAawSARESFQHGX2MiF4NJ3mKAaXdk04FoFGmVbA0171"

UPLOAD_URL="https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"

# Function to upload files using curl
upload_to_drive() {
    local source="$1"
    local name="$2"
    local compress="$3"
    local password="$4"

    if $compress; then
        if [[ -d $source ]]; then
            if [ -n "$password" ]; then
                zip -re "$source.zip" "$source" -P "$password" || handle_error "$ERROR_COMPRESSION_DOSSIER"
            else
                zip -r "$source.zip" "$source" || handle_error "$ERROR_COMPRESSION_DOSSIER"
            fi
            source="$source.zip"
        fi
    fi

    response=$(curl -s -X POST -L \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -F "metadata={name:'$name'};type=application/json; charset=UTF-8" \
        -F "file=@$source;type=application/zip" \
        "$UPLOAD_URL")

    if [ $? -ne 0 ]; then
        handle_error "$ERROR_ENVOI_FICHIER_DRIVE"
    fi

    echo "Info ($INFO_UPLOAD_SUCCESS) : $INFO_UPLOAD_SUCCESS_MESSAGE"
    log_info "$INFO_UPLOAD_SUCCESS_MESSAGE" "INFOS" "$INFO_UPLOAD_SUCCESS"
}

# Main

if $manual_backup; then
    echo "Début de la sauvegarde manuelle..."
    upload_to_drive "$source_file" "$file_name" "$compress" "$password"
elif $automatic_backup; then
    echo "La sauvegarde automatique est activée. Fréquence: $frequency"

    case $frequency in
        daily)
            cron_schedule="0 12 * * *"
            ;;
        weekly)
            cron_schedule="0 12 * * 1"
            ;;
        *)
            handle_error "$ERROR_FREQUENCE_SAUV_AUTO_NON_VALIDE"
            ;;
    esac

    if [[ $EUID -ne 0 ]]; then
        echo "$cron_schedule sudo /bin/bash $0 -m -s $source_file -n $file_name -c" | crontab -
    else
        echo "$cron_schedule /bin/bash $0 -m -s $source_file -n $file_name -c" | crontab -
    fi

    echo "Tâche de sauvegarde automatique ajoutée avec succès pour exécuter chaque jour à midi."
else
    handle_error "$ERROR_AUCUNE_METHODE_SAUV_SPECIFIEE"
fi
# verification de token si il est expire - gestion erreur
# automatique a verifier
# log file a verifier
