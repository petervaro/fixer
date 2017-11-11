<img src="img/logo.png?raw=true"
     alt="fixer"
     width="256"
     height="256"/>

fixer
=====

Command line currency converter implemented in D, based on the daily updated
rates available from http://fixer.io.  For more information please visit
the repository of the project at https://gitlab.com/petervaro/fixer.

Usage
-----

```bash
$ fixer 1 gbp eur
1.13
$ fixer 1 usd in eur
0.86
$ fixer 1 eur to huf
312.00
```

For more info:

```bash
$ fixer --help
```

Install
-------

The required toools to install:

- `DUB` - https://code.dlang.org/download
- `ldc` - https://github.com/ldc-developers/ldc#installation

```bash
# Compile and install executable to /usr/local/bin
$ bash install.sh
```

License
-------

Copyright (C) 2017 [Peter Varo](www.petervaro.com)

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANYWARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program, most likely a file in the root directory, called 'LICENSE'. If
not, see http://www.gnu.org/licenses.
