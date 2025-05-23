#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"

check_remnanode() {
    if sudo docker ps -q --filter "name=remnanode" | grep -q .; then
        info "Remnanode установлен"
        while true; do
            question "Хотите обновить docker-compose файл для интеграции с Tblocker? (y/n):"
            UPDATE_DOCKER="$REPLY"
            if [[ "$UPDATE_DOCKER" == "y" || "$UPDATE_DOCKER" == "Y" ]]; then
                return 0
            elif [[ "$UPDATE_DOCKER" == "n" || "$UPDATE_DOCKER" == "N" ]]; then
                info "Remnanode установлен, отказ от обновления docker-compose"
                return 1
            else
                warn "Пожалуйста, введите только 'y' или 'n'"
            fi
        done
    fi
    return 0
}

update_docker_compose() {
    info "Обновление docker-compose файла..."
    cd /opt/remnanode
    sudo docker compose down
    rm -f docker-compose.yml
    cp "/opt/remnasetup/data/docker/node-tblocker-compose.yml" docker-compose.yml
    sudo docker compose up -d
    success "Docker-compose файл обновлен!"
}

check_tblocker() {
    if [ -f /opt/tblocker/config.yaml ] && systemctl list-units --full -all | grep -q tblocker.service; then
        info "Tblocker уже установлен"
        while true; do
            question "Желаете обновить конфигурацию? (y/n):"
            UPDATE_CONFIG="$REPLY"
            if [[ "$UPDATE_CONFIG" == "y" || "$UPDATE_CONFIG" == "Y" ]]; then
                return 0
            elif [[ "$UPDATE_CONFIG" == "n" || "$UPDATE_CONFIG" == "N" ]]; then
                info "Tblocker уже установлен"
                read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
                exit 0
                return 1
            else
                warn "Пожалуйста, введите только 'y' или 'n'"
            fi
        done
    fi
    return 0
}

check_webhook() {
    while true; do
        question "Требуется настройка отправки вебхуков? (y/n):"
        WEBHOOK_NEEDED="$REPLY"
        if [[ "$WEBHOOK_NEEDED" == "y" || "$WEBHOOK_NEEDED" == "Y" ]]; then
            while true; do
                question "Укажите адрес вебхука (пример portal.domain.com/tblocker/webhook):"
                WEBHOOK_URL="$REPLY"
                if [[ -n "$WEBHOOK_URL" ]]; then
                    break
                fi
                warn "Адрес вебхука не может быть пустым. Пожалуйста, введите значение."
            done
            return 0
        elif [[ "$WEBHOOK_NEEDED" == "n" || "$WEBHOOK_NEEDED" == "N" ]]; then
            return 1
        else
            warn "Пожалуйста, введите только 'y' или 'n'"
        fi
    done
}

setup_crontab() {
    info "Настройка crontab..."
    crontab -l > /tmp/crontab_tmp 2>/dev/null || true
    echo "0 * * * * truncate -s 0 /var/lib/toblock/access.log" >> /tmp/crontab_tmp
    echo "0 * * * * truncate -s 0 /var/lib/toblock/error.log" >> /tmp/crontab_tmp

    crontab /tmp/crontab_tmp
    rm /tmp/crontab_tmp
    success "Crontab настроен!"
}

install_tblocker() {
    info "Установка Tblocker..."
    sudo mkdir -p /opt/tblocker
    sudo chmod -R 777 /opt/tblocker
    sudo mkdir -p /var/lib/toblock
    sudo chmod -R 777 /var/lib/toblock
    sudo su - << 'ROOT_EOF'
source /tmp/install_vars

curl -fsSL git.new/install -o /tmp/tblocker-install.sh || {
    error "Ошибка: Не удалось скачать скрипт Tblocker."
    exit 1
}

printf "\n\n\n" | bash /tmp/tblocker-install.sh || {
    error "Ошибка: Не удалось выполнить скрипт Tblocker."
    exit 1
}

rm /tmp/tblocker-install.sh

if [[ -f /opt/tblocker/config.yaml ]]; then
    sed -i 's|^LogFile:.*$|LogFile: "/var/lib/toblock/access.log"|' /opt/tblocker/config.yaml
    sed -i 's|^UsernameRegex:.*$|UsernameRegex: "email: (\\\\S+)"|' /opt/tblocker/config.yaml
    sed -i "s|^AdminBotToken:.*$|AdminBotToken: \"$ADMIN_BOT_TOKEN\"|" /opt/tblocker/config.yaml
    sed -i "s|^AdminChatID:.*$|AdminChatID: \"$ADMIN_CHAT_ID\"|" /opt/tblocker/config.yaml
    sed -i "s|^BlockDuration:.*$|BlockDuration: $BLOCK_DURATION|" /opt/tblocker/config.yaml

    if [[ "$WEBHOOK_NEEDED" == "y" || "$WEBHOOK_NEEDED" == "Y" ]]; then
        sed -i 's|^SendWebhook:.*$|SendWebhook: true|' /opt/tblocker/config.yaml
        sed -i "s|^WebhookURL:.*$|WebhookURL: \"https://$WEBHOOK_URL\"|" /opt/tblocker/config.yaml
    else
        sed -i 's|^SendWebhook:.*$|SendWebhook: false|' /opt/tblocker/config.yaml
    fi
else
    error "Ошибка: Файл /opt/tblocker/config.yaml не найден."
    exit 1
fi

exit
ROOT_EOF

    sudo systemctl restart tblocker.service
    success "Tblocker успешно установлен!"
}

