public class AstalHyprland.Monitor : Object {
    public signal void removed();

    public int id { get; private set; }
    public string name { get; private set; }
    public string description { get; private set; }
    public string make { get; private set; }
    public string model { get; private set; }
    public string serial { get; private set; }
    public int width { get; private set; }
    public int height { get; private set; }
    public double refresh_rate { get; private set; }
    public int x { get; private set; }
    public int y { get; private set; }
    public Workspace active_workspace { get; private set; }
    public Workspace special_workspace { get; private set; }
    public int reserved_top { get; private set; }
    public int reserved_bottom { get; private set; }
    public int reserved_left { get; private set; }
    public int reserved_right { get; private set; }
    public double scale { get; private set; }
    public Transform transform { get; private set; }
    public bool focused { get; private set; }
    public bool dpms_status { get; private set; }
    public bool vrr { get; private set; }
    public bool actively_tearing { get; private set; }
    public bool disabled { get; private set; }
    public string current_format { get; private set; }
    public Array<string> available_modes { get; private set; }

    internal void sync(Json.Object obj) {
        var hyprland = Hyprland.get_default();

        id = (int)obj.get_int_member("id");
        name = obj.get_string_member("name");
        description = obj.get_string_member("description");
        make = obj.get_string_member("make");
        model = obj.get_string_member("model");
        serial = obj.get_string_member("serial");
        width = (int)obj.get_int_member("width");
        height = (int)obj.get_int_member("height");
        refresh_rate = obj.get_double_member("refreshRate");
        x = (int)obj.get_int_member("x");
        y = (int)obj.get_int_member("y");
        scale = obj.get_double_member("scale");
        transform = (Transform)obj.get_int_member("transform");
        focused = obj.get_boolean_member("focused");
        dpms_status = obj.get_boolean_member("dpmsStatus");
        vrr = obj.get_boolean_member("vrr");
        actively_tearing = obj.get_boolean_member("activelyTearing");
        disabled = obj.get_boolean_member("disabled");
        current_format = obj.get_string_member("currentFormat");

        var r = obj.get_array_member("reserved");
        reserved_top = (int)r.get_int_element(0);
        reserved_bottom = (int)r.get_int_element(1);
        reserved_left = (int)r.get_int_element(2);
        reserved_right = (int)r.get_int_element(3);

        var modes = new Array<string>();
        foreach (var mode in obj.get_array_member("availableModes").get_elements()) {
            modes.append_val(mode.get_string());
        }

        active_workspace = hyprland.get_workspace((int)obj.get_object_member("activeWorkspace").get_int_member("id"));
        special_workspace = hyprland.get_workspace((int)obj.get_object_member("specialWorkspace").get_int_member("id"));
    }

    public void focus() {
        if(Hyprland.get_default().config_provider == ConfigProvider.LUA) {
            Hyprland.get_default().dispatch("focus", "{monitor=" + id.to_string() + "}");
            return;
        }

        Hyprland.get_default().dispatch("focusmonitor", id.to_string());
    }

    public enum Transform {
        NORMAL = 0,
        /** rotate by 90° counter clockwise */
        ROTATE_90_DEG = 1,
        /** rotate by 180° */
        ROTATE_180_DEG = 2,
        /** rotate by 270° counter clockwise  */
        ROTATE_270_DEG = 3,
        /** mirror both axis  */
        FLIPPED = 4,
        /** flip and rotate by 90° */
        FLIPPED_ROTATE_90_DEG = 5,
        /** flip and rotate by 180° */
        FLIPPED_ROTATE_180_DEG = 6,
        /** flip and rotate by 270° */
        FLIPPED_ROTATE_270_DEG = 7,
    }
}
