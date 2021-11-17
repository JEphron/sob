module main;

import std.stdio;
import std.string;
import std.file;

import graphics;
import input;
import utils;
import keyboard;

import models.editor;
import models.document;
import models.cursor;

class TextEditorState {
    Editor editor;
    Keyboard keyboard;
    KeyMapContainer keyContainer;
    Font font;
    int fontSize = 32;
    bool shouldQuit;
}

float textHeight(Font f, int fontSize) {
    return f.baseSize * fontSize/cast(float)f.baseSize;
}

void drawEditor(TextEditorState state, Editor editor) {
    import std.encoding;
    import std.conv;
    import std.ascii;
    import raylib : DrawTextCodepoint, GetFontDefault;

    Font font = state.font;
    auto fontSize = state.fontSize;
    auto document = editor.document;

    float textHeight = textHeight(font, fontSize);
    float scaleFactor = cast(float)fontSize / font.baseSize;

    int defaultFontSize = 10;   // Default Font chars height in pixel
    if (fontSize < defaultFontSize) fontSize = defaultFontSize;
    int spacing = fontSize / defaultFontSize;

    float y = 0;
    auto viewport = Viewport(0, document.lineCount, 0, 100);
    foreach(row, line; document.getViewport(viewport)) {
        float textOffsetX = 0.0f;

        foreach(i, codepoint; line.codePoints) {
            auto tint = Colors.GREEN;
            auto advance = getGlyphAdvance(font, codepoint) * scaleFactor + spacing;
            auto isCursor = row == editor.cursor.row && i == editor.cursor.column;
            auto pos = Vector2(textOffsetX, y);
            if (!isWhite(codepoint)) {
                DrawTextCodepoint(font, codepoint, pos, fontSize, tint);
            }

            if(isCursor) {
                auto glyphRect = Rectangle(pos.x, pos.y, advance, textHeight);
                drawCursor(editor.cursor, font, fontSize, codepoint, glyphRect, tint);
            }
            textOffsetX += advance;
        }
        y += textHeight;
    }
}

void drawCursor(Cursor cursor, Font font, int fontSize, dchar codepoint, Rectangle glyphRect, Color color) {
    import raylib : DrawTextCodepoint;
    final switch(cursor.mode) {
        case CursorMode.NORMAL:
            drawRectangle(glyphRect, color);
            DrawTextCodepoint(font, codepoint, glyphRect.pos, fontSize, invertColor(color));
            break;
        case CursorMode.INSERT:
            drawRectangle(Vector2(glyphRect.x, glyphRect.y), Vector2(1, glyphRect.height), color);
            break;
    }
}

float getGlyphAdvance(Font font, dchar codepoint) {
    import raylib: GetGlyphIndex;
    int index = GetGlyphIndex(font, codepoint);
    if (font.chars[index].advanceX == 0) {
        return cast(float)font.recs[index].width;
    }
    return cast(float)font.chars[index].advanceX;
}


void draw(TextEditorState state) {
    clearBackground(16, 16, 16);
    if(state.editor) {
        drawEditor(state, state.editor);
    }
}

abstract class KeyCommand {
    void run(TextEditorState state);
}

class QuitCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.shouldQuit = true;
    }
}

class MoveCursorKeyCommand : KeyCommand {
    int dx, dy;

    this(int dx, int dy) {
        this.dx = dx;
        this.dy = dy;
    }

    override void run(TextEditorState state) {
        if(!state.editor)
            return;
        state.editor.cursor.moveVertically(dy);
        state.editor.cursor.moveHorizontally(dx);
    }
}

class EnterModeCommand : KeyCommand {
    CursorMode mode;

    this(CursorMode mode) {
        this.mode = mode;
    }

    override void run(TextEditorState state) {
        if(!state.editor)
            return;
        state.editor.cursor.mode = this.mode;
    }
}

struct KeyBind {
    KeyboardKey key;
    KeyboardKey mod1;
    KeyboardKey mod2;
}

class KeyMap {
    private KeyCommand delegate()[KeyBind] keybinds;

    void add(KeyBind bind, lazy KeyCommand command) {
        keybinds[bind] = () => command();
    }

    KeyCommand match(KeyboardKey key, KeyboardKey[] modifiers) {
        import std.algorithm.searching: canFind;
        foreach(bind, fn; keybinds) {
            if(bind.key != key) continue;
            if(bind.mod1 && !modifiers.canFind(bind.mod1)) continue;
            if(bind.mod2 && !modifiers.canFind(bind.mod2)) continue;
            return fn();
        }
        return null;
    }
}

class KeyMapContainer {
    private KeyMap[CursorMode] modalMaps;

    this() {
        import std.traits;
        static foreach(mode; EnumMembers!CursorMode) {
            modalMaps[mode] = new KeyMap();
        }
    }

