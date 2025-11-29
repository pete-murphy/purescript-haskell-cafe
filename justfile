# https://just.systems

@help:
    just --list

@run:
    npx vite dev

@test:
    npx spago test

@build:
    npx spago build
    npm run build

@deploy:
    npx wrangler deploy

@file-server:
    npx http-server -p 8080 ./file-server

# Populate the file server with the haskell-cafe archive
@script:
    npx spago run --main Script.Main