# source this before calling quarto in the permafrost env
. "$CONDA_PREFIX/etc/conda/activate.d/quarto.sh"
export DENO_DIR="$CONDA_PREFIX/bin/deno_cache"
mkdir -p "$PWD/.qhome/Library/Caches"
export HOME="$PWD/.qhome"
