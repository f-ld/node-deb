# CHANGELOG

#### 0.1.12 - 2016-04-05
  - Support for the creation of a .changes files together with the .deb package (to use with mini-dinstall debian package repository)
  - Updated doc after first publish

#### 0.1.11 - 2016-04-05
- Forked from https://github.com/heartsucker/node-deb
- Added
  - Support for custom install path using the --path option
  - Support for basic System V init script (see --init sysv) + custom stop command (used only for system v)

#### 0.1.10 - 2016-03-09
- Changed
  - `postinst` now runs `npm install` with the `--production` option

#### 0.1.9 - 2016-03-08
- **BREAKING**
  - `node-deb` will no longer include the `node_modules` directory, but instead will run `npm install` during the
  `postinst` step in the install directory. Thus, if `package.json` exists, it will be auto included in the `.deb`.
- Added
  - Better script logging
  - `package.json` and `npm-shrinkwrap.json` are included by default, and warning messages are displayed if they aren't
  included
  - If `node_deb.start_command` is not present in `package.json`, default to using `scripts.start`
