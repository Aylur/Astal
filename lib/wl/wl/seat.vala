[CCode(cheader_filename = "wayland-client.h", cname = "wl_seat_interface")]
private extern Wl.Interface wl_seat_interface;

namespace AstalWl {
/**
 * Wraps the Wayland `wl_seat` interface.
 *
 * A seat represents a user input device group containing one or more
 * keyboards, pointer devices, or touchscreens. It tracks the seats
 * capabilities and compositor-assigned name.
 */
public class Seat : Object {
    /**
     * Bitfield flags describing the input capabilities of this seat.
     */
    [Flags]
    public enum Capabilities {
        POINTER = 1,
        KEYBOARD = 2,
        TOUCH = 4
    }

    private Wl.Seat seat;

    /**
     * Returns the underlying `wl_seat` object.
     */
    [GIR(visible = false)]
    public unowned Wl.Seat get_wl_seat() {
        return this.seat;
    }
    
    /**
     * The unique registry id of this seat.
     */
    public uint32 id { get; construct; }

    /**
     * The compositor-assigned name for this seat.
     */
    public string? name { get; private set; }

    /**
     * The current input capabilities of this seat.
     */
    public Capabilities capabilities { get; private set; }

    private void handle_capabilities (Wl.Seat wl_seat, uint32 capabilities) {
        this.capabilities = capabilities;
    }
    private void handle_name (Wl.Seat wl_seat, string name) {
        this.name = name;
    }

    private const Wl.SeatListener seat_listener = {
        handle_capabilities,
        handle_name,
    };

    internal Seat(Global global, Wl.Registry registry, Wl.Display display) {
        Object(id: global.name);
        this.seat = registry.bind<Wl.Seat>(global.name, ref wl_seat_interface, uint.min(global.version, 10));
        this.seat.add_listener(seat_listener, this);
    }
}
}
