module models.viewport;

import std.math;
import settings;
import graphics: Vector2;
import models.document;
import std.encoding;
import utils;

struct Viewport {
    float top;
    float left;
    float width;
    float height;
    Document document;

    const float bottom() {
        return top + height;
    }

    const float right() {
        return left + width;
    }

    const int topRow() {
        return cast(int)floor(top / Settings.lineHeight);
    }

    const int bottomRow() {
        return cast(int)ceil(bottom / Settings.lineHeight);
    }

    const int leftColumn() {
        return cast(int)ceil(left / Settings.glyphWidth);
    }

    const int rightColumn() {
        return cast(int)floor(right / Settings.glyphWidth);
    }

    void draw(Vector2 rootPosition) {
        import graphics;
        drawRectangleLines(Rectangle(rootPosition.x, rootPosition.y, width, height), Colors.RED);
    }

    invariant {
        assert(top >= 0, "top must be >= 0");
        assert(left >= 0, "left must be >= 0");
        assert(width > 0, "width must be > 0");
        assert(height > 0, "height must be > 0");
    }
}
