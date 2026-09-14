[CCode(cheader_filename = "wayland-client.h", cname = "wl_output_interface")]
private extern Wl.Interface wl_output_interface;

namespace AstalWl {
/**
 * Represents a display output device and tracks properties associated with it.
 *
 * This class listens to Wayland `wl_output` and optional
 * `zxdg_output_v1` events if supported by the compositor
 * to maintain accurate state information.
 */
public class Output : Object {
    /**
     * This enumeration describes how the physical pixels on an output are laid out.
     */
    public enum Subpixel {
        UNKNOWN = 0,
        NONE = 1,
        HORIZONTAL_RGB = 2,
        HORIZONTAL_BGR = 3,
        VERTICAL_RGB = 4,
        VERTICAL_BGR = 5
    }

    /**
     * This describes transformations that clients and compositors apply to buffer contents.
     * The flipped values correspond to an initial flip around a vertical axis followed by rotation.
     */
    public enum Transform {
        NORMAL = 0,
        ROTATE_90 = 1,
        ROTATE_180 = 2,
        ROTATE_270 = 3,
        FLIPPED = 4,
        FLIPPED_90 = 5,
        FLIPPED_180 = 6,
        FLIPPED_270 = 7,
    }

    private Wl.Output output;
    private ZxdgOutputV1? xdg_output;

    public signal void invalidate();

    /**
     * Returns the underlying `wl_output` proxy pointer.
     */
    [GIR(visible = false)]
    public unowned Wl.Output get_wl_output() {
        return this.output;
    }
    /**
     * The unique registry ID of this output as provided by the compositor.
     */
    public uint32 id { get; construct; }
    /**
     * The logical geometry of the output in compositor coordinates.
     * This reflects the visible area after applying scaling and transform.
     */
    public Rectangle? geometry { get; private set; }
    public Rectangle? pending_geometry;
    private Rectangle? output_geometry { get; private set; }
    /**
     * The physical width of the output in millimeters.
     */
    public int physical_width { get; private set; }
    private int? pending_physical_width;
    /**
     * The physical height of the output in millimeters.
     */
    public int physical_height { get; private set; }
    private int? pending_physical_height;
    /**
     * The refresh rate of the current output mode in Hz.
     */
    public double refresh_rate { get; private set; }
    private double? pending_refresh_rate;
    /**
     * The rotation or flip transform of the output surface.
     */
    public Transform transform { get; private set; }
    private Transform? pending_transform;
    /**
     * The subpixel layout of the physical monitor.
     */
    public Subpixel subpixel { get; private set; }
    private Subpixel? pending_subpixel;
    /**
     * The manufacturer name of the display device.
     */
    public string? make { get; private set; }
    private string? pending_make;
    /**
     * The product or model name of the display device.
     */
    public string? model { get; private set; }
    private string? pending_model;
    /**
     * The scaling factor of the output.
     */
    public double scale { get; private set; }
    private double? pending_scale;
    /**
     * The compositor-assigned name of this output.
     * Usually corresponds to an identifier like "HDMI-A-1".
     */
    public string? name { get; private set; }
    private string? pending_name;
    /**
     * A description of the output.
     */
    public string? description { get; private set; }
    private string? pending_description;

    /**
     * emitted whenever there were changes on any property
     */
    public signal void changed();

    private void handle_geometry (Wl.Output wl_output, int32 x, int32 y, int32 physical_width, int32 physical_height, int32 subpixel, string make, string model, int32 transform) {
        this.output_geometry.x = x;
        this.output_geometry.y = y;
        this.pending_subpixel = subpixel;
        this.pending_make = make;
        this.pending_model = model;
        this.pending_transform = transform;
        switch (this.pending_transform) {
            case ROTATE_90:
            case ROTATE_270:
            case FLIPPED_90:
            case FLIPPED_270:
                this.pending_physical_width = physical_height;
                this.pending_physical_height = physical_width;
                break;
            default:
                this.pending_physical_width = physical_width;
                this.pending_physical_height = physical_height;
                break;
        }
    }

    private void handle_mode (Wl.Output wl_output, uint32 flags, int32 width, int32 height, int32 refresh) {
        if ((flags & 1) == 0) return;
        Transform transform = this.pending_transform != null ? this.pending_transform : this.transform;
        switch (transform) {
            case ROTATE_90:
            case ROTATE_270:
            case FLIPPED_90:
            case FLIPPED_270:
                this.output_geometry.height = width;
                this.output_geometry.width = height;
                break;
            default:
                this.output_geometry.height = height;
                this.output_geometry.width = width;
                break;
        }
        this.pending_refresh_rate = refresh / 1000;
    }

