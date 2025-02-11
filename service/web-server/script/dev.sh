dev_web_server() { 
    pnpm run dev
    pnpm run lint -- --debug
    pnpm run lint -- --fix
}

bootstrap_web_server() { 
    # https://typescript-eslint.io/getting-started/
    # https://react-v9.holt.courses/lessons/tools/linting
    install_eslint() { 
        pnpm add --save-dev eslint @eslint/js typescript typescript-eslint eslint-config-prettier
        pnpm run eslint --init
    }

    # https://react-v9.holt.courses/lessons/tools/code-formatting
    install_prettier() { 
        pnpm install --save-dev prettier
        # create prettier.config.js
    }

    install_shadcn() { 
        pnpm dlx shadcn@latest init
    }

    install_tanstack_router() {
        # https://tanstack.com/router/latest/docs/framework/react/quick-start#using-file-based-route-generation
        echo ''
     }
}

add_shadcn_components() { 
    pnpm dlx shadcn@latest add "component-name" 
}