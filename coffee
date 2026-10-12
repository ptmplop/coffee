#!/usr/bin/env bash
# coffee — keep the Mac awake (caffeinate -dimsu) with a happy cup of coffee.
# Ctrl-C to stop and let the Mac sleep normally again.
#
# Stock macOS is all it needs: it runs on the system bash 3.2.
# 256 colours by default, 24-bit when COLORTERM=truecolor, line art if NO_COLOR.

set -u

VERSION=1.0.0

case ${1:-} in
  '') ;;
  -h|--help)
    cat <<EOF
coffee $VERSION — keep your Mac awake, with a happy cup of coffee for company.

usage: coffee

Runs caffeinate -dimsu until you press Ctrl-C, then lets the Mac sleep again.
NO_COLOR=1 draws the cup in plain line art. https://github.com/ptmplop/coffee
EOF
    exit 0 ;;
  -v|--version) echo "coffee $VERSION"; exit 0 ;;
  *) echo "coffee: unknown option '$1' (see coffee --help)" >&2; exit 2 ;;
esac

if ! command -v caffeinate >/dev/null 2>&1; then
  echo "coffee: caffeinate not found (this tool is macOS-only)" >&2
  exit 1
fi

# -w $$ ties caffeinate to this script, so it lets go however we exit.
caffeinate -dimsu -w $$ &
caf_pid=$!
start=$SECONDS
since=$(date +%H:%M)

# Piped or logged instead of on screen: stay awake without the show.
if [ ! -t 1 ] || [ "${TERM:-dumb}" = dumb ]; then
  trap 'kill "$caf_pid" 2>/dev/null; exit 0' INT TERM HUP
  echo "coffee: keeping the Mac awake since $since (Ctrl-C to stop)"
  wait "$caf_pid"
  echo "coffee: caffeinate stopped, so the Mac can sleep again" >&2
  exit 1
fi

E=$'\033'
if [ -n "${NO_COLOR:-}" ]; then depth=0
else case ${COLORTERM:-} in truecolor|24bit) depth=24 ;; *) depth=256 ;; esac
fi

# ── Colours ──────────────────────────────────────────────────────────────────
# Each colour has a 256-colour index and a 24-bit value; P gets the one in use.
rgb() { if [ $depth = 24 ]; then P="2;$2"; else P="5;$1"; fi; }

pixel() {  # pixel key → P, the colour after SGR 38;/48; (empty = see-through)
  case $1 in
    o) rgb 236 '46;40;41'    ;;  # ink outline
    w) rgb 223 '255;217;179' ;;  # apricot mug
    s) rgb 180 '232;185;142' ;;  # its shadow side
    h) rgb 231 '255;248;238' ;;  # its shine
    c) rgb 95  '122;74;42'   ;;  # coffee
    k) rgb 237 '74;42;26'    ;;  # coffee in the shade of the rim
    l) rgb 137 '184;132;87'  ;;  # crema
    e) rgb 235 '42;34;35'    ;;  # eyes and smile
    p) rgb 210 '255;135;135' ;;  # cheeks
    d) rgb 255 '242;242;242' ;;  # saucer
    D) rgb 250 '196;196;196' ;;  # saucer rim
    z) rgb 247 '160;160;160' ;;  # steam
    *) P= ;;
  esac
}

rgb 166 '217;102;31'; tint="$E[38;${P}m"
bold="$E[1m" faint="$E[2m" off="$E[0m"
[ $depth = 0 ] && tint=

# ── The cup ──────────────────────────────────────────────────────────────────
# One character per pixel; render() folds two pixel rows into one text line.
cup=(
'.......oooooooooo...........'
'.....oowwwwwwwwwwoo.........'
'....owwkkkkkkkkkkwwo........'
'...owwkclllcccccckwwo.......'
'...owwwccccccccccwwwo.......'
'...owwwwwwwwwwwwwwwwo.......'
'...owhwwwwwwwwwwwwwsooooo...'
'...owhwwwwwwwwwwwwwsowwwwo..'
'...owhwweewwwweewwwsoooowwo.'
'...owhwweewwwweewwwso..owwo.'
'...owhppwwwwwwwwppwso..owwo.'
'...owhwwwwewwewwwwwsoooowwo.'
'...owhwwwwweewwwwwwsowwwwo..'
'...owhwwwwwwwwwwwwwsooooo...'
'...owhwwwwwwwwwwwwwso.......'
'..ooossssssssssssssooo......'
'.odddoooooooooooooodddo.....'
'oDDDDDDDDDDDDDDDDDDDDDDo....'
'.oooooooooooooooooooooo.....'
'............................'
)
# Other faces: rows 8 and 9 (the eyes) swapped in.
shut='...owhwwwwwwwwwwwwwsoooowwo.'      # blink (row 8; row 9 is the closed lids)
wink='...owhwweewwwwwwwwwsoooowwo.'      # right eye closed
squint8='...owhwwewwwwwwewwwsoooowwo.'   # a contented ^ ^ ...
squint9='...owhwewewwwwewewwso..owwo.'
air='............................'

