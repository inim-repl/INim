#! /bin/bash

# This script borrowed from the Nimble project - Thanks!
export BRANCH=devel
export PATH=$HOME/.nimble/bin:$GITBIN:$PATH
echo $HOME
if ! type -P choosenim &> /dev/null; then
  echo "Fresh install"

  export CHOOSENIM_CHOOSE_VERSION="$BRANCH --latest"
  curl https://nim-lang.org/choosenim/init.sh -sSf > init.sh
  sh init.sh -y

else
  echo "Already installed"
  rm -rf $HOME/.choosenim/current
  choosenim update $BRANCH --latest
  choosenim $BRANCH
  nim -v
fi

