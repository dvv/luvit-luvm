# Luvit Version Manager

## Installation

First you'll need to make sure your system has build-essentials installed.

To install create a folder somewhere in your filesystem with the "`luvm.sh`" file inside it. I put mine in a folder called "`~/.luvm`".

Or if you have `git` installed, then just clone it:

    git clone git://github.com/luvit/luvm.git ~/.luvm

To activate luvm, you need to source it from your _bash_ shell

    . ~/.luvm/luvm.sh

We recommend to add this line to your ~/.bashrc or ~/.profile file to have it automatically sources upon login.
It's convenient to put in a line to use a specific version of luvit.

    luvm use 0.1.4

## Usage

To download, compile, and install the version 0.1.1 of luvit, do this:

    luvm install 0.1.4

And then in any new shell just use the installed version:

    luvm use 0.1.4

Or you can just run it:

    luvm run 0.1.4

If you want to see what versions are available:

    luvm ls

To restore your $PATH, you can deactivate it.

    luvm deactivate

To set a default Luvit version to be used in any new shell, use the alias 'default':

    luvm alias default 0.1.4

## Problems

Feel free to bug [here](https://github.com/luvit/luvm/issues)

## License

Same as for [nvm](https://github.com/creationix/nvm)
