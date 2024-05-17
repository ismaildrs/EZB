#!/bin/bash

source /etc/ezb/configuration.sh

# Error Codes
ERROR_OPTION_NON_EXISTANTE=100
ERROR_PARAMETRE_OBLIGATOIRE_MANQUANT=101
ERROR_ERREUR_INCONNUE=102
ERROR_ECRITURE_FICHIER_JOURNAL=103
ERROR_EXECUTION_SCRIPT_NON_ROOT=104
ERROR_OPTION_P_NON_C=105
ERROR_OPTION_NON_VALIDE=106
ERROR_MANUAL_SOURCE_OMISSION=107
ERROR_AUTOMATIC_SOURCE_OMISSION=108
ERROR_FICHIER_SPECIFIE_INEXISTANT=109
ERROR_COMPRESSION_DOSSIER=110
ERROR_ENVOI_FICHIER_B2=111
ERROR_FREQUENCE_SAUV_AUTO_NON_VALIDE=112
ERROR_AUCUNE_METHODE_SAUV_SPECIFIEE=113
ERROR_UTILISATION_FORK_AUTOMATIC=114

# Info Codes
INFO_UPLOAD_SUCCESS_B2=400
INFO_UPLOAD_SUCCESS_MESSAGE_B2="File uploaded successfully to Backblaze B2."

# Function to log info and errors
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
            echo "$timestamp : $username : $log_type ($error_code) : $log_message" >> "$log_dir/history.log"
        fi
    fi
}

# Function to handle errors
handle_error() {
    local error_code=$1
    local error_message
    case $error_code in
        $ERROR_OPTION_NON_EXISTANTE)
            error_message="Option saisie non existante."
            ;;
        $ERROR_PARAMETRE_OBLIGATOIRE_MANQUANT)
            error_message="Paramètre obligatoire manquant."
            ;;
        $ERROR_ERREUR_INCONNUE)
            error_message="Erreur inconnue."
            ;;
        $ERROR_ECRITURE_FICHIER_JOURNAL)
            error_message="Erreur lors de l'écriture dans le fichier journal."
            ;;
        $ERROR_EXECUTION_SCRIPT_NON_ROOT)
            error_message="Le script doit être exécuté avec sudo ou en tant qu'utilisateur root."
            ;;
        $ERROR_OPTION_P_NON_C)
            error_message="L'option -p ne peut être utilisée que si l'option -c est spécifiée."
            ;;
        $ERROR_OPTION_NON_VALIDE)
            error_message="Option non valide."
            ;;
        $ERROR_MANUAL_SOURCE_OMISSION)
            error_message="Pour une sauvegarde manuelle, les options -s et -n sont obligatoires."
            ;;
        $ERROR_AUTOMATIC_SOURCE_OMISSION)
            error_message="Pour une sauvegarde automatique, les options -s, -n et -f sont obligatoires."
            ;;
        $ERROR_FICHIER_SPECIFIE_INEXISTANT)
            error_message="Le fichier spécifié n'existe pas."
            ;;
        $ERROR_COMPRESSION_DOSSIER)
            error_message="Erreur de la compression du dossier."
            ;;
        $ERROR_ENVOI_FICHIER_B2)
            error_message="Erreur lors de l'envoi du fichier vers Backblaze B2."
            ;;
        $ERROR_FREQUENCE_SAUV_AUTO_NON_VALIDE)
            error_message="Fréquence de sauvegarde automatique non valide. Les options valides sont 'everyminute', 'hourly', 'daily', 'weekly' or 'yearly'."
            ;;
        $ERROR_AUCUNE_METHODE_SAUV_SPECIFIEE)
            error_message="Aucune méthode de sauvegarde spécifiée. Veuillez choisir 'manual' ou 'automatic'."
            ;;
        $ERROR_UTILISATION_FORK_AUTOMATIC)
            error_message="L'utilisation de 'fork' avec 'automatic' n'est pas intégrée."
            ;;
        *)
            error_message="Erreur inconnue: $error_code"
            ;;
    esac
    log_info "$error_message" "ERREUR" "$error_code"
    echo "Erreur ($error_code) : $error_message"
    exit 1
}

# ... rest of the script ...

