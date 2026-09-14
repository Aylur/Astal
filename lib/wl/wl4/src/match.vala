namespace AstalWl4 {
private class GetWlOutputStateMachine {
    private Gdk.Monitor monitor;
    private AstalWl.Registry registry;
    private SourceFunc cb;

    private ulong monitor_connect_invalidate;
    private ulong monitor_connect_connector;
    private ulong registry_connect_add_output;

    private AstalWl.Output? output;

    private void finish() {
        if (monitor_connect_invalidate != 0) {
            monitor.disconnect(monitor_connect_invalidate);
            monitor_connect_invalidate = 0;
        }
        if (monitor_connect_connector != 0) {
            monitor.disconnect(monitor_connect_connector);
            monitor_connect_connector = 0;
        }
        if (registry_connect_add_output != 0) {
            registry.output_list_model.disconnect(registry_connect_add_output);
            registry_connect_add_output = 0;
        }

        // Never invoke the callback synchronously: if finish() runs inside
        // the constructor (immediate connector + output already known),
        // the async state machine hasn't advanced past the constructor
        // call yet, so the callback would re-enter get_wl_output from
        // state 0 and recurse infinitely.
        Idle.add((owned)cb);
    }

    private void invalidate() {
        output = null;
        finish();
    }

    public GetWlOutputStateMachine(Gdk.Monitor monitor, owned SourceFunc cb) {
        this.monitor = monitor;
        this.cb = (owned)cb;

        monitor_connect_invalidate = monitor.invalidate.connect(this.invalidate);
        if (monitor.connector != null) {
            debug("immediate with_connector");
            with_connector();
        } else {
            debug("delayed with_connector");
            monitor_connect_connector = monitor.notify["connector"].connect(this.with_connector);
        }
    }

    private void with_connector() {
        if (monitor_connect_connector != 0) {
            monitor.disconnect(monitor_connect_connector);
            monitor_connect_connector = 0;
        }

        registry = AstalWl.get_default();
        var output = registry.get_output_by_name(monitor.connector);
        if (output != null) {
            debug("immediate finish");
            this.output = output;
            finish();
        } else {
            debug("delayed finish");
            registry_connect_add_output = registry.output_list_model.items_changed.connect(this.handle_new_output);
        }
    }

    private void handle_new_output(uint pos, uint rem, uint add) {
        for (uint i = pos; i < pos + add; i++) {
            var output = (AstalWl.Output)registry.output_list_model.get_item(i);
            if (output.name == monitor.connector) {
                debug("found output");
                this.output = output;
                finish();
                break;
            }
        }
    }

    public AstalWl.Output? result() {
        return output;
    }
}

/**
 * Match a GDK monitor to the corresponding AstalWl output object.
 * It may take some time for the corresponding output to appear and initialize,
 * so this function is async.
 * This function can return null in edge cases, for example when the monitor
 * disappears during the matching process.
 */
public async AstalWl.Output? find_output_by_gdk_monitor(Gdk.Monitor monitor) {
        if (monitor.valid) {
            var match = new GetWlOutputStateMachine(monitor, find_output_by_gdk_monitor.callback);
            yield;
            return match.result();
        } else {
            return null;
        }
    }
}
