#!/bin/sh -e

. ../common-script.sh

USERNAME=$(whoami)

install_sddm() {
    echo "Installing SDDM if not already installed..."
    if ! command_exists sddm; then
        case ${PACKAGER} in
            pacman)
                $ESCALATION_TOOL ${PACKAGER} -S --needed --noconfirm sddm qt6-svg
                ;;
            *)
                $ESCALATION_TOOL ${PACKAGER} install -y sddm qt6-svg
                ;;
        esac
    else
        echo "SDDM is already installed."
    fi
}

install_theme() {
    echo "Installing and configuring SDDM theme..."

    # Check if astronaut-theme already exists
    if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
        echo "SDDM astronaut theme is already installed. Skipping theme installation."
    else
        if ! $ESCALATION_TOOL git clone https://github.com/keyitdev/sddm-astronaut-theme.git /usr/share/sddm/themes/sddm-astronaut-theme; then
            echo "Failed to clone theme repository. Exiting."
            exit 1
        fi
    fi

    # Create or update /etc/sddm.conf
    $ESCALATION_TOOL tee /etc/sddm.conf > /dev/null << EOF
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=sddm-astronaut-theme
EOF

    $ESCALATION_TOOL systemctl enable sddm
    echo "SDDM theme configuration complete."
}

# Autologin
configure_autologin() {
    read -r -p "Do you want to enable autologin? (y/n): " enable_autologin
    if [ "$enable_autologin" != "y" ] && [ "$enable_autologin" != "Y" ]; then
        echo "Autologin not configured."
        return
    fi

    echo "Available sessions:"
    i=1
    for session_type in xsessions wayland-sessions; do
        for session_file in /usr/share/$session_type/*.desktop; do
            [ -e "$session_file" ] || continue
            name=$(grep -i "^Name=" "$session_file" | cut -d= -f2)
            type=$(echo "$session_type" | sed 's/s$//')
            eval "session_file_$i=\"$session_file\""
            echo "$i) $name ($type)"
            i=$((i + 1))
        done
    done

    # Prompt user to choose a session
    while true; do
        echo "Enter the number of the session you'd like to autologin: "
        read choice
        selected_session=""
        eval "selected_session=\$session_file_$choice"
        if [ -n "$selected_session" ]; then
            session_file="$selected_session"
            break
        else
            echo "Invalid choice. Please enter a valid number."
        fi
    done

    # Find the corresponding .desktop file and Update SDDM configuration
    actual_session=$(basename "$session_file" .desktop)

    $ESCALATION_TOOL sed -i '1i[Autologin]\nUser = '"$USERNAME"'\nSession = '"$actual_session"'\n' /etc/sddm.conf
    echo "Autologin configuration complete."

    $ESCALATION_TOOL systemctl restart sddm
}

checkEnv
checkEscalationTool
install_sddm
install_theme
configure_autologin