# Variables
manual_backup=false
automatic_backup=false
install_checked=false
use_threads=false
forked_backup=false
source_file=""
file_name=""
frequency=""
log_dir="/var/log"
restore=false
minute="*"
hour="*"
day="*"
month="*"
week="*"
cron_schedule=""
lgfile="/var/log/history.log"
resfile="./restoreFile.log"


setup_command() {
    cp ./b2 /usr/local/bin
    chmod +x b2
    chmod +x ./ezb.sh
    chmod +w /etc/ezb/configuration.sh
    gcc ./forkBackup.c -o ezbFork
    gcc ./threadsBackup.c -o ezbThread
    cp ./ezb.sh /usr/local/bin
    cp ./ezbFork /usr/local/bin
    cp ./ezbThread /usr/local/bin
    mkdir /etc/ezb/
    mv ./configuration.sh /etc/ezb/
    alias ezb="ezb.sh"
}

# Function to authorize account and obtain auth token
authorize_account() {
    local response=$(b2 authorize-account "$B2_APPLICATION_KEY_ID" "$B2_APPLICATION_KEY")
    B2_ACCOUNT_AUTH_TOKEN=$(echo "$response" | jq -r '.accountAuthToken')
}

# Function to log restore information
log_restore() {
    local file_name="$1"
    local bucket_name="$2"
    local username=$(whoami)
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local restore_message="$timestamp : $username : Restored file: $file_name from bucket:$bucket_name"
    
    # Define the log file path
    local restorefile="$PWD/restoreFile.log"

    # Check if the log file exists, if not create it
    if [ ! -f "$restorefile" ]; then
        touch "$restorefile" || { echo "Failed to create log file: $restorefile"; return; }
    fi

    # Write the restore message to the log file
    echo "$restore_message" >> "$restorefile" || { echo "Failed to write to log file: $log_file"; return; }
}



# # Function to display restore file
# display_restore_file() {
#     local restorefile="$PWD/restoreFile.log"

#     # Check if the restore file exists
#     if [ -f "$restorefile" ]; then
#         cat "$restorefile"
#     else
#         echo "Restore file does not exist or has not been created yet."
#     fi
# }


# Function to upload files to Backblaze B2
upload_to_b2() {
    local source="$1"
    local file_name="$2"

    # Check if the b2 command exists
    if ! command -v b2 &> /dev/null; then
        handle_error "$ERROR_ENVOI_FICHIER_B2"
    fi

    # Check if the source is a directory or a file
    if [ -d "$source" ]; then
        # Upload all files in the directory using sync
        b2 sync "$source" "b2://$BUCKET_NAME/$file_name/"
    elif [ -f "$source" ]; then
        # Upload a single file using upload-file
        b2 upload-file "$BUCKET_NAME" "$source" "$file_name"
    else
        # Handle the case if the source is neither a file nor a directory
        handle_error "Invalid source: $source"
    fi

    # Check if the upload was successful
    if [ $? -ne 0 ]; then
        handle_error "$ERROR_ENVOI_FICHIER_B2"
    fi

    echo "Info ($INFO_UPLOAD_SUCCESS_B2) : $INFO_UPLOAD_SUCCESS_MESSAGE_B2"
    log_info "$INFO_UPLOAD_SUCCESS_MESSAGE_B2" "INFOS" "$INFO_UPLOAD_SUCCESS_B2"
    
    # Log restore details
    log_restore "$source" "$BUCKET_NAME"
}

# Function to display help menu
show_help() {
    echo "Usage: sudo backup [options]"
    echo "-m, --manual         Perform a manual backup"
    echo "-a, --automatic     Perform an automatic backup"
    echo "-co, --configure     Configure the command, specify the following fields: <B2_APPLICATION_KEY_ID> <B2_APPLICATION_KEY> <BUCKET_NAME>"
    echo "-i, --install       Install the command"
    echo "-s, --source        Source of the file/directory to backup"
    echo "-n, --name          Name of the file on Backblaze"
    echo "-f, --frequency     Frequency of automatic backup (ex: daily, weekly)"
    echo "-r, --restore       Restore files from backup"
    echo "-l, --log           Log file"
    echo "-fo, --fork         Fork"
    echo "-t, --thread        Use threads"
    echo "-h, --help          Show help"
}

# Function to compress folder
compress_folder() {
    local source_folder="$1"
    local destination="$2"

    echo "Compression en cours..."
    tar -czf "$destination" "$source_folder"
    echo "Compression terminée."
}

