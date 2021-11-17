module models.viewport;

struct Viewport {
    // right now these are in "cell" coordinates, so row/column
    // however, for correctness they should be in pixels
    // this means that the Editor must be able to determine which characters lie within
    // a given pixelspace rect
    // to do this, we'll start with the lineHeight (which is constant)
    // bottom > lineHeight * nLines > top
    // then we'll do codepoints, so for each line
    // start from the beginning, measuring each codepoint and summing the width
    // until we exceed 'left'. Then yield codepoints until the sum exceeds 'right'.

    int top;
    int left;
    int width;
    int height;

    const int bottom() {
        return top + height;
    }

    const int right() {
        return left + width;
    }

    void draw() {
        import graphics;
        drawRectangleLines(Rectangle( left, top, width, height), Colors.RED);
    }

    invariant {
        assert(top >= 0);
        assert(left >= 0);
        assert(width > 0);
        assert(height > 0);
    }
}