# Pairs of pixel rows → text lines in OUT[]. Where both halves match, the cell
# is a space on that background (seamless in every terminal); where they
# differ it's ▀/▄ with one colour in front and the other behind.
render() {
  local top bot line x n=${#1} k=0 a b fg bg nf nb ch
  OUT=()
  while [ $# -ge 2 ]; do
    top=$1 bot=$2
    shift 2
    line= fg=- bg=
    for (( x = 0; x < n; x++ )); do
      pixel "${top:x:1}"; a=$P
      pixel "${bot:x:1}"; b=$P
      if [ "$a" = "$b" ]; then nb=$a nf=$fg ch=' '
      elif [ -z "$b" ]; then nb= nf=$a ch='▀'
      elif [ -z "$a" ]; then nb= nf=$b ch='▄'
      else nb=$b nf=$a ch='▀'
      fi
      if [ "$nb" != "$bg" ]; then
        if [ -n "$nb" ]; then line+="$E[48;${nb}m"; else line+="$E[49m"; fi
        bg=$nb
      fi
      if [ "$nf" != "$fg" ]; then line+="$E[38;${nf}m"; fg=$nf; fi
      line+=$ch
    done
    OUT[k]="$line$off"
    k=$((k + 1))
  done
}

# The same pixels at double size, for big windows: each pixel is two whole
# cells, so the cup is pure background colour. "fg" draws █ instead, which the
# faint attribute can fade (the steam needs that).
render2() {  # $1 = bg|fg, then pixel rows → OUT[], one line per row
  local how=$1 row line x n k=0 a cur
  shift
  n=${#1}
  OUT=()
  for row in "$@"; do
    line= cur=-
    for (( x = 0; x < n; x++ )); do
      pixel "${row:x:1}"; a=$P
      if [ $how = fg ]; then
        if [ -z "$a" ]; then line+='  '; continue; fi
        if [ "$a" != "$cur" ]; then line+="$E[38;${a}m"; cur=$a; fi
        line+='██'
      else
        if [ "$a" != "$cur" ]; then
          if [ -n "$a" ]; then line+="$E[48;${a}m"; else line+="$E[49m"; fi
          cur=$a
        fi
        line+='  '
      fi
    done
    OUT[k]="$line$off"
    k=$((k + 1))
  done
}

# Two wisps rise off the coffee, rooted at the bottom and swaying together
# above it, each growing and shrinking; the top line is faint. The loop
# repeats every 16 ticks, so each tick is rendered once and kept.
wx=(9 14)
wob=(0 1 1 1 0 -1 -1 -1)
steam() {  # $1 = tick (0-15) → STEAMS[tick * 8 + line]
  local t=$1 i y x n row
  local px
  px=("$air" "$air" "$air" "$air" "$air" "$air" "$air" "$air")
  for i in 0 1; do
    n=$(( (t / 2 + i * 3) % 8 ))
    [ $n -gt 4 ] && n=$((8 - n))
    for (( y = 7; y > 3 - n; y-- )); do
      x=$(( wx[i] + (y > 5 ? 0 : wob[(y + t + i) % 8]) ))
      row=${px[y]}
      px[y]=${row:0:x}z${row:x+1}
    done
  done
  if [ $zoom = 2 ]; then
    render2 fg "${px[@]}"
    OUT[0]="$faint${OUT[0]}" OUT[1]="$faint${OUT[1]}"
  else
    render "${px[@]}"
    OUT[0]="$faint${OUT[0]}"
  fi
  for (( i = 0; i < 4 * zoom; i++ )); do STEAMS[t * 8 + i]=${OUT[i]}; done
}

paint() {  # the cup and its faces at the current zoom → CUP[], EYES[face * 2 + line]
  if [ $zoom = 2 ]; then
    render2 bg "${cup[@]}"; CUP=("${OUT[@]}")
    EYES=("${CUP[8]}" "${CUP[9]}")
    render2 bg "$shut" "${cup[9]}"; EYES[2]=${OUT[0]} EYES[3]=${OUT[1]}
    render2 bg "$wink" "${cup[9]}"; EYES[4]=${OUT[0]} EYES[5]=${OUT[1]}
    render2 bg "$squint8" "$squint9"; EYES[6]=${OUT[0]} EYES[7]=${OUT[1]}
  else
    render "${cup[@]}"; CUP=("${OUT[@]}")
    EYES=("${CUP[4]}" '')
    render "$shut" "${cup[9]}"; EYES[2]=${OUT[0]} EYES[3]=
    render "$wink" "${cup[9]}"; EYES[4]=${OUT[0]} EYES[5]=
    render "$squint8" "$squint9"; EYES[6]=${OUT[0]} EYES[7]=
  fi
  STEAMS=()
  painted=$zoom
}

# Blink every few seconds; now and then a wink, or a contented squint.
next_blink=12 blink_face=1 blink_len=1
face_at() {  # $1 = tick → face: 0 open, 1 blink, 2 wink, 3 squint
  face=0
  [ $1 -lt $next_blink ] && return
  face=$blink_face
  if [ $1 -ge $((next_blink + blink_len - 1)) ]; then
    next_blink=$(( $1 + 12 + RANDOM % 16 ))
    case $((RANDOM % 8)) in
      0) blink_face=2 blink_len=4 ;;
      1) blink_face=3 blink_len=8 ;;
      *) blink_face=1 blink_len=1 ;;
    esac
  fi
}

