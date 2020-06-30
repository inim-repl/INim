#! /bin/bash

# This script borrowed from the Nimble project - Thanks!

export GITBIN=$HOME/.choosenim/git/bin
export PATH=$HOME/.nimble/bin:$GITBIN:$PATH

if ! type -P choosenim &> /dev/null; then
  echo "Fresh install"
  mkdir -p $GITBIN

  export CHOOSENIM_CHOOSE_VERSION="$BRANCH --latest"
  curl https://nim-lang.org/choosenim/init.sh -sSf > init.sh
  sh init.sh -y
  cp $HOME/.nimble/bin/choosenim$EXT $GITBIN/.

else
  echo "Already installed"
  rm -rf $HOME/.choosenim/current
  choosenim update $BRANCH --latest
  choosenim $BRANCH
fi

