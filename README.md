# INim: Interactive Nim Shell [![nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://github.com/yglukhov/nimble-tag) ![Nim CI](https://github.com/inim-repl/INim/workflows/Nim%20CI/badge.svg)

`$ nimble install inim`

![alt text](https://github.com/AndreiRegiani/INim/blob/master/readme.gif?raw=true)

## Features
* Runs on Linux, macOS and Windows
* Auto-indent (`if`, `for`, `proc`, `var`, ...)
* Arrow keys support (command history and line navigation)
* Prints out value and type of discarded expressions: ```>>> x```
* Uses current `nim` compiler in PATH
* Runs in the current directory: `import` your local modules (access to exported* symbols)
* Preload existing source code (access to non-exported* symbols): `inim -s example.nim`
* Optional Colorized output
* Edit lines using $EDITOR (Ctrl-X)
* Built in tools like ipython (cd(), ls(), pwd(), call()) enabled with --withTools
* When piped a file or some code, INim will execute that code and exit

## Config
Config is saved and loaded from `configDir / inim`.
* On Windows, this is %APPDATA%\inim
* On Linux, this is /home/<user>/.config/inim

Currently, the config allows you to set two options:
* Style
  * `prompt`: Set prompt string (default: "inim> ")
  * `showTypes`: Show var types when printing without echo (default: true)
  * `showColor`: Output results with pretty colors
* History
  * persistent history (default: true)
* Features
  * `withTools`: Enable built in tools

## Contributing
Pull requests and suggestions are welcome.
