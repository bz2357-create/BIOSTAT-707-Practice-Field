# Conda's Quarto activation already sets QUARTO_DART_SASS to the bundled binary.
# Replace that default for affected POSIX checkouts: Dart Sass interprets colons
# in absolute positional paths as source:destination separators.
case "${PIXI_PROJECT_ROOT:-}" in
  *:*) export QUARTO_DART_SASS="${PIXI_PROJECT_ROOT}/scripts/quarto-sass.py" ;;
esac
