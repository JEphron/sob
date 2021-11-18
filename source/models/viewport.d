module models.viewport;

import std.math;
import settings;
import graphics: Vector2;
import models.document;
import std.encoding;
import utils;

struct Viewport {
    int top;
    int left;
    int width;
    int height;
    Document document;

    const int bottom() {
        return top + height;
    }

    const int right() {
        return left + width;
    }

    const int topRow() {
        return cast(int)floor(top / Settings.lineHeight);
    }

    const int bottomRow() {
        return cast(int)ceil(bottom / Settings.lineHeight);
    }

    const int rightColumn(int row) {
        // oh no...

        auto line = document.getLine(row);
        int numCodePoints = 0;
        float totalWidth = 0;
        foreach(ix, codePoint; line.codePoints) {
            totalWidth += getGlyphWidth(codePoint);
            if(totalWidth > right) {
                break;
            }
            numCodePoints++;
        }
        return numCodePoints;
    }

    const int leftColumn(int row) {
        // oh nooooo...

        auto line = document.getLine(row);
        int numCodePoints = 0;
        float totalWidth = 0;
        foreach(ix, codePoint; line.codePoints) {
            totalWidth += getGlyphWidth(codePoint);
            if(totalWidth > left) {
                break;
            }
            numCodePoints++;
        }
        return numCodePoints;
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
