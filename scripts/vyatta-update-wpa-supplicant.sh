#!/bin/bash
# shellcheck disable=SC2018,SC2019

action="$1"
if="$2"
unit=wpa_supplicant-wired@"$if".service
config_path=/etc/wpa_supplicant/wpa_supplicant-wired-"$if".conf

if [[ "$action" = DELETE ]]; then
    echo "Disabling $unit..."
    systemctl disable "$unit" --now
    echo "Removing $config_path..."
    rm -f "$config_path"
else
    echo "Re-generating $config_path..."

    stage_config_path=/etc/wpa_supplicant/.wpa_supplicant-wired-"$if".conf
    {
        echo 'network={'
        eap=()
        eval "eap=($(cli-shell-api returnValues interfaces ethernet "$if" eapol eap | tr a-z A-Z))"
        if (( ${#eap[@]} )); then
            echo '    eap='"${eap[*]}"
        fi
        echo '    key_mgmt=IEEE8021X'
        echo '    eapol_flags=0'
        echo '    identity="'"$(cli-shell-api returnValue interfaces ethernet "$if" eapol identity)"'"'
        echo '    ca_cert="'"$(cli-shell-api returnValue interfaces ethernet "$if" eapol ca-cert-file)"'"'
        echo '    client_cert="'"$(cli-shell-api returnValue interfaces ethernet "$if" eapol cert-file)"'"'
        echo '    private_key="'"$(cli-shell-api returnValue interfaces ethernet "$if" eapol key-file)"'"'
        phase1=()
        if [[ "$(cli-shell-api returnValue interfaces ethernet "$if" eapol allow-canned-success)" = true ]]; then
            phase1+=("allow_canned_success=1")
        fi
        echo '    phase1="'"${phase1[*]}"'"'
        echo '}'
    } > "$stage_config_path"
    mv "$stage_config_path" "$config_path"

    echo "Enabling/restarting $unit..."
    systemctl enable "$unit"
    systemctl restart "$unit"
fi
