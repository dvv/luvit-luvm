# Luvit Version Manager
# Implemented as a bash function
# To use source this file from your bash profile
#
# Made after Tim Caswell's nvm

# Auto detect the LUVM_DIR
if [ ! -d "$LUVM_DIR" ]; then
  export LUVM_DIR=$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)
fi

# Use curl, or wget, what available
if [ `which curl` ]; then
  GET='curl -L --progress-bar'
else
  GET='wget -q --progress=bar --no-check-certificate -O -'
fi

# Expand a version using the version cache
luvm_version()
{
  PATTERN=$1
  VERSION=''
  if [ -f "$LUVM_DIR/alias/$PATTERN" ]; then
    luvm_version `cat $LUVM_DIR/alias/$PATTERN`
    return
  fi
  # If it looks like an explicit version, don't do anything funny
  if [[ "$PATTERN" == ?*.?*.?* ]]; then
    VERSION="$PATTERN"
  fi
  # The default version is the current one
  if [ ! "$PATTERN" -o "$PATTERN" = 'current' ]; then
    VERSION=`luvit -v 2>/dev/null`
  fi
  if [ "$PATTERN" = 'all' ]; then
    (cd $LUVM_DIR; \ls -dG v* 2>/dev/null || echo "N/A")
    return
  fi
  if [ ! "$VERSION" ]; then
    VERSION=`(cd $LUVM_DIR; \ls -d ${PATTERN}* 2>/dev/null) | sort -t. -k 2,1n -k 2,2n -k 3,3n | tail -n1`
  fi
  if [ ! "$VERSION" ]; then
    echo "N/A"
    return 13
  elif [ -e "$LUVM_DIR/$VERSION" ]; then
    (cd $LUVM_DIR; \ls -dG "$VERSION")
  else
    echo "$VERSION"
  fi
}

