dev() { 
    pnpm run dev
}

bootstrap() { 
    install_eslint() { 
        pnpm install --save-dev eslint eslint-import-resolver-typescript eslint-plugin-import
        pnpm eslint . 
    }
}