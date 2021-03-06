###
# Get the value for a key in a JSON object
#
# IMPORTANT: There must be no newlines within nested objects
###
function jsonval {
  local temp json=$1 key=$2

  temp=$(echo $json | sed 's/\\\\\//\//g' | \
    sed 's/[{}]//g' | \
    sed 's/\"\:\"/\|/g' | \
    sed 's/[\,]/ /g' | \
    sed 's/\"//g' | \
    grep -w $key | \
    cut -d":" -f2-9999999 | \
    sed -e 's/^ *//g' -e 's/ *$//g'
  )
  echo ${temp##*|}
}

###
# If the revolver command is not installed, create a simple polyfill
# function to prevent COMMAND_NOT_FOUND errors
###
function _zulu_color {
  $(type color 2>&1 > /dev/null)
  if [[ $? -ne 0 && ! -x ${ZULU_DIR:-"${ZDOTDIR:-$HOME}/bin/color"} ]]; then
    local color=$1 style=$2 b=0

    shift

    case $style in
      bold|b)           b=1; shift ;;
      italic|i)         b=2; shift ;;
      underline|u)      b=4; shift ;;
      inverse|in)       b=7; shift ;;
      strikethrough|s)  b=9; shift ;;
    esac

    case $color in
      black|b)    echo "\033[${b};30m${@}\033[0;m" ;;
      red|r)      echo "\033[${b};31m${@}\033[0;m" ;;
      green|g)    echo "\033[${b};32m${@}\033[0;m" ;;
      yellow|y)   echo "\033[${b};33m${@}\033[0;m" ;;
      blue|bl)    echo "\033[${b};34m${@}\033[0;m" ;;
      magenta|m)  echo "\033[${b};35m${@}\033[0;m" ;;
      cyan|c)     echo "\033[${b};36m${@}\033[0;m" ;;
      white|w)    echo "\033[${b};37m${@}\033[0;m" ;;
    esac

    return
  fi

  color "$@"
}

###
# If the revolver command is not installed, create an empty
# function to prevent COMMAND_NOT_FOUND errors
###
function _zulu_revolver {
  if [[ $ZULU_NO_PROGRESS -eq 1 ]]; then
    return
  fi

  $(type revolver 2>&1 > /dev/null)
  if [[ $? -ne 0 && ! -x ${ZULU_DIR:-"${ZDOTDIR:-$HOME}/bin/revolver"} ]]; then
    # Check for a revolver process file, and remove it if it exists.
    # Revolver will handle the missing state and kill any orphaned process.
    if [[ -f "${ZDOTDIR:-$HOME}/.revolver/${$}" ]]; then
      rm "${ZDOTDIR:-$HOME}/.revolver/${$}"
    fi
    return
  fi

  revolver "$@"
}