# ── Screen ───────────────────────────────────────────────────────────────────
clock() {  # seconds → T, e.g. 1:02:03
  printf -v T '%d:%02d:%02d' $(($1 / 3600)) $(($1 % 3600 / 60)) $(($1 % 60))
}

human() {  # seconds → H, e.g. 42s, 12m 05s, 2h 07m
  if [ $1 -lt 60 ]; then H="${1}s"
  elif [ $1 -lt 3600 ]; then printf -v H '%dm %02ds' $(($1 / 60)) $(($1 % 60))
  else printf -v H '%dh %02dm' $(($1 / 3600)) $(($1 % 3600 / 60)); fi
}

measure() {
  local size
  trap '' TSTP                     # a Ctrl-Z now would stop stty and hang us
  size=$(stty size </dev/tty 2>/dev/null)
  trap 'stop=1' TSTP
  rows=${size% *} cols=${size#* }
  case "$rows$cols" in ''|*[!0-9]*) rows=0 ;; esac
  [ "$rows" -gt 0 ] && [ "$cols" -gt 0 ] || { rows=24 cols=80; }   # unknown size
  zoom=1
  if [ $depth != 0 ] && [ $cols -ge 64 ] && [ $rows -ge 34 ]; then view=pixels zoom=2 h=31
  elif [ $depth != 0 ] && [ $cols -ge 32 ] && [ $rows -ge 18 ]; then view=pixels h=17
  elif [ $cols -ge 24 ] && [ $rows -ge 11 ]; then view=lines h=11
  else view=text h=2
  fi
  top=$(( (rows - h) / 2 + 1 ))
  left=$(( (cols - 24 * zoom) / 2 + 1 ))   # centre on the saucer; the handle hangs off
  [ $view = pixels ] && [ $zoom != $painted ] && paint
}

