import { defineConfig } from "vitepress"

function github(url = "") {
    return `https://github.com/aylur/astal${url}`
}

export default defineConfig({
    title: "Astal",
    description: "Documentation website of the Astal project",

    outDir: "./dist",
    base: "/astal/",
    cleanUrls: true,

    lastUpdated: true,

    head: [
        ["link", { rel: "icon", href: "/astal/icon.svg" }],
    ],

    themeConfig: {
        logo: "/icon.svg",
        outline: "deep",

        footer: {
            message: 'Released under the LGPL v2.1 License',
            copyright: 'Logo is created by VDawg'
        },

        nav: [
            {
                text: "Showcases",
                link: "/showcases",
                activeMatch: "/showcases/",
            },
            {
                text: "Guide",
                link: "/guide/getting-started/installation",
                activeMatch: "/guide/",
            },
            {
                text: "0.1.0",
                items: [
                    { text: "Contributing", link: github("/blob/main/CONTRIBUTING.md") },
                    { text: "Changelog", link: github("/blob/main/CHANGELOG.md") },
                ],
            }
        ],

        sidebar: [
            {
                text: "Getting Started",
                base: "/guide/getting-started",
                collapsed: false,
                items: [
                    { text: "Introduction", link: "/introduction" },
                    { text: "Installation", link: "/installation" },
                    { text: "Supported Languages", link: "/supported-languages" },
                ],
            },
            {
                text: "AGS",
                base: "/guide/ags",
                collapsed: false,
                items: [
                    { text: "Installation", link: "/installation" },
                    { text: "First Widgets", link: "/first-widgets" },
                    { text: "Theming", link: "/theming" },
                    { text: "CLI and App", link: "/cli-app" },
                    { text: "Widget", link: "/widget" },
                    { text: "Variable", link: "/variable" },
                    { text: "Binding", link: "/binding" },
                    { text: "GObject", link: "/gobject" },
                    { text: "Utilities", link: "/utilities" },
                    { text: "FAQ", link: "/faq" },
                ],
            },
            {
                text: "Libraries",
                collapsed: true,
                items: [
                    { text: "References", link: "/guide/libraries/references" },
                    { text: "Astal", link: "https://aylur.github.io/libastal" },
                    { text: "Apps", link: "/guide/libraries/apps" },
                    { text: "Auth", link: "/guide/libraries/auth" },
                    { text: "Battery", link: "/guide/libraries/battery" },
                    { text: "Bluetooth", link: "/guide/libraries/bluetooth" },
                    { text: "Cava", link: "/guide/libraries/cava" },
                    { text: "Hyprland", link: "/guide/libraries/hyprland" },
                    { text: "Mpris", link: "/guide/libraries/mpris" },
                    { text: "Network", link: "/guide/libraries/network" },
                    { text: "Notifd", link: "/guide/libraries/notifd" },
                    { text: "PowerProfiles", link: "/guide/libraries/powerprofiles" },
                    { text: "River", link: "/guide/libraries/river" },
                    { text: "Tray", link: "/guide/libraries/tray" },
                    { text: "WirePlumber", link: "/guide/libraries/wireplumber" },
                ],
            },
        ],

        socialLinks: [
            { icon: "github", link: github() },
            { icon: "discord", link: "https://discord.gg/CXQpHwDuhY" },
        ],

        editLink: {
            pattern: github("/edit/main/docs/:path"),
            text: "Edit this page on GitHub",
        },

        lastUpdated: {
            text: "Last updated",
        },

        search: {
            provider: "local",
        }
    },
})
