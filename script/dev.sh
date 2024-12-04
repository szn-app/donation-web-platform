misc() { 
   cargo create-tauri-app 
}



develop_tauri_desktop_with_workaround_black_screen() { 
    cd ./service/web-server
    WEBKIT_DISABLE_COMPOSITING_MODE=1 cargo tauri dev
}

develop_tauri_android() { 
    ./script.sh setup_android_sdk_variables

    cargo tauri android init
    cargo tauri android dev
}

develop_pnpm_react() { 
    cd web-server
    pnpm install
    WEBKIT_DISABLE_COMPOSITING_MODE=1 cargo tauri dev
}

build() {
    pnpm install
    NO_STRIP=true cargo tauri build 
    WEBKIT_DISABLE_COMPOSITING_MODE=1 ./src-tauri/target/release/bundle/appimage/*.AppImage
}