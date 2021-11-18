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
import settings;

class TextEditorState {
    Editor editor;
    Keyboard keyboard;
    KeyMapContainer keyContainer;
    Font font;
    int fontSize = 30;
    bool shouldQuit;
}

void draw(TextEditorState state) {
    clearBackground(16, 16, 16);
    if(state.editor) {
        state.editor.draw();
    }
}

abstract class KeyCommand {
    void run(TextEditorState state);
}

class NewlineCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.insertNewLine();
    }
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
        if(dy) state.editor.cursor.moveVertically(dy);
        if(dx) state.editor.cursor.moveHorizontally(dx);
        state.editor.scrollToContain(state.editor.cursor);
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

class BackspaceCommand : KeyCommand {
    override void run(TextEditorState state) {
        if(!state.editor)
            return;
        auto needsMoveBack = !state.editor.cursor.isAtEndOfLine;
        state.editor.deleteBeforeCursor();
        if(needsMoveBack) {
            new MoveCursorKeyCommand(-1, 0).run(state);
        }
    }
}

class ChainedCommand : KeyCommand {
    KeyCommand[] commands;

    this(KeyCommand[] commands) {
        this.commands = commands;
    }

    override void run(TextEditorState state) {
        foreach(command; commands) {
            command.run(state);
        }
    }
}

class InsertNewlineAboveCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.insertNewLineAbove();
    }
}

class InsertNewlineBelowCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.insertNewLineBelow();
    }
}

struct KeyBind {
    KeyboardKey key;
    KeyboardKey mod1;
    KeyboardKey mod2;
}

struct KeyEvent {
    KeyboardKey key;
    KeyboardKey[] modifiers;

    bool hasModifier(KeyboardKey mod) {
        import std.algorithm;
        return modifiers.canFind(mod);
    }
}

class KeyMap {
    private KeyCommand delegate()[KeyBind] keybinds;
    private void delegate(KeyEvent) defaultAction;

    void add(KeyBind bind, lazy KeyCommand command) {
        keybinds[bind] = () => command();
    }

    void setDefault(void delegate(KeyEvent) fn) {
        defaultAction = fn;
    }

    KeyCommand match(KeyEvent event) {
        import std.algorithm.searching: canFind;
        foreach(bind, fn; keybinds) {
            if(bind.key != event.key) continue;
            if(bind.mod1 && !event.modifiers.canFind(bind.mod1)) continue;
            if(bind.mod2 && !event.modifiers.canFind(bind.mod2)) continue;
            return fn();
        }
        if(defaultAction) defaultAction(event);
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

KeyMapContainer registerKeyCommands(TextEditorState state) {
    auto container = new KeyMapContainer();

    container.global((map) {
        map.add(KeyBind(KeyboardKey.KEY_D, KeyboardKey.KEY_LEFT_CONTROL), new QuitCommand());
    });

    container.modeMap(CursorMode.INSERT, (map) {
        map.add(KeyBind(KeyboardKey.KEY_ESCAPE),
            new ChainedCommand([
                new MoveCursorKeyCommand(-1, 0),
                new EnterModeCommand(CursorMode.NORMAL)
            ]));
        map.add(KeyBind(KeyboardKey.KEY_BACKSPACE), new BackspaceCommand());
        map.add(KeyBind(KeyboardKey.KEY_ENTER), new NewlineCommand());
        map.setDefault((event) {
            import std.ascii;
            import std.conv;

            if(!event.key.isPrintable) return;

            auto ch = event.key.to!dchar;
            if(!event.hasModifier(KeyboardKey.KEY_LEFT_SHIFT)) {
                ch = ch.toLower();
            }
            state.editor.insertCharacter(ch);
            state.editor.scrollToContain(state.editor.cursor);
        });
    });

    container.modeMap(CursorMode.NORMAL, (map) {
        map.add(KeyBind(KeyboardKey.KEY_H), new MoveCursorKeyCommand(-1, 0));
        map.add(KeyBind(KeyboardKey.KEY_J), new MoveCursorKeyCommand(0, 1));
        map.add(KeyBind(KeyboardKey.KEY_K), new MoveCursorKeyCommand(0, -1));
        map.add(KeyBind(KeyboardKey.KEY_L), new MoveCursorKeyCommand(1, 0));

        map.add(KeyBind(KeyboardKey.KEY_O),
            new ChainedCommand([
                new InsertNewlineBelowCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );

        map.add(KeyBind(KeyboardKey.KEY_O, KeyboardKey.KEY_LEFT_SHIFT),
            new ChainedCommand([
                new InsertNewlineAboveCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );

        map.add(KeyBind(KeyboardKey.KEY_I), new EnterModeCommand(CursorMode.INSERT));
        map.add(KeyBind(KeyboardKey.KEY_A),
            new ChainedCommand([
                new MoveCursorKeyCommand(1, 0),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
    });

    return container;
}

void handleInput(TextEditorState state) {
    import core.time;
    auto modifiers = state.keyboard.heldModifiers();
    auto keymap = state.keyContainer.current(state.editor.cursor.mode);
    foreach(key; state.keyboard.justPressed) {
        if(auto match = keymap.match(KeyEvent(key, modifiers)))
            match.run(state);
    }

    int keyRepeatDelayMs = 120;
    int keyRepeatRateMs = 17;

    if(auto lastKey = state.keyboard.mostRecentlyPressedKey) {
        auto isReadyToBeginRepeating = !lastKey.hasBegunRepeating && lastKey.timeHeldMs > keyRepeatDelayMs;
        auto isReadyToRepeat = lastKey.hasBegunRepeating && lastKey.timeSinceRepeatMs > keyRepeatRateMs;

        if(lastKey.isDown && (isReadyToBeginRepeating || isReadyToRepeat)) {
            if(auto match = keymap.match(KeyEvent(lastKey.key, modifiers)))
                match.run(state);
            lastKey.timeOfLastRepeat = MonoTime.currTime;
        }
    }
}

string resourcePath(string path) {
    import std.path;
    return buildNormalizedPath(dirName(__FILE_FULL_PATH__) ~ "/../res/" ~ path);
}

Font loadFont() {
    import raylib : LoadFontEx;
    import std.string;
    auto fontPath = resourcePath("FiraMono-Regular.otf");
    return LoadFontEx(fontPath.toStringz, Settings.fontSize, null, 250);
}

void main(string[] args) {
    import raylib: SetExitKey;
    initWindow(Settings.windowWidth, Settings.windowHeight, ";_;");

    Settings.font = loadFont();

    auto state = new TextEditorState();
    auto documentPath = resourcePath("sample.json");
    state.editor = Editor.fromFilepath(documentPath);
    state.keyboard = new Keyboard();
    state.keyContainer = registerKeyCommands(state);

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
