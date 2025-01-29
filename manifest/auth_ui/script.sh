generate_secret_auth_ui() {
# generate secrets for production
    auth_ui_secret_file="./manifest/auth_ui/production/secret.env"
    if [ ! -f "$auth_ui_secret_file" ]; then
        t=$(mktemp) && cat <<EOF > "$t"
COOKIE_SECRET="$(openssl rand -base64 32)"
CSRF_COOKIE_NAME="$(shuf -n 1 /usr/share/dict/words | tr -d '\n')_csrf"
CSRF_COOKIE_SECRET="$(openssl rand -base64 32)"
EOF

        mv $t $auth_ui_secret_file
        echo "generated secrets file: file://$auth_ui_secret_file" 
    fi
}
