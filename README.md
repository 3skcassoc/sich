## Server

To run Sich you need to install Lua 5.1 and LuaSocket library:

* **Debian**: `apt-get install lua5.1 lua-socket`

* **Windows**: download and install [LuaForWindows](https://github.com/rjpcomputing/luaforwindows/releases/latest)

Next, download [sich.lua](../../raw/master/release/sich.lua).
If you want to change default options (host, port, etc.) download and edit [config.store](../../raw/master/release/config.store).

To start:

* **Debian**: `lua sich.lua`

* **Windows**: double click on file `sich.lua`

## Client

* Open `<Cossacks 3>/data/resources/servers.dat` in text editor.

* Remove or comment out official servers, add new one.

* Restart game.

## Tools

* [C3 Servers](../../raw/master/tools/c3servers.wlua)

* [Protocol Dissector for Wireshark](../../raw/master/tools/cossacks3dissector.lua)

## License

* [WTFPL](../../raw/master/LICENSE)