update_tblocker_config() {
    info "Обновление конфигурации Tblocker..."
    if [[ -f /opt/tblocker/config.yaml ]]; then
        sudo sed -i 's|^LogFile:.*$|LogFile: "/var/lib/toblock/access.log"|' /opt/tblocker/config.yaml
        sudo sed -i 's|^UsernameRegex:.*$|UsernameRegex: "email: (\\\\S+)"|' /opt/tblocker/config.yaml
        sudo sed -i "s|^AdminBotToken:.*$|AdminBotToken: \"$ADMIN_BOT_TOKEN\"|" /opt/tblocker/config.yaml
        sudo sed -i "s|^AdminChatID:.*$|AdminChatID: \"$ADMIN_CHAT_ID\"|" /opt/tblocker/config.yaml
        sudo sed -i "s|^BlockDuration:.*$|BlockDuration: $BLOCK_DURATION|" /opt/tblocker/config.yaml

        if [[ "$WEBHOOK_NEEDED" == "y" || "$WEBHOOK_NEEDED" == "Y" ]]; then
            sudo sed -i 's|^SendWebhook:.*$|SendWebhook: true|' /opt/tblocker/config.yaml
            sudo sed -i "s|^WebhookURL:.*$|WebhookURL: \"https://$WEBHOOK_URL\"|" /opt/tblocker/config.yaml
        else
            sudo sed -i 's|^SendWebhook:.*$|SendWebhook: false|' /opt/tblocker/config.yaml
        fi
        
        sudo systemctl restart tblocker.service
        success "Конфигурация Tblocker обновлена!"
    else
        error "Ошибка: Файл /opt/tblocker/config.yaml не найден."
        exit 1
    fi
}

main() {
    if check_remnanode; then
        update_docker_compose
    fi

    if check_tblocker; then
        while true; do
            question "Введите токен бота для Tblocker (создайте бота в @BotFather для оповещений):"
            ADMIN_BOT_TOKEN="$REPLY"
            if [[ -n "$ADMIN_BOT_TOKEN" ]]; then
                break
            fi
            warn "Токен бота не может быть пустым. Пожалуйста, введите значение."
        done
        echo "ADMIN_BOT_TOKEN=$ADMIN_BOT_TOKEN" > /tmp/install_vars

        while true; do
            question "Введите Telegram ID админа для Tblocker:"
            ADMIN_CHAT_ID="$REPLY"
            if [[ -n "$ADMIN_CHAT_ID" ]]; then
                break
            fi
            warn "Telegram ID админа не может быть пустым. Пожалуйста, введите значение."
        done
        echo "ADMIN_CHAT_ID=$ADMIN_CHAT_ID" >> /tmp/install_vars

        question "Укажите время блокировки пользователя (указывается значение в минутах, по умолчанию 10):"
        BLOCK_DURATION="$REPLY"
        BLOCK_DURATION=${BLOCK_DURATION:-10}
        echo "BLOCK_DURATION=$BLOCK_DURATION" >> /tmp/install_vars

        check_webhook
        if [[ "$WEBHOOK_NEEDED" == "y" || "$WEBHOOK_NEEDED" == "Y" ]]; then
            echo "WEBHOOK_URL=$WEBHOOK_URL" >> /tmp/install_vars
        fi

        export WEBHOOK_NEEDED
        export WEBHOOK_URL

        update_tblocker_config
    else
        while true; do
            question "Введите токен бота для Tblocker (создайте бота в @BotFather для оповещений):"
            ADMIN_BOT_TOKEN="$REPLY"
            if [[ -n "$ADMIN_BOT_TOKEN" ]]; then
                break
            fi
            warn "Токен бота не может быть пустым. Пожалуйста, введите значение."
        done
        echo "ADMIN_BOT_TOKEN=$ADMIN_BOT_TOKEN" > /tmp/install_vars

        while true; do
            question "Введите Telegram ID админа для Tblocker:"
            ADMIN_CHAT_ID="$REPLY"
            if [[ -n "$ADMIN_CHAT_ID" ]]; then
                break
            fi
            warn "Telegram ID админа не может быть пустым. Пожалуйста, введите значение."
        done
        echo "ADMIN_CHAT_ID=$ADMIN_CHAT_ID" >> /tmp/install_vars

        question "Укажите время блокировки пользователя (указывается значение в минутах, по умолчанию 10):"
        BLOCK_DURATION="$REPLY"
        BLOCK_DURATION=${BLOCK_DURATION:-10}
        echo "BLOCK_DURATION=$BLOCK_DURATION" >> /tmp/install_vars

        check_webhook
        if [[ "$WEBHOOK_NEEDED" == "y" || "$WEBHOOK_NEEDED" == "Y" ]]; then
            echo "WEBHOOK_URL=$WEBHOOK_URL" >> /tmp/install_vars
        fi

        export WEBHOOK_NEEDED
        export WEBHOOK_URL

        install_tblocker
        setup_crontab
    fi

    rm -f /tmp/install_vars
    success "Установка завершена!"
    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
    exit 0
}

main
