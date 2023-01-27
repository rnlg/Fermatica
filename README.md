# Fermatica

*Mathematica* interface to Robert H. Lewis' Fermat CAS.

### Installation

To use ***Fermatica***, you should first install Fermat itself, see
 instructions on http://home.bway.net/lewis/zip.html. You should
 secure that Fermat starts from the terminal.

You might want to define environment variable `FERMATPATH=/path/to/fer64` , where `/path/to/fer64` is the exact path to `fer64` executable. 

1. Copy the content of the 'Source/' directory to the desired location, say `home/of/Fermatica`
2. Change to this location with `cd home/of/Fermatica`
3. Run `math -script makeShortcut.m`

Result: 
You can load Fermatica package from *Mathematica* session with ``<<Fermatica` ``

If the environment variable `FERMATPATH` is defined, ***Fermatica*** will automatically set  `$FermatCMD` to value of this variable. Otherwise, you will have to use `$FermatCMD="/path/to/fer64"` in *Mathematica* session immediately after loading the package with `` <<Fermatica` ``.

### Usage

Although ***Fermatica*** can be used on its own (e.g., many matrix functions are implemented, like `FDet, FDot, FInverse, ...`), its main usage for now is via the option `UseFermat->True` in several procedures of ***LiteRed2*** and ***Libra*** packages.