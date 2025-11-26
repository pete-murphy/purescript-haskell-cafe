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
