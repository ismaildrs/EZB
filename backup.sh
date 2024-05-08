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
        $ERROR_OPTION_NON_EXISTANT)
            echo "Erreur ($ERROR_OPTION_NON_EXISTANT): Option saisie non existante."
            ;;
        $ERROR_PARAMETRE_OBLIGATOIRE_MANQUANT)
            echo "Erreur ($ERROR_PARAMETRE_OBLIGATOIRE_MANQUANT): Paramètre obligatoire manquant."
            ;;
        # Autre erreur à ajouter ...
        *)
            echo "Erreur inconnue: $error_code"
            ;;
    esac
}

# pour afficher et sauvgarder les erreurs
handle_error() {
    local error_message="$1"
    echo "Erreur : $error_message"
    log_info "$error_message" "ERREUR"
    show_help
    exit 1
}


#pour sauvgarder les infos
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
            echo "$timestamp : $username : $log_type : $log_message" >> "$log_dir/history.log" || { echo "Erreur lors de l'écriture dans le fichier journal."; exit 1; }
        fi
    fi
}


# pour checker si luser est root
if [ "$(id -u)" -ne 0 ] && [ "$1" == "-m" ]; then
    handle_error "le script ("$1") doit être exécuté avec sudo ou en tant qu'utilisateur root."
fi
if [ "$(id -u)" -ne 0 ] && [ "$1" == "-a" ] ; then
    handle_error "le script ("$1") doit être exécuté avec sudo ou en tant qu'utilisateur root."
fi


# pour donner au moins une options
if [ "$#" -eq 0 ]; then
    handle_error "Aucune option n'a été spécifiée. Veuillez spécifier au moins une option."
fi


# pour verifier les options
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
                handle_error "L'option -p ne peut être utilisée que si l'option -c est spécifiée."
            fi
            ;;
        -f|--frequency)
            frequency="$2"
            shift 2
            ;;

        # a fixer
        -l|--log)
            cat "$lgfile"
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            handle_error "Option non valide: $1"
            ;;
    esac
done


if $manual_backup && [[ -z $source_file || -z $file_name ]]; then
    handle_error "Pour une sauvegarde manuelle, les options -s et -n sont obligatoires."
fi


if $automatic_backup && [[ -z $source_file || -z $file_name || -z $frequency ]]; then
    handle_error "Pour une sauvegarde automatique, les options -s, -n et -f sont obligatoires."
fi


if ! find "$source_file" > /dev/null 2>&1; then
    handle_error "Le fichier spécifié n'existe pas."
fi


# changer le token
ACCESS_TOKEN="ya29.a0AXooCgsZrMnWxOFxzcMoohtidgDC014x_riI5ofzQ2-SOQUGcP4pZUpjNhZ0VAIGirQu5a6lcpVV4Pk5ZBbTs6NI-U6AZKkCuWXXbNYGut2_lGRs2rAfteAhhFnrH24AGpaGM2Ri3gh1KAG1gOIajo0w-lYNbhNZvOc4aCgYKAc8SARASFQHGX2MiaWchNI1wDMUP_YpXl7om6g0171"

UPLOAD_URL="https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"


# fonction d'upload utilise curl
#(change it to be able to save normal -first if- folders and zipped folders)
upload_to_drive() {
    local source="$1"
    local name="$2"
    local compress="$3"
    local password="$4"

    if $compress; then
        if [[ -d $source ]]; then
            if [ -n "$password" ]; then
                zip -re "$source.zip" "$source" -P "$password" || handle_error "Erreur de la compression du dossier."
            else
                zip -r "$source.zip" "$source" || handle_error "Erreur la compression du dossier."
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
        handle_error "Erreur lors de l'envoi du fichier vers Google Drive."
    fi

    echo "Toutes les opérations d'upload vers Google Drive ont été effectuées avec succès."
    log_info "Toutes les opérations d'upload vers Google Drive ont été effectuées avec succès." "INFOS"
}



# Main

# working
if $manual_backup; then
    echo "Début de la sauvegarde manuelle..."
    upload_to_drive "$source_file" "$file_name" "$compress" "$password"

# pas encore tester
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
            handle_error "Fréquence de sauvegarde automatique non valide. Les options valides sont 'daily' ou 'weekly'."
            ;;
    esac

    if [[ $EUID -ne 0 ]]; then
        echo "$cron_schedule sudo /bin/bash $0 -m -s $source_file -n $file_name -c" | crontab -
    else
        echo "$cron_schedule /bin/bash $0 -m -s $source_file -n $file_name -c" | crontab -
    fi

    echo "Tâche de sauvegarde automatique ajoutée avec succès pour exécuter chaque jour à midi."
else
    handle_error "Aucune méthode de sauvegarde spécifiée. Veuillez choisir 'manual' ou 'automatic'."
fi


# verification de token si il est expire - gestion erreur
# automatique a verifier
# log file a verifier
# 