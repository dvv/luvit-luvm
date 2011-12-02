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
  GET='curl --progress-bar'
else
  GET='wget -q --progress=bar -O -'
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
    return
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
      echo "    luvm copy-packages <version> Install global NPM packages contained in <version> to current version"
      echo
      echo "Example:"
      echo "    luvm install 0.0.1           Install a specific version number"
      echo "    luvm use 0.0.2               Use the latest available 0.2.x release"
      echo "    luvm run 0.4.12 myApp.js     Run myApp.js using luvit v0.4.12"
      echo "    luvm alias default 0.4       Auto use the latest installed v0.4.x version"
      echo
    ;;
    "install" )
      if [ $# -ne 2 ]; then
        luvm help
        return
      fi
      VERSION=`luvm_version $2`

      [ -d "$LUVM_DIR/$VERSION" ] && echo "$VERSION is already installed." && return

      if (
        mkdir -p "$LUVM_DIR/src" && \
        cd "$LUVM_DIR/src" && \
        $GET "http://creationix.com/dist/$VERSION/luvit-$VERSION.tar.gz" | tar -xzpf - && \
        cd "luvit-$VERSION" && \
        PREFIX="$LUVM_DIR/$VERSION" make && \
        rm -fr "$LUVM_DIR/$VERSION" 2>/dev/null && \
        mkdir "$LUVM_DIR/$VERSION" && \
        PREFIX="$LUVM_DIR/$VERSION" make install
        )
      then
        luvm use $VERSION
        # TODO: a simple npm surrogate
        #if ! which npm ; then
        #  echo "Installing npm..."
        #  if [[ "`expr match $VERSION '\(^0\.1\.\)'`" != '' ]]; then
        #    echo "npm requires node v0.2.3 or higher"
        #  elif [[ "`expr match $VERSION '\(^0\.2\.\)'`" != '' ]]; then
        #    if [[ "`expr match $VERSION '\(^0\.2\.[0-2]$\)'`" != '' ]]; then
        #      echo "npm requires node v0.2.3 or higher"
        #    else
        #      $GET http://npmjs.org/install.sh | clean=yes npm_install=0.2.19 sh
        #    fi
        #  else
        #    $GET http://npmjs.org/install.sh | clean=yes sh
        #  fi
        #fi
      else
        echo "luvm: install $VERSION failed!"
      fi
    ;;
    "uninstall" )
      [ $# -ne 2 ] && luvm help && return
      if [[ $2 == `luvm_version` ]]; then
        echo "luvm: Cannot uninstall currently-active luvit version, $2."
        return
      fi
      VERSION=`luvm_version $2`
      if [ ! -d $LUVM_DIR/$VERSION ]; then
        echo "$VERSION version is not installed yet"
        return;
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
      if [[ $MANPATH == *$LUVM_DIR/*/share/man* ]]; then
        export MANPATH=${MANPATH%$LUVM_DIR/*/share/man*}${MANPATH#*$LUVM_DIR/*/share/man:}
        echo "$LUVM_DIR/*/share/man removed from \$MANPATH"
      else
        echo "Could not find $LUVM_DIR/*/share/man in \$MANPATH"
      fi
    ;;
    "use" )
      if [ $# -ne 2 ]; then
        luvm help
        return
      fi
      VERSION=`luvm_version $2`
      if [ ! -d $LUVM_DIR/$VERSION ]; then
        echo "$VERSION version is not installed yet"
        return;
      fi
      if [[ $PATH == *$LUVM_DIR/*/bin* ]]; then
        PATH=${PATH%$LUVM_DIR/*/bin*}$LUVM_DIR/$VERSION/bin${PATH#*$LUVM_DIR/*/bin}
      else
        PATH="$LUVM_DIR/$VERSION/bin:$PATH"
      fi
      if [[ $MANPATH == *$LUVM_DIR/*/share/man* ]]; then
        MANPATH=${MANPATH%$LUVM_DIR/*/share/man*}$LUVM_DIR/$VERSION/share/man${MANPATH#*$LUVM_DIR/*/share/man}
      else
        MANPATH="$LUVM_DIR/$VERSION/share/man:$MANPATH"
      fi
      export PATH
      hash -r
      export MANPATH
      export LUVM_PATH="$LUVM_DIR/$VERSION/lib/luvit"
      export LUVM_BIN="$LUVM_DIR/$VERSION/bin"
      echo "Now using luvit $VERSION"
    ;;
    "run" )
      # run given version of luvit
      if [ $# -lt 2 ]; then
        luvm help
        return
      fi
      VERSION=`luvm_version $2`
      if [ ! -d $LUVM_DIR/$VERSION ]; then
        echo "$VERSION version is not installed yet"
        return;
      fi
      echo "Running luvit $VERSION"
      $LUVM_DIR/$VERSION/bin/luvit "${@:3}"
    ;;
    "ls" | "list" )
      if [ $# -ne 1 ]; then
        luvm_version $2
        return
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
    * )
      luvm help
    ;;
  esac
}

luvm ls default >/dev/null 2>&1 && luvm use default >/dev/null
