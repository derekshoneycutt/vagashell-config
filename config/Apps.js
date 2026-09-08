.pragma library

var pinned = [
    { name: "Google Chrome", desktopId: "com.google.Chrome", aliases: ["google-chrome", "Google-chrome"] },
    { name: "Ghostty", desktopId: "com.mitchellh.ghostty", aliases: ["com.mitchellh.ghostty"] },
    { name: "Files", desktopId: "org.gnome.Nautilus", aliases: ["org.gnome.Nautilus", "nautilus"] },
    { name: "Visual Studio Code", desktopId: "code", aliases: ["code", "Code"] },
    { name: "Neovim", desktopId: "", icon: "nvim", command: ["ghostty", "--class=nvim", "--gtk-single-instance=false", "-e", "nvim"], aliases: ["nvim"] },
    { name: "Text Editor", desktopId: "org.gnome.TextEditor", aliases: ["org.gnome.TextEditor"] },
    { name: "Qalculate", desktopId: "qalculate-gtk", aliases: ["qalculate-gtk"] },
    { name: "Zotero", desktopId: "zotero", aliases: ["Zotero", "zotero"] },
    { name: "Steam", desktopId: "steam", aliases: ["steam"] },
    {
        name: "Audiobookshelf",
        desktopId: "",
        icon: "chrome-neejcaapkjghlgnkkgnfchhncfdjelgk-Default",
        command: ["/opt/google/chrome/google-chrome", "--profile-directory=Default", "--app-id=neejcaapkjghlgnkkgnfchhncfdjelgk"],
        aliases: ["crx_neejcaapkjghlgnkkgnfchhncfdjelgk"]
    },
    { name: "Spotify", desktopId: "spotify", aliases: ["spotify"] },
    { name: "VirtualBox", desktopId: "virtualbox", aliases: ["VirtualBox Manager", "VirtualBox"] },
    { name: "System Monitor", desktopId: "org.gnome.SystemMonitor", aliases: ["gnome-system-monitor", "org.gnome.SystemMonitor"] }
]
