namespace AstalWl {
/**
 * A simple 2D axis-aligned rectangle with integer coordinates.
 *
 * Used throughout the AstalWl library to represent output geometry,
 * window bounds, and other screen regions.
 */
public struct Rectangle {
    public int x;
    public int y;
    public int width;
    public int height;


    /**
     * Creates a zero-sized rectangle at position (0,0).
     */
    public Rectangle.zero() {
        this.x = 0;
        this.y = 0;
        this.width = 0;
        this.height = 0;
    }

    /**
     * Creates an exact copy of this rectangle.
     */
    public Rectangle copy() {
        return Rectangle() {
                x = this.x,
                y = this.y,
                width = this.width,
                height = this.height
        };
    }

    /**
     * Normalizes the rectangle to ensure positive width and height.
     *
     * If width or height are negative, adjusts the origin (x,y) so
     * the rectangle always represents a valid region with top-left
     * origin and positive extent.
     */
    public void normalize() {
        if (this.width < 0) {
            this.x += this.width;
            this.width = -1 * this.width;
        }
        if (this.height < 0) {
            this.y += this.height;
            this.height = -1 * this.height;
        }
    }

    /**
     * Computes the intersection of two rectangles.
     *
     * If no intersection exists, `result` is set to a zero rectangle and
     * `false` is returned.
     */
    public static bool intersect(Rectangle a, Rectangle b, out Rectangle result) {
        Rectangle ra = a.copy();
        Rectangle rb = b.copy();

        ra.normalize();
        rb.normalize();

        int x1 = int.max(ra.x, rb.x);
        int y1 = int.max(ra.y, rb.y);
        int x2 = int.min(ra.x + ra.width, rb.x + rb.width);
        int y2 = int.min(ra.y + ra.height, rb.y + rb.height);

        if ((x1 >= x2) || (y1 >= y2)) {
            result = Rectangle.zero();
            return false;
        }
        result = Rectangle() {
            x = x1,
            y = y1,
            width = x2 - x1,
            height = y2 - y1
        };
        return true;
    }
}
}