if [ "$(id -u)" -ne 0 ] && ([ "$1" == "-i" ]||[ "$1" == "--install" ]); then
    handle_error "$ERROR_EXECUTION_SCRIPT_NON_ROOT"
fi

# Function to parse command line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            -t|--thread)
                use_threads=true
                shift
                ;;
            -i|--install)
                setup_command
                exit 0;
                ;;
            -co|--configure)
                sed -i "s/B2_APPLICATION_KEY_ID=.*/B2_APPLICATION_KEY_ID=\"$2\"/" "/etc/ezb/configuration.sh"
                sed -i "s/B2_APPLICATION_KEY=.*/B2_APPLICATION_KEY=\"$3\"/" "/etc/ezb/configuration.sh"
                sed -i "s/BUCKET_NAME=.*/BUCKET_NAME=\"$4\"/" "/etc/ezb/configuration.sh"
                exit 0
                ;;
            -m|--manual)
                manual_backup=true
                shift
                ;;
            -a|--automatic)
                automatic_backup=true
                shift
                ;;
            -fo|--fork)
                if $automatic_backup; then
                    handle_error "$ERROR_UTILISATION_FORK_AUTOMATIC"
                    exit 1;
                else
                    forked_backup=true
                fi
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
            -f|--frequency)
                frequency="$2"
                shift 2
                ;;
            -r|--restore)
                restore=true
                display_restore_file
                exit 0
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
}

# Call the function to parse command line options
parse_options "$@"

# Check if the user is root for specific options
if [ "$(id -u)" -ne 0 ] && ([ "$1" == "-m" ]||[ "$1" == "-a" ]); then
    handle_error "$ERROR_EXECUTION_SCRIPT_NON_ROOT"
fi

if [ "$(id -u)" -ne 0 ] && [ "$1" == "-a" ] ; then
    handle_error "$ERROR_EXECUTION_SCRIPT_NON_ROOT"
fi

# Check if at least one option is provided
if [ "$#" -eq 0 ]; then
    handle_error "$ERROR_OPTION_NON_EXISTANTE"
fi

# Check backup options
if [[ $manual_backup && (-z "$source_file" || -z "$file_name") ]]; then
    handle_error "$ERROR_MANUAL_SOURCE_OMISSION"
fi

if [[ $automatic_backup && (-z "$source_file" || -z "$file_name") ]]; then
    handle_error "$ERROR_AUTOMATIC_SOURCE_OMISSION"
fi

# Check if specified file exists
if ! find "$source_file" > /dev/null 2>&1; then
    handle_error "$ERROR_FICHIER_SPECIFIE_INEXISTANT"
fi

# Authorize account and obtain auth token
authorize_account

# Main
if $manual_backup; then
    if $forked_backup; then
        echo "Début de la sauvegarde manuelle parallèle..."
        backup "$source_file"
    elif $use_threads; then
        echo "Début de la sauvegarde manuelle parallèle avec les threads..."
        backup2 "$source_file"
    else
        echo "Début de la sauvegarde manuelle sans compression..."
        upload_to_b2 "$source_file" "$file_name"
    fi

elif $automatic_backup; then
    echo "La sauvegarde automatique est activée. Fréquence: $frequency"

    if [ -z $frequency ]; then
        echo "--------------Specifiy the following fields: --------------"
        echo "> Minutes: "
        read minute
        echo "> Hour: "
        read hour
        echo "> Day: "
        read day
        echo "> Month: "
        read month
        echo "> Week: "
        read week
    else 
        case $frequency in
            everyminute)
                ;;
            hourly)
                minute="0"
                ;;
            daily)
                minute="0"
                hour="0"
                ;;
            weekly)
                minute="0"
                hour="0"
                week="0"
                ;;
            monthly)
                minute="0"
                hour="0"
                day="1"
                ;;
            yearly)
                minute="0"
                hour="0"
                day="1"
                month="1"
                ;;
        esac
    fi
    

    cron_schedule="$minute $hour $day $month $week"

    if [[ $EUID -eq 0 ]]; then
        echo "$cron_schedule $0 -m -s $(pwd)/$source_file $file_name" | sudo crontab -
        echo "Scheduling done successfully"
    fi
else
    handle_error "$ERROR_AUCUNE_METHODE_SAUV_SPECIFIEE"
fi

