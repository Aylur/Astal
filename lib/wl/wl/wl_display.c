#include <dlfcn.h>
#include <stdlib.h>

struct wl_display* astal_wl_get_wl_display() {
    struct wl_display *(*get_wl_display_func)(void *);
    void *(*get_gdk_display_func)();

    get_gdk_display_func = dlsym(RTLD_DEFAULT, "gdk_display_get_default");

    if (!get_gdk_display_func)
        return NULL;
    
    get_wl_display_func = dlsym(RTLD_DEFAULT, "gdk_wayland_display_get_wl_display");
    if (!get_wl_display_func)
        return NULL;

    void* display = get_gdk_display_func();
    if(!display) return NULL;
    return get_wl_display_func(display);
}
