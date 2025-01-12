install_tailwindcss() { 
    pnpm install -D tailwindcss postcss autoprefixer
    pnpm dlx tailwindcss init -p
    
    pnpm install -D prettier prettier-plugin-tailwindcss

    example() { 
        pnpm tailwindcss -i ./src/input.css -o ./src/output.css --watch
    }
}

install_shadcn_for_vite() { 
    install_tailwindcss

    # follow https://ui.shadcn.com/docs/installation/vite
    # [manual] setup configs and paths resolution

    pnpm dlx shadcn@latest init
    pnpm dlx shadcn@latest add button
}   

install_nextui() {
    # https://nextui.org/docs/guide/installation#global-installation
    pnpm add @nextui-org/react framer-motion
    echo "public-hoist-pattern[]=*@nextui-org/*" > .npmrc && pnpm install

    pnpm add @nextui-org/button
    # [manual] add component styles to tailwind.config.js
}