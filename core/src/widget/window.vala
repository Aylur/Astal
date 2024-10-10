using GtkLayerShell;

namespace Astal {
[Flags]
public enum WindowAnchor {
    NONE = 0,
    TOP = 1,
    RIGHT = 2,
    LEFT = 4,
    BOTTOM = 8,
}

public enum Exclusivity {
    NORMAL,
    EXCLUSIVE,
    IGNORE,
}

public enum Layer {
    BACKGROUND = 0, // GtkLayerShell.Layer.BACKGROUND
    BOTTOM = 1, // GtkLayerShell.Layer.BOTTOM
    TOP = 2, // GtkLayerShell.Layer.TOP
    OVERLAY = 3, // GtkLayerShell.Layer.OVERLAY
}

public enum Keymode {
    NONE = 0, // GtkLayerShell.KeyboardMode.NONE
    ON_DEMAND = 1, // GtkLayerShell.KeyboardMode.ON_DEMAND
    EXCLUSIVE = 2, // GtkLayerShell.KeyboardMode.EXCLUSIVE
}

public class Window : Gtk.Window {
    private static bool check(string action) {
        if (!is_supported()) {
            critical(@"can not $action on window: layer shell not supported");
            print("tip: running from an xwayland terminal can cause this, for example VsCode");
            return true;
        }
        return false;
    }

    private InhibitManager? inhibit_manager;
    private Inhibitor? inhibitor;

    construct {
        if (check("initialize layer shell"))
            return;

        height_request = 1;
        width_request = 1;
        init_for_window(this);
        inhibit_manager = InhibitManager.get_default();
    }

    public bool inhibit {
        set {
            if (inhibit_manager == null) {
                return;
            }
            if (value && inhibitor == null) {
                inhibitor = inhibit_manager.inhibit(this);
            }
            else if (!value && inhibitor != null) {
                inhibitor = null;
            }
        }
        get {
            return inhibitor != null;
        }
    }

    public override void show() {
        base.show();
        if(inhibit) {
            inhibitor = inhibit_manager.inhibit(this);
        }
    }

    public string namespace {
        get { return get_namespace(this); }
        set { set_namespace(this, value); }
    }

    public int anchor {
        set {
            if (check("set anchor"))
                return;

            set_anchor(this, Edge.TOP, WindowAnchor.TOP in value);
            set_anchor(this, Edge.BOTTOM, WindowAnchor.BOTTOM in value);
            set_anchor(this, Edge.LEFT, WindowAnchor.LEFT in value);
            set_anchor(this, Edge.RIGHT, WindowAnchor.RIGHT in value);
        }
        get {
            var a = WindowAnchor.NONE;
            if (get_anchor(this, Edge.TOP))
                a = a | WindowAnchor.TOP;

            if (get_anchor(this, Edge.RIGHT))
                a = a | WindowAnchor.RIGHT;

            if (get_anchor(this, Edge.LEFT))
                a = a | WindowAnchor.LEFT;

            if (get_anchor(this, Edge.BOTTOM))
                a = a | WindowAnchor.BOTTOM;

            return a;
        }
    }

    public Exclusivity exclusivity {
        set {
            if (check("set exclusivity"))
                return;

            switch (value) {
                case Exclusivity.NORMAL:
                    set_exclusive_zone(this, 0);
                    break;
                case Exclusivity.EXCLUSIVE:
                    auto_exclusive_zone_enable(this);
                    break;
                case Exclusivity.IGNORE:
                    set_exclusive_zone(this, -1);
                    break;
            }
        }
        get {
            if (auto_exclusive_zone_is_enabled(this))
                return Exclusivity.EXCLUSIVE;

            if (get_exclusive_zone(this) == -1)
                return Exclusivity.IGNORE;

            return Exclusivity.NORMAL;
        }
    }

    public Layer layer {
        get { return (Layer)get_layer(this); }
        set {
            if (check("set layer"))
                return;

            set_layer(this, (GtkLayerShell.Layer)value);
        }
    }

    public Keymode keymode {
        get { return (Keymode)get_keyboard_mode(this); }
        set {
            if (check("set keymode"))
                return;

            set_keyboard_mode(this, (GtkLayerShell.KeyboardMode)value);
        }
    }

    public Gdk.Monitor gdkmonitor {
        get { return get_monitor(this); }
        set {
            if (check("set gdkmonitor"))
                return;

            set_monitor (this, value);
        }
    }

    public new int margin_top {
        get { return GtkLayerShell.get_margin(this, Edge.TOP); }
        set {
            if (check("set margin_top"))
                return;

            GtkLayerShell.set_margin(this, Edge.TOP, value);
        }
    }

    public new int margin_bottom {
        get { return GtkLayerShell.get_margin(this, Edge.BOTTOM); }
        set {
            if (check("set margin_bottom"))
                return;

            GtkLayerShell.set_margin(this, Edge.BOTTOM, value);
        }
    }

    public new int margin_left {
        get { return GtkLayerShell.get_margin(this, Edge.LEFT); }
        set {
            if (check("set margin_left"))
                return;

            GtkLayerShell.set_margin(this, Edge.LEFT, value);
        }
    }

    public new int margin_right {
        get { return GtkLayerShell.get_margin(this, Edge.RIGHT); }
        set {
            if (check("set margin_right"))
                return;

            GtkLayerShell.set_margin(this, Edge.RIGHT, value);
        }
    }

    public new int margin {
        set {
            if (check("set margin"))
                return;

            margin_top = value;
            margin_right = value;
            margin_bottom = value;
            margin_left = value;
        }
    }

    /**
     * CAUTION: the id might not be the same mapped by the compositor
     * to reset and let the compositor map it pass a negative number
     */
    public int monitor {
        set {
            if (check("set monitor"))
                return;

            if (value < 0)
                set_monitor(this, (Gdk.Monitor)null);

            var m = Gdk.Display.get_default().get_monitor(value);
            set_monitor(this, m);
        }
        get {
            var m = get_monitor(this);
            var d = Gdk.Display.get_default();
            for (var i = 0; i < d.get_n_monitors(); ++i) {
                if (m == d.get_monitor(i))
                    return i;
            }

            return -1;
        }
    }
}

/**
 * CAUTION: the id might not be the same mapped by the compositor
 */
public uint get_num_monitors() {
    return Gdk.Display.get_default().get_n_monitors();
}
}
