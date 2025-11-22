# https://just.systems

@help:
    just --list

@run:
    npx vite dev

@test:
    npx spago test

@test-one PATTERN:
    # Run tests matching PATTERN (requires spec-node)
    # First install: npx spago install spec-node
    # Example: just test-one "extracts author correctly"
    npx spago test -- --match PATTERN

@build:
    npx spago build