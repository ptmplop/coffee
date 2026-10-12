#!/usr/bin/env bash
# Install coffee — keep your Mac awake, with a happy cup of coffee for company.
#
#   curl -fsSL https://github.com/ptmplop/coffee/releases/latest/download/install.sh | bash
#
# coffee goes in the first of ~/.local/bin, ~/bin, /usr/local/bin and
# /opt/homebrew/bin that is on your PATH and writable, or in a directory you
# name (... | bash -s -- ~/somewhere). It never uses sudo or touches anything
# else. Run it again to update.
#
# Everything happens in main, called on the last line, so a download cut off
# halfway runs nothing.

main() {
  set -eu
  local url=${COFFEE_URL:-https://github.com/ptmplop/coffee/releases/latest/download/coffee}
  local dir=${1:-} d version

  if [ -z "$dir" ]; then
    for d in "$HOME/.local/bin" "$HOME/bin" /usr/local/bin /opt/homebrew/bin; do
      if on_path "$d" && [ -d "$d" ] && [ -w "$d" ]; then dir=$d; break; fi
    done
    [ -n "$dir" ] || dir=$HOME/.local/bin
  fi
  mkdir -p "$dir" 2>/dev/null || :
  if [ ! -w "$dir" ]; then
    echo "coffee: can't write to $dir. Name another directory: ... | bash -s -- ~/bin" >&2
    exit 1
  fi

  tmp=$(mktemp "${TMPDIR:-/tmp}/coffee.XXXXXX")   # global: the trap runs after main returns
  trap 'rm -f "${tmp:-}"' EXIT
  if ! curl -fsSL "$url" -o "$tmp"; then
    echo "coffee: couldn't download $url, so nothing was installed" >&2
    exit 1
  fi
  if [ "$(head -n 1 "$tmp")" != '#!/usr/bin/env bash' ] || ! bash -n "$tmp" 2>/dev/null; then
    echo "coffee: the download from $url doesn't look right, so nothing was installed" >&2
    exit 1
  fi
  version=$(bash "$tmp" --version </dev/null)
  chmod 755 "$tmp"
  mv -f "$tmp" "$dir/coffee"

  echo "☕ $version is in $dir"
  if ! on_path "$dir"; then
    echo "   $dir isn't on your PATH yet. Add it, then open a new terminal:"
    echo "   echo 'export PATH=\"$dir:\$PATH\"' >> ~/.zshrc"
  elif [ "$(command -v coffee)" != "$dir/coffee" ]; then
    echo "   Another coffee comes first on your PATH: $(command -v coffee)"
  else
    echo "   Run it: coffee"
  fi
  if [ "$(uname -s)" != Darwin ]; then
    echo "   (coffee is for macOS: it needs caffeinate)"
  fi
}

on_path() {
  case ":$PATH:" in *":$1:"*) return 0 ;; esac
  return 1
}

main "$@"
