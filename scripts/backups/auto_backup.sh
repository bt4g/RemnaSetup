#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

BACKUP_DIR="/opt/backups"
AUTO_BACKUP_DIR="$BACKUP_DIR/auto_backup"
SCRIPT_DIR="/opt/remnasetup/data/backup"

mkdir -p "$AUTO_BACKUP_DIR"

check_time_format() {
    local time=$1
    if [[ ! $time =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        return 1
    fi
    return 0
}

get_hours_word() {
    local hours=$1
    local last_digit=$((hours % 10))
    local last_two_digits=$((hours % 100))
    
    if [ $last_two_digits -ge 11 ] && [ $last_two_digits -le 19 ]; then
        get_string "auto_backup_hours_5_20"
    elif [ $last_digit -eq 1 ]; then
        get_string "auto_backup_hours_1"
    elif [ $last_digit -ge 2 ] && [ $last_digit -le 4 ]; then
        get_string "auto_backup_hours_2_4"
    else
        get_string "auto_backup_hours_5_20"
    fi
}

get_days_word() {
    local days=$1
    local last_digit=$((days % 10))
    local last_two_digits=$((days % 100))
    
    if [ $last_two_digits -ge 11 ] && [ $last_two_digits -le 19 ]; then
        get_string "auto_backup_days_5_20"
    elif [ $last_digit -eq 1 ]; then
        get_string "auto_backup_days_1"
    elif [ $last_digit -ge 2 ] && [ $last_digit -le 4 ]; then
        get_string "auto_backup_days_2_4"
    else
        get_string "auto_backup_days_5_20"
    fi
}

cleanup_old_crons() {
    info "$(get_string "auto_backup_cleanup_old_crons")"
    crontab -l 2>/dev/null | grep -v "$AUTO_BACKUP_DIR/backup.sh" | crontab -
}

while true; do
    question "$(get_string "auto_backup_select_mode")"
    case $REPLY in
        [Yy]* ) BACKUP_MODE="daily"; break;;
        [Nn]* ) BACKUP_MODE="hourly"; break;;
        * ) warn "$(get_string "auto_backup_please_answer_yn")";;
    esac
done

if [ "$BACKUP_MODE" = "daily" ]; then
    info "$(get_string "auto_backup_current_time" "$(date +%H:%M)")"
    while true; do
        question "$(get_string "auto_backup_enter_time")"
        if check_time_format "$REPLY"; then
            BACKUP_TIME="$REPLY"
            break
        else
            warn "$(get_string "auto_backup_invalid_time")"
        fi
    done

    HOUR=${BACKUP_TIME%%:*}
    MINUTE=${BACKUP_TIME#*:}
    CRON_SCHEDULE="$MINUTE $HOUR * * *"
else
    while true; do
        question "$(get_string "auto_backup_enter_interval")"
        if [[ "$REPLY" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
            INTERVAL_HOURS="$REPLY"
            break
        else
            warn "$(get_string "auto_backup_enter_number")"
        fi
    done
    CRON_SCHEDULE="0 */$INTERVAL_HOURS * * *"
fi

question "$(get_string "auto_backup_enter_storage")"
STORAGE_DAYS="$REPLY"
STORAGE_DAYS=${STORAGE_DAYS:-3}

while true; do
    question "$(get_string "auto_backup_enter_password")"
    PASSWORD="$REPLY"
    if [ ${#PASSWORD} -ge 8 ]; then
        break
    else
        warn "$(get_string "auto_backup_password_short")"
    fi
done

while true; do
    question "$(get_string "auto_backup_use_telegram")"
    case $REPLY in
        [Yy]* ) USE_TELEGRAM=true; break;;
        [Nn]* ) USE_TELEGRAM=false; break;;
        * ) warn "$(get_string "auto_backup_please_answer_yn")";;
    esac
done

if [ "$USE_TELEGRAM" = true ]; then
    question "$(get_string "auto_backup_enter_bot_token")"
    BOT_TOKEN="$REPLY"
    
    question "$(get_string "auto_backup_enter_chat_id")"
    CHAT_ID="$REPLY"

    cp "$SCRIPT_DIR/backup_script_tg.sh" "$AUTO_BACKUP_DIR/backup.sh"
    sed -i "s/BOT_TOKEN=\"\"/BOT_TOKEN=\"$BOT_TOKEN\"/" "$AUTO_BACKUP_DIR/backup.sh"
    sed -i "s/CHAT_ID=\"\"/CHAT_ID=\"$CHAT_ID\"/" "$AUTO_BACKUP_DIR/backup.sh"
else
    cp "$SCRIPT_DIR/backup_script.sh" "$AUTO_BACKUP_DIR/backup.sh"
fi

sed -i "s/PASSWORD=\"\"/PASSWORD=\"$PASSWORD\"/" "$AUTO_BACKUP_DIR/backup.sh"
sed -i "s/-mtime +3/-mtime +$STORAGE_DAYS/" "$AUTO_BACKUP_DIR/backup.sh"

chmod +x "$AUTO_BACKUP_DIR/backup.sh"

cleanup_old_crons

(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $AUTO_BACKUP_DIR/backup.sh") | crontab -

success "$(get_string "auto_backup_configured")"
if [ "$BACKUP_MODE" = "daily" ]; then
    success "$(get_string "auto_backup_daily_at" "$BACKUP_TIME")"
else
    HOURS_WORD=$(get_hours_word "$INTERVAL_HOURS")
    success "$(get_string "auto_backup_every_hours" "$INTERVAL_HOURS" "$HOURS_WORD")"
fi
DAYS_WORD=$(get_days_word "$STORAGE_DAYS")
success "$(get_string "auto_backup_storage_days" "$STORAGE_DAYS" "$DAYS_WORD")"
if [ "$USE_TELEGRAM" = true ]; then
    success "$(get_string "auto_backup_telegram_configured")"
fi

read -n 1 -s -r -p "$(get_string "auto_backup_press_key")"
exit 0