status() {  # $1 = screen row. Both lines share a left edge: the timer sits over Ctrl-C.
  local y=$1 x w
  clock $((SECONDS - start))
  [ $full = 0 ] && [ "$T" = "$shown_T" ] && return
  shown_T=$T
  if [ $cols -ge 29 ]; then
    x=$(( (cols - 29) / 2 + 1 ))
    buf+="$E[$y;${x}H${bold}Staying awake$off  $bold$tint$T$off"
    [ $full = 1 ] && [ $y -lt $rows ] &&
      buf+="$E[$((y + 1));${x}H${faint}since $since$off    Ctrl-C$faint to stop$off"
  elif [ $cols -ge $((7 + ${#T})) ] && [ $cols -ge 14 ]; then
    w=$((7 + ${#T})); [ $w -lt 14 ] && w=14
    x=$(( (cols - w) / 2 + 1 ))
    buf+="$E[$y;${x}H${bold}Awake$off  $bold$tint$T$off"
    [ $full = 1 ] && [ $y -lt $rows ] && buf+="$E[$((y + 1));${x}HCtrl-C$faint to stop$off"
  elif [ $cols -ge ${#T} ]; then
    buf+="$E[$y;$(( (cols - ${#T}) / 2 + 1 ))H$bold$tint$T$off"
  fi
}

lineart() {  # $1 = tick; the original line-art cup, used when NO_COLOR is set
  local x=$((left + 5)) y=$top s1 s2 eyes
  if [ $(($1 / 2 % 2)) = 0 ]; then s1='(   (' s2=' )   )'; else s1=' )   )' s2='(   ('; fi
  case $face in 1) eyes='─     ─' ;; 2) eyes='^     ─' ;; *) eyes='^     ^' ;; esac
  buf+="$E[$y;$((x + 3))H$faint$s1$off$E[K"
  buf+="$E[$((y + 1));$((x + 3))H$s2$E[K"
  buf+="$E[$((y + 2));$((x + 3))H$s1$E[K"
  buf+="$E[$((y + 3));${x}H╭───────────╮"
  buf+="$E[$((y + 4));${x}H│  $eyes  ├──╮"
  buf+="$E[$((y + 5));${x}H│     ‿     │  │"
  buf+="$E[$((y + 6));${x}H│           ├──╯"
  buf+="$E[$((y + 7));$((x - 2))H──┴───────────┴──"
}

# Only what changed is sent: the steam, the timer once a second, the eyes when
# they move. Everything is repainted every 16 ticks, in case anything else
# wrote on the screen.
draw() {  # $1 = tick
  local t=$1 i j n line
  face_at $t
  buf="$E[?2026h"
  [ $((t % 16)) = 0 ] && full=1
  if [ $wipe = 1 ]; then buf+="$E[2J"; wipe=0; full=1; fi
  case $view in
    pixels)
      n=$((4 * zoom))   # lines of steam; the eyes are on that line of the cup too
      [ -z "${STEAMS[t % 16 * 8]:-}" ] && steam $((t % 16))
      for (( i = 0; i < n; i++ )); do buf+="$E[$((top + i));${left}H${STEAMS[t % 16 * 8 + i]}"; done
      if [ $full = 1 ] || [ $face != $shown_face ]; then
        for (( i = 0; i < 10 * zoom; i++ )); do
          j=$((i - n))
          if [ $j -ge 0 ] && [ $j -lt $zoom ]; then line=${EYES[face * 2 + j]}
          elif [ $full = 1 ]; then line=${CUP[i]}
          else continue
          fi
          buf+="$E[$((top + n + i));${left}H$line"
        done
        shown_face=$face
      fi
      status $((top + 14 * zoom + 1)) ;;
    lines)
      lineart $t
      status $((top + 9)) ;;
    *)
      status $top ;;
  esac
  full=0
  buf+="$E[?2026l"
  printf '%s' "$buf"
}

setup_term() {
  [ -n "$tty_state" ] && stty -echo 2>/dev/null
  printf '%s' "$E[?1049h$E[?25l$E[?7l"
  wipe=1 onscreen=1
}

restore_term() {  # retried: in bash 3.2 a signal can interrupt this write and lose it
  local i
  for i in 1 2 3; do
    printf '%s' "$E[?2026l$E[0m$E[?7h$E[?25h$E[?1049l" 2>/dev/null && break
  done
  [ -n "$tty_state" ] && stty "$tty_state" 2>/dev/null
  onscreen=0
}

# Ctrl-Z: hand the terminal back in a sane state, stop, and carry on after fg.
# Run from the main loop, not the trap, and stop with TSTP rather than STOP:
# with no shell around to resume us, the kernel drops TSTP and we keep going.
ctrl_z() {
  trap '' TSTP
  restore_term
  trap - TSTP
  kill -TSTP $$
  trap '' TSTP
  setup_term
  trap 'stop=1' TSTP
  resized=1
}

cleanup() {
  trap '' INT TERM HUP TSTP WINCH TTOU TTIN
  [ $onscreen = 1 ] && restore_term
  kill "$caf_pid" 2>/dev/null
  [ $quiet = 1 ] && return
  human $((SECONDS - start))
  if [ $failed = 1 ]; then
    echo "coffee: caffeinate stopped after $H, so the Mac can sleep again" >&2
  else
    printf '☕ %sCoffee break over%s after %s%s%s. Your Mac can sleep again 😴\n' "$bold" "$off" "$tint" "$H" "$off"
  fi
}

# ── Go ───────────────────────────────────────────────────────────────────────
tty_state=
[ -t 0 ] && tty_state=$(stty -g 2>/dev/null)
quiet=0 failed=0 resized=0 stop=0 onscreen=0 painted=0
full=1 shown_face=-1 shown_T=
trap cleanup EXIT
trap 'exit 0' INT TERM
trap 'quiet=1; exit 0' HUP
trap 'resized=1' WINCH
trap '' TSTP              # no Ctrl-Z until we're on screen
setup_term
measure                   # (and from here on, Ctrl-Z sets stop)

t=0
while :; do
  if [ $stop = 1 ]; then stop=0; ctrl_z; fi
  if [ $resized = 1 ]; then resized=0; measure; wipe=1; fi
  draw $t
  sleep 0.25 & wait $!       # wait, not a plain sleep: traps fire straight away
  kill -0 "$caf_pid" 2>/dev/null || { failed=1; exit 1; }
  t=$((t + 1))
done
