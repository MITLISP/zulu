###
# Output usage information
###
function _zulu_install_usage() {
  echo $(_zulu_color yellow "Usage:")
  echo "  zulu install <packages...>"
  echo
  echo $(_zulu_color yellow "Options:")
  echo "      --no-autoselect-themes      Don't autoselect themes after installing"
  echo "      --ignore-dependencies       Don't automatically install dependencies"
  echo "  -b, --branch                    Specify a branch to install"
  echo "  -t, --tag                       Specify a tag to install"
}

###
# Install a package
###
function _zulu_install_package() {
  local package ref json repo dir file link packagetype
  local -a dependencies

  package="$1"
  ref="$2"

  # Check if the package is already installed
  root="$base/packages/$package"
  if [[ -d "$root" ]]; then
    echo $(_zulu_color red "Package '$package' is already installed")
    return 1
  fi

  # Get the JSON from the index
  json=$(cat "$index/$package")
  if [[ $? -ne 0 ]]; then
    echo 'Could not find package in index'
    return 1
  fi

  # Get the repository URL from the JSON
  repo=$(jsonval $json 'repository')
  if [[ $? -ne 0 || -z $repo ]]; then
    echo 'Could not find repository URL'
    return 1
  fi

  # Clone the repository
  cd "$base/packages"

  git clone --recursive --branch $ref $repo $package
  if [[ $? -ne 0 ]]; then
    echo 'Failed to clone repository'
    return 1
  fi

  packagefile="$config/packages"
  in_packagefile=$(cat $packagefile | grep -e '^'${package}'$')
  if [[ "$in_packagefile" = "" ]]; then
    echo "$package" >> $packagefile
  fi

  return
}

###
# Zulu command to handle package installation
###
function _zulu_install() {
  local base index packages out help no_autoselect_themes ignore_dependencies \
    branch tag ref

  # Parse options
  zparseopts -D h=help -help=help \
    -no-autoselect-themes=no_autoselect_themes \
    -ignore-dependencies=ignore_dependencies \
    b:=branch -branch:=branch \
    t:=tag -tag:=tag

  # Output help and return if requested
  if [[ -n $help ]]; then
    _zulu_install_usage
    return
  fi

  if [[ -n $branch && -n $tag ]]; then
    echo $(_zulu_color red 'You must only specify one of branch or tag')
    return 1
  fi

  # Set up some variables
  base=${ZULU_DIR:-"${ZDOTDIR:-$HOME}/.zulu"}
  config=${ZULU_CONFIG_DIR:-"${ZDOTDIR:-$HOME}/.config/zulu"}
  index="${base}/index/packages"

  packages=($@)
  packagefile="$config/packages"

  if [[ ! -f $packagefile ]]; then
    touch $packagefile
  fi

  # If no package name is passed, throw an error
  if [[ ${#packages} -eq 0 ]]; then
    echo $(_zulu_color red "Please specify a package name")
    echo
    _zulu_install_usage
    return 1
  fi

  # Do a first loop, to ensure all packages exist
  for package in "$packages[@]"; do
    if [[ ! -f "$index/$package" ]]; then
      echo $(_zulu_color red "Package '$package' is not in the index")
      return 1
    fi
  done

  # Do a second loop, to do the actual install
  for package in "$packages[@]"; do
    # Get the JSON from the index
    json=$(cat "$index/$package")

    if [[ -z $ignore_dependencies ]]; then
      # Get the list of dependencies from the index
      dependencies=($(echo $(jsonval $json 'dependencies') | tr "," "\n" | sed 's/\[//g' | sed 's/\]//g'))

      # If there are dependencies in the list
      if [[ ${#dependencies} -ne 0 ]]; then
        # Loop through each of the dependencies
        for dependency in "$dependencies[@]"; do
          # Check that the dependency is not already installed
          if [[ ! -d "$base/packages/$dependency" ]]; then
            _zulu_revolver start "Installing dependency $dependency..."
            out=$(_zulu_install_package "$dependency" 2>&1)
            state=$?
            _zulu_revolver stop

            if [ $state -eq 0 ]; then
              echo "$(_zulu_color green '✔') Finished installing dependency $dependency        "
              zulu link $dependency
            else
              echo "$(_zulu_color red '✘') Error installing dependency $dependency        "
              echo "$out"
            fi
          fi
        done
      fi
    fi

    local ref='master'
    if [[ -n $branch ]]; then
      shift branch
      ref=$branch
    fi

    if [[ -n $tag ]]; then
      shift tag
      ref=$tag
    fi

    _zulu_revolver start "Installing $package..."
    out=$(_zulu_install_package "$package" "$ref" 2>&1)
    state=$?
    _zulu_revolver stop

    if [ $state -eq 0 ]; then
      local -a link_flags; link_flags=()

      if [[ -n $no_autoselect_themes ]]; then
        link_flags=($link_flags '--no-autoselect-themes')
      fi

      echo "$(_zulu_color green '✔') Finished installing $package        "
      zulu link $link_flags $package
    else
      echo "$(_zulu_color red '✘') Error installing $package        "
      echo "$out"
    fi
  done
}
