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
}   