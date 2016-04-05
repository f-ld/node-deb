# node-deb

For of node-dev by heartsucker (https://github.com/heartsucker/node-deb) to get some new features quickly.
This wont be maintained and will be proposed for merge into the main project.
Debian packaging for Node.js projects written 100% in `bash`.

Simple.

## Installation
`npm install node-deb-pkg`

## Compatibility

This exists mostly as an internal tool for my company, so until there is an `0.2.0` release, there will not be any sort
of assurances of compatibility between releases. This includes command line flags, executables, and init scripts.

## Usage

`node-deb [opts] -- file1 file2 ...`

For the full list of options, run `node-deb -h`.

## Configuration
You do not need to add anything to `package.json` as it uses sane defaults. However, if you don't like these, there are
two options for overrides: command line options, or the JSON object `node_deb` at the top level of your `package.json`.

For example, here are some sample `node_deb` overrides. The full list can be found by running
`node-deb --list-json-overrides`.

```json
{
  "name": "some-app",
  ...
  "node_deb": {
    "init": "systemd",
    "version": "1.2.3-beta",
    "start_command": "/usr/bin/node foo.js"
  }
}
```

Command line options always override values found in the `node_deb` object, and values found in the `node_deb` object
always override the values found in the rest of `package.json`.

Examples can be found by looking at `test.sh` and the corresponding projects in the `test` directory.

## Examples
#### Ex. 1
`package.json`:

```json
{
  "name": "some-app",
  "version": "1.2.3",
  "scripts": {
    "start": "/usr/bin/node app.js arg1 arg2 arg3"
  }
}
```

`cmd`: `node-deb -- app.js lib/ package.json`

You will get:
- A Debian package named `some-app_1.2.3_all.deb`
  - Containing the files `app.js` & `package.json` and the directory `lib`
  - Installed via
    - `apt-get install some-app`
    - `apt-get install some-app=1.2.3`

On install, you will get.
- An executable named `some-app`
  - That starts the app with the command `/usr/bin/node app.js arg1 arg2 arg3`
- An `upstart` init script installed to `/etc/init/some-app.conf`
- A `systemd` unit file installed to `/etc/systemd/system/some-app.service`
- A Unix user `some-app`
- A Unix group `some-app`

#### Ex. 2
`package.json`:

```json
{
  "name": "some-other-app",
  "version": "5.0.2",
  "scripts": {
    "start": "/usr/bin/node --harmony index.js"
  }
}
```

`cmd`: `node-deb -u foo -g bar -v 20150826 -- index.js lib/ package.json`

You will get:
- A Debian package named `some-other-app_20150826_all.deb`
  - Containing the files `index.js` & `package.json` and the directory `lib`
  - Installed via
    - `apt-get install some-other-app`
    - `apt-get install some-other-app=20150826`

On install, you will get.
- An executable named `some-other-app`
  - That starts the app with the command `/usr/bin/node --harmony index.js`
- An `upstart` init script installed to `/etc/init/some-other-app.conf`
- A `systemd` unit file installed to `/etc/systemd/system/some-other-app.service`
- A Unix user `foo`
- A Unix group `bar`

#### &c.
`node-deb` can Debian-package itself. Just run `./node-deb -- node-deb templates/ package.json`.

More complete examples can be found by looking at `test.sh` and the corresponding projects in the `test` directory.

## Requirements
- `dpkg`
- `jq`

These are both available through `apt` and `brew`.

## Contributing
Please make all pull requests to the `develop` branch.