    private void handle_done (Wl.Output wl_output) {
        this.freeze_notify();
        if(this.pending_name != null) {
            this.name = this.pending_name;
            this.pending_name = null;
        }
        if(this.pending_description != null) {
            this.description = this.pending_description;
            this.pending_description = null;
        }
        if(this.pending_make != null) {
            this.make = this.pending_make;
            this.pending_make = null;
        }
        if(this.pending_model != null) {
            this.model = this.pending_model;
            this.pending_model = null;
        }
        if(this.pending_scale != null) {
            this.scale = this.pending_scale;
            this.pending_scale = null;
        }
        if(this.pending_refresh_rate != null) {
            this.refresh_rate = this.pending_refresh_rate;
            this.pending_refresh_rate = null;
        }
        if(this.pending_geometry != null) {
            this.geometry = this.pending_geometry.copy();
            this.pending_geometry = null;
        }
        if(this.pending_subpixel != null) {
            this.subpixel = this.pending_subpixel;
            this.pending_subpixel = null;
        }
        if(this.pending_transform != null) {
            this.transform = this.pending_transform;
            this.pending_transform = null;
        }
        if(this.pending_physical_width != null) {
            this.physical_width = this.pending_physical_width;
            this.pending_physical_width = null;
        }
        if(this.pending_physical_height != null) {
            this.physical_height = this.pending_physical_height;
            this.pending_physical_height = null;
        }
        
        if (this.xdg_output == null) {
            this.geometry.x = (int)(this.output_geometry.x / this.scale);
            this.geometry.y = (int)(this.output_geometry.y / this.scale);
            switch (this.transform) {
                case ROTATE_90:
                case ROTATE_270:
                case FLIPPED_90:
                case FLIPPED_270:
                    this.geometry.width = (int)(this.output_geometry.height / this.scale);
                    this.geometry.height = (int)(this.output_geometry.width / this.scale);
                    break;
                default:
                    this.geometry.width = (int)(this.output_geometry.width / this.scale);
                    this.geometry.height = (int)(this.output_geometry.height / this.scale);
                    break;
            }
        } else {
            this.scale = double.max(this.output_geometry.width / (double)this.geometry.width,
                    this.output_geometry.height / (double)this.geometry.height);
        }
        this.notify_property("geometry");

        this.thaw_notify();
        changed();
    }

    private void handle_scale (Wl.Output wl_output, int32 factor) {
        this.pending_scale = factor;
    }

    private void handle_name(Wl.Output wl_output, string name) {
        this.pending_name = name;
    }

    private void handle_description (Wl.Output wl_output, string description) {
        this.pending_description = description;
    }

    private void handle_xdg_logical_position(ZxdgOutputV1 zxdg_output_v1, int32 x, int32 y) {
        if(this.pending_geometry == null) this.pending_geometry = Rectangle();
        this.pending_geometry.x = x;
        this.pending_geometry.y = y;
    }

    private void handle_xdg_logical_size(ZxdgOutputV1 zxdg_output_v1, int32 width, int32 height) {
        if(this.pending_geometry == null) this.pending_geometry = Rectangle();
        this.pending_geometry.width = width;
        this.pending_geometry.height = height;
    }

    /**
     * deprecated, the compositor will send wl_output.done instead.
     */
    private void handle_xdg_done(ZxdgOutputV1 zxdg_output_v1) {}

    /**
     * deprecated, use wl_output.name instead.
     */
    private void handle_xdg_name(ZxdgOutputV1 zxdg_output_v1, string name) {}

    /**
     * deprecated, use wl_output.description instead.
     */
    private void handle_xdg_description(ZxdgOutputV1 zxdg_output_v1, string description) {}

    private const ZxdgOutputV1Listener xdg_output_listener = {
        handle_xdg_logical_position,
        handle_xdg_logical_size,
        handle_xdg_done,
        handle_xdg_name,
        handle_xdg_description
    };

    private const Wl.OutputListener output_listener = {
        handle_geometry,
        handle_mode,
        handle_done,
        handle_scale,
        handle_name,
        handle_description
    };

    internal void init_xdg(ZxdgOutputManagerV1 output_manager, Wl.Display display) {
        this.xdg_output = output_manager.get_xdg_output(this.output);
        this.xdg_output.add_listener(xdg_output_listener, this);
    }

    internal Output(Global global, Wl.Registry registry, Wl.Display display, ZxdgOutputManagerV1 output_manager) {
        Object(id: global.name);
        this.geometry = Rectangle();
        this.pending_geometry = Rectangle();
        this.output_geometry = Rectangle();
        this.output = registry.bind<Wl.Output>(global.name, ref wl_output_interface, uint.min(global.version, 4));
        this.output.add_listener(output_listener, this);
        if (output_manager != null) init_xdg(output_manager, display);
    }
}
}
