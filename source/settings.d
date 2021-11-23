module settings;

import raylib: Font;

static class Settings {
    static int windowWidth = 1200;
    static int windowHeight = 1200;
    static int fontSize = 32;
    static int keyRepeatRateMs = 15;
    static int keyRepeatDelayMs = 20;
    static Font font;

    static float lineHeight() {
        return font.baseSize * fontSize/cast(float)font.baseSize;
    }

    static float glyphWidth() {
        import graphics : measureText2d;
        auto cellSize = measureText2d(" ", Settings.font, Settings.fontSize, 1);
        return cellSize.x;
    }
}
