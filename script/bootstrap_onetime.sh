install_tailwindcss() { 
    pnpm install -D tailwindcss postcss autoprefixer
    pnpm tailwind init -p 

    pnpm install -D prettier prettier-plugin-tailwindcss

    example() { 
        pnpm tailwindcss -i ./src/input.css -o ./src/output.css --watch
    }
}