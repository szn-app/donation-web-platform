dev() { 
    pnpm run dev
    pnpm run lint -- --debug
    pnpm run lint -- --fix
}

bootstrap() { 
    # https://typescript-eslint.io/getting-started/
    # https://react-v9.holt.courses/lessons/tools/linting
    install_eslint() { 
        pnpm add --save-dev eslint @eslint/js typescript typescript-eslint eslint-config-prettier
        pnpm run eslint --init
    }

    # https://react-v9.holt.courses/lessons/tools/code-formatting
    install_prettier() { 
        pnpm install --save-dev prettier
        # create .prettierrc
    }
}