    void modeMap(CursorMode mode, void delegate(KeyMap map) registerBindings) {
        registerBindings(modalMaps[mode]);
    }

    void global(void delegate(KeyMap map) registerBindings) {
        foreach(map; modalMaps) {
            registerBindings(map);
        }
    }

    KeyMap current(CursorMode mode) {
        return modalMaps[mode];
    }
}

KeyMapContainer registerKeyCommands() {
    auto container = new KeyMapContainer();

    container.global((map) {
        map.add(KeyBind(KeyboardKey.KEY_D, KeyboardKey.KEY_LEFT_CONTROL), new QuitCommand());
    });

    container.modeMap(CursorMode.INSERT, (map) {
        map.add(KeyBind(KeyboardKey.KEY_ESCAPE), new EnterModeCommand(CursorMode.NORMAL));
    });

    container.modeMap(CursorMode.NORMAL, (map) {
        map.add(KeyBind(KeyboardKey.KEY_I), new EnterModeCommand(CursorMode.INSERT));
        map.add(KeyBind(KeyboardKey.KEY_H), new MoveCursorKeyCommand(-1, 0));
        map.add(KeyBind(KeyboardKey.KEY_J), new MoveCursorKeyCommand(0, 1));
        map.add(KeyBind(KeyboardKey.KEY_K), new MoveCursorKeyCommand(0, -1));
        map.add(KeyBind(KeyboardKey.KEY_L), new MoveCursorKeyCommand(1, 0));
    });

    return container;
}

void handleInput(TextEditorState state) {
    import core.time;
    auto modifiers = state.keyboard.heldModifiers();
    auto keymap = state.keyContainer.current(state.editor.cursor.mode);
    foreach(key; state.keyboard.justPressed) {
        if(auto match = keymap.match(key, modifiers))
            match.run(state);
    }

    int keyRepeatDelayMs = 100;
    int keyRepeatRateMs = 17;

    if(auto lastKey = state.keyboard.mostRecentlyPressedKey) {
        auto isReadyToBeginRepeating = !lastKey.hasBegunRepeating && lastKey.timeHeldMs > keyRepeatDelayMs;
        auto isReadyToRepeat = lastKey.hasBegunRepeating && lastKey.timeSinceRepeatMs > keyRepeatRateMs;

        if(lastKey.isDown && (isReadyToBeginRepeating || isReadyToRepeat)) {
            if(auto match = keymap.match(lastKey.key, modifiers))
                match.run(state);
            lastKey.timeOfLastRepeat = MonoTime.currTime;
        }
    }

}

/* void _handleCommand(TextEditorState state) { */
/*     int keyRepeatDelayMs = 100; */
/*     int keyRepeatRateMs = 17; */
/*     float timeSinceKeyPressed = 0; */
/*     float timeBetweenKeyRepeats = 0; */

/*     import std.algorithm; */
/*     import std.array; */
/*     auto justPressedKeys = updateKeys(state); */
/*     timeSinceKeyPressed += getDeltaTime() * 1000f; */
/*     if(justPressedKeys.length > 0) { */
/*         timeSinceKeyPressed = 0; */
/*     } */

/*     foreach(keyCommand; determineKeyCommand(justPressedKeys)) { */
/*         keyCommand.run(state); */
/*     } */

/*     if(timeSinceKeyPressed > keyRepeatDelayMs && timeBetweenKeyRepeats > keyRepeatRateMs) { */
/*         timeBetweenKeyRepeats = 0; */
/*         auto heldKeys = state.pressedKeys.byKeyValue.filter!(kv=>kv.value).map!(kv => kv.key).array; */
/*         foreach(keyCommand; determineKeyCommand(heldKeys)) { */
/*             keyCommand.run(state); */
/*         } */
/*     } */
/*     timeBetweenKeyRepeats += getDeltaTime() * 1000f; */
/* } */

Font loadFont() {
    import raylib : LoadFontEx;
    import std.string;
    auto fontPath = "/home/jephron/dev/personal/motherfuckingtexteditor/res/FiraMono-Regular.otf";
    return LoadFontEx(fontPath.toStringz, 32, null, 250);
}

void main(string[] args) {
    import raylib: SetExitKey;
    initWindow(1200, 1200, "MOFO TEXT EDITOR");

    auto state = new TextEditorState();
    auto documentPath = "/home/jephron/dev/personal/motherfuckingtexteditor/source/main.d";
    state.editor = Editor.fromFilepath(documentPath);
    state.font = loadFont();
    state.keyboard = new Keyboard();
    state.keyContainer = registerKeyCommands();

    setTargetFPS(60);
    SetExitKey(KeyboardKey.KEY_NULL); // don't close on escape-key press

    while(!windowShouldClose() && !state.shouldQuit) {
        beginDrawing();
        state.keyboard.update();
        handleInput(state);
        draw(state);
        endDrawing();
    }

    closeWindow();
}
