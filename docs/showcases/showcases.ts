type Showcase = {
    label: string
    src: string
    url: string
    icon: string // https://devicon.dev/
}

type Grid<T> = T | [T, T] | [T, T, T] | [T, T, T, T]

export default [
    {
        label: "Placeholder (this is an ags v1 screenshot)",
        src: "/astal/showcase/aylur.png",
        url: "https://github.com/Aylur/dotfiles",
        icon: "devicon-javascript-plain",
    },
    {
        label: "Idk I just love oxocarbon",
        src: "/astal/showcase/contrib1.webp",
        url: "https://github.com/tokyob0t/dotfiles",
        icon: "devicon-lua-plain",
    },
    // add mowe shuwucases hewe~
] satisfies Array<Grid<Showcase>>
