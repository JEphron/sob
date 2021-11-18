module settings;

import raylib: Font;

static class Settings {
    static int fontSize = 30;
    static int keyRepeatRateMs = 15;
    static int keyRepeatDelayMs = 20;
    static Font font;

    static float lineHeight() {
        return font.baseSize * fontSize/cast(float)font.baseSize;
    }
}