luvm()
{
  if [ $# -lt 1 ]; then
    luvm help
    return 1
  fi
  case $1 in
    "help" )
      echo
      echo "Luvit Version Manager"
      echo
      echo "Usage:"
      echo "    luvm help                    Show this message"
      echo "    luvm install <version>       Download and install a <version>"
      echo "    luvm uninstall <version>     Uninstall a version"
      echo "    luvm use <version>           Modify PATH to use <version>"
      echo "    luvm run <version> [<args>]  Run <version> with <args> as arguments"
      echo "    luvm ls                      List installed versions"
      echo "    luvm ls <version>            List versions matching a given description"
      echo "    luvm deactivate              Undo effects of luvm on current shell"
      echo "    luvm alias [<pattern>]       Show all aliases beginning with <pattern>"
      echo "    luvm alias <name> <version>  Set an alias named <name> pointing to <version>"
      echo "    luvm unalias <name>          Deletes the alias named <name>"
      echo "    luvm heart                   Install heart package manager"
      echo
      echo "Example:"
      echo "    luvm install 0.0.1           Install a specific version number"
      echo "    luvm use 0.0.2               Use the latest available 0.2.x release"
      echo "    luvm run 0.4.12 myApp.lua    Run myApp.lua using luvit 0.4.12"
      echo "    luvm alias default 0.4       Auto use the latest installed 0.4.x version"
      echo
    ;;
    "install" )
      if [ $# -ne 2 ]; then
        luvm help
        return 1
      fi
      VERSION=`luvm_version $2`

      [ -d "$LUVM_DIR/$VERSION" ] && echo "$VERSION is already installed." && return

      if (
        mkdir -p "$LUVM_DIR/src" && \
        cd "$LUVM_DIR/src" && \
        eval $GET "http://luvit.io/dist/$VERSION/luvit-$VERSION.tar.gz" | tar -xzpf - && \
        cd "luvit-$VERSION" && \
        PREFIX="$LUVM_DIR/$VERSION" make && \
        rm -fr "$LUVM_DIR/$VERSION" 2>/dev/null && \
        mkdir "$LUVM_DIR/$VERSION" && \
        PREFIX="$LUVM_DIR/$VERSION" make install
        )
      then
        luvm use $VERSION
        # install lui -- a simple npm surrogate
        if ! which lui ; then
          echo "Installing lui..."
          eval $GET https://github.com/luvit/lui/raw/master/lui >"$LUVM_DIR/$VERSION/bin/lui" && \
          chmod a+x "$LUVM_DIR/$VERSION/bin/lui"
        fi
      else
        echo "luvm: install $VERSION failed!"
      fi
    ;;
    "heart" )
      if ! which heart ; then
        echo "Installing heart package manager..."
        VERSION=`luvm_version`
        mkdir -p "$LUVM_DIR/src" && \
        cd "$LUVM_DIR/src" && \
        eval $GET https://github.com/luvit/heart/tarball/master | tar -xzpf - && \
        rm -fr heart && \
        mv luvit-heart* heart && \
        PREFIX="$LUVM_DIR/$VERSION" make -C heart install
      fi
    ;;
    "uninstall" )
      [ $# -ne 2 ] && luvm help && return
      if [[ $2 == `luvm_version` ]]; then
        echo "luvm: Cannot uninstall currently-active luvit version, $2."
        return 1
      fi
      VERSION=`luvm_version $2`
      if [ ! -d $LUVM_DIR/$VERSION ]; then
        echo "$VERSION version is not installed yet"
        return 1
      fi

      # Delete all files related to target version.
      (mkdir -p "$LUVM_DIR/src" && \
          cd "$LUVM_DIR/src" && \
          rm -rf "luvit-$VERSION" 2>/dev/null && \
          rm -f "luvit-$VERSION.tar.gz" 2>/dev/null && \
          rm -rf "$LUVM_DIR/$VERSION" 2>/dev/null)
      echo "Uninstalled luvit $VERSION"

      # Rm any aliases that point to uninstalled version.
      for A in `grep -l $VERSION $LUVM_DIR/alias/*`
      do
        luvm unalias `basename $A`
      done

    ;;
    "deactivate" )
      if [[ $PATH == *$LUVM_DIR/*/bin* ]]; then
        export PATH=${PATH%$LUVM_DIR/*/bin*}${PATH#*$LUVM_DIR/*/bin:}
        hash -r
        echo "$LUVM_DIR/*/bin removed from \$PATH"
      else
        echo "Could not find $LUVM_DIR/*/bin in \$PATH"
      fi
    ;;
    "use" )
      if [ $# -ne 2 ]; then
        luvm help
        return 1
      fi
      VERSION=`luvm_version $2`
      if [ ! -d $LUVM_DIR/$VERSION ]; then
        echo "$VERSION version is not installed yet"
        return 1
      fi
      if [[ $PATH == *$LUVM_DIR/*/bin* ]]; then
        PATH=${PATH%$LUVM_DIR/*/bin*}$LUVM_DIR/$VERSION/bin${PATH#*$LUVM_DIR/*/bin}
      else
        PATH="$LUVM_DIR/$VERSION/bin:$PATH"
      fi
      export PATH
      hash -r
      echo "Now using luvit $VERSION"
    ;;
    "run" )
      # run given version of luvit
      if [ $# -lt 2 ]; then
        luvm help
        return 1
      fi
      VERSION=`luvm_version $2`
      if [ ! -d $LUVM_DIR/$VERSION ]; then
        echo "$VERSION version is not installed yet"
        return 1
      fi
      echo "Running luvit $VERSION"
      $LUVM_DIR/$VERSION/bin/luvit "${@:3}"
    ;;
    "ls" | "list" )
      if [ $# -ne 1 ]; then
        luvm_version $2
        return 0
      fi
      luvm_version all
      echo -ne "current: \t"; luvm_version current
      luvm alias
    ;;
    "alias" )
      mkdir -p $LUVM_DIR/alias
      if [ $# -le 2 ]; then
        (cd $LUVM_DIR/alias && for ALIAS in `\ls $2* 2>/dev/null`; do
            DEST=`cat $ALIAS`
            VERSION=`luvm_version $DEST`
            if [ "$DEST" = "$VERSION" ]; then
                echo "$ALIAS -> $DEST"
            else
                echo "$ALIAS -> $DEST (-> $VERSION)"
            fi
        done)
        return
      fi
      if [ ! "$3" ]; then
          rm -f $LUVM_DIR/alias/$2
          echo "$2 -> *poof*"
          return
      fi
      mkdir -p $LUVM_DIR/alias
      VERSION=`luvm_version $3`
      if [ $? -ne 0 ]; then
        echo "! WARNING: Version '$3' does not exist." >&2
      fi
      echo $3 > "$LUVM_DIR/alias/$2"
      if [ ! "$3" = "$VERSION" ]; then
          echo "$2 -> $3 (-> $VERSION)"
      else
        echo "$2 -> $3"
      fi
    ;;
    "unalias" )
      mkdir -p $LUVM_DIR/alias
      [ $# -ne 2 ] && luvm help && return
      [ ! -f $LUVM_DIR/alias/$2 ] && echo "Alias $2 doesn't exist!" && return
      rm -f $LUVM_DIR/alias/$2
      echo "Deleted alias $2"
    ;;
    "copy-packages" )
        if [ $# -ne 2 ]; then
          luvm help
          return
        fi
        VERSION=`luvm_version $2`
        ROOT=`luvm use $VERSION && npm -g root`
        # TODO
        INSTALLS=`luvm use $VERSION > /dev/null && npm -g -p ll | grep "$ROOT\/[^/]\+$" | cut -d '/' -f 8 | cut -d ":" -f 2 | grep -v npm | tr "\n" " "`
        npm install -g $INSTALLS
    ;;
    "clear-cache" )
        rm -f $LUVM_DIR/v* 2>/dev/null
        echo "Cache cleared."
    ;;
    "version" )
        luvm_version $2
    ;;
    "heart" )
        VERSION=`luvm_version`
        mkdir -p "$LUVM_DIR/src" && \
        cd "$LUVM_DIR/src" && \
        eval $GET "https://github.com/dvv/heart/tarball/master" | tar -xzpf - && \
        cd dvv-heart-* && \
        PREFIX="$LUVM_DIR/$VERSION" make install
        cd ..
        rm -fr dvv-heart-*
    ;;
    * )
      luvm help
    ;;
  esac
}

luvm ls default >/dev/null 2>&1 && luvm use default >/dev/null
