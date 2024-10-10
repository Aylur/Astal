# Cava

Audio visualizer using [cava](https://github.com/karlstav/cava).

## Installation

1. install dependencies

Note that it requires [libcava](https://github.com/LukashonakV/cava), a fork of cava, which provides cava as a shared library.

:::code-group

```sh [<i class="devicon-archlinux-plain"></i> Arch]
sudo pacman -Syu meson vala gobject-introspection
paru -S libcava
```

```sh [<i class="devicon-fedora-plain"></i> Fedora]
# Not yet documented
```

```sh [<i class="devicon-ubuntu-plain"></i> Ubuntu]
# Not yet documented
```

:::

2. clone repo

```sh
git clone https://github.com/aylur/astal.git
cd astal/lib/cava
```

3. install

```sh
meson setup build
meson install -C build
```

:::tip
Most distros recommend manual installs in `/usr/local`,
which is what `meson` defaults to. If you want to install to `/usr`
instead which most package managers do, set the `prefix` option:

```sh
meson setup --prefix /usr build
```

:::

## Usage

You can browse the [Cava reference](https://aylur.github.io/libastal/cava).

### CLI

There is no CLI for this library, use the one provided by cava.

```sh
cava
```

### Library

:::code-group

```js [<i class="devicon-javascript-plain"></i> JavaScript]
import Wp from "gi://AstalCava"

const cava = Cava.get_default()

cava.connect("notify::values", () => {
    print(cava.get_values())
})
```

```py [<i class="devicon-python-plain"></i> Python]
# Not yet documented
```

```lua [<i class="devicon-lua-plain"></i> Lua]
-- Not yet documented
```

```vala [<i class="devicon-vala-plain"></i> Vala]
// Not yet documented
```

:::
