module main;

import std.stdio;
import std.string;
import std.file;
import std.conv;

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
    CommandPalette commandPalette;
    int fontSize = 30;
    bool shouldQuit;

    this() {
        keyboard = Keyboard.get();
    }
}

void draw(TextEditorState state) {
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

class InsertTabCommand : KeyCommand {
    override void run(TextEditorState state) {
        for(int i = 0; i < 4; i++)
            state.editor.insertCharacter(' ');
        state.editor.scrollToContain(state.editor.cursor);
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

class MoveCursorToEndOfLineCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.cursor.moveToEndOfLine();
    }
}

class MoveCursorToBeginningOfLineCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.cursor.moveToBeginningOfLine();
    }
}

class MoveCursorToEndOfDocumentCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.cursor.moveToLine(state.editor.document.lineCount-1);
        state.editor.scrollToContain(state.editor.cursor);
    }
}

class MoveCursorToBeginningOfDocumentCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.cursor.moveToLine(0);
        state.editor.scrollToContain(state.editor.cursor);
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
    char charValue = 0;
    Modifier mod1;
    Modifier mod2;

    this(KeyboardKey key) {
        this.key = key;
    }

    this(KeyboardKey key, Modifier mod1) {
        this.key = key;
        this.mod1 = mod1;
    }

    this(char charValue) {
        this.charValue = charValue;
    }

    this(char charValue, Modifier mod1) {
        this.charValue = charValue;
        this.mod1 = mod1;
    }

    bool hasModifier(Modifier mod) {
        return mod1 == mod || mod2 == mod;
    }

    bool match(KeyEvent event) {
        if(event.action == KeyAction.RELEASE) return false;

        if(charValue) {
            if(!event.charValue) return false;
            if(charValue != event.charValue) return false;
        }

        if(key) {
            if(!event.key) return false;
            if(key != event.key) return false;
        }

        if(mod1 && !event.hasModifier(mod1)) return false;
        if(mod2 && !event.hasModifier(mod2)) return false;
        return true;
    }

    string toMnemonic() {
        import std.traits: EnumMembers;
        import std.ascii;

        string s;

        foreach(modifier; EnumMembers!Modifier) {
            if(hasModifier(modifier) && modifier) {
                s ~= modifier.toString() ~ "-";
            }
        }

        if(key && key.isPrintable) {
            s ~= (cast(char)key).toLower();
        } else if(charValue) {
            s ~= charValue;
        }
        return s;
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
            if(bind.match(event)) return fn();
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
        map.add(KeyBind('d', Modifier.CONTROL), new QuitCommand());
    });

    container.modeMap(CursorMode.INSERT, (map) {
        map.add(KeyBind(KeyboardKey.KEY_ESCAPE),
            new ChainedCommand([
                new MoveCursorKeyCommand(-1, 0),
                new EnterModeCommand(CursorMode.NORMAL)
            ]));
        map.add(KeyBind(KeyboardKey.KEY_BACKSPACE), new BackspaceCommand());
        map.add(KeyBind(KeyboardKey.KEY_ENTER), new NewlineCommand());
        map.add(KeyBind(KeyboardKey.KEY_TAB), new InsertTabCommand());
        map.setDefault((event) {
            import std.ascii;

            if(!event.charValue) return;

            state.editor.insertCharacter(event.charValue);
            state.editor.scrollToContain(state.editor.cursor);
        });
    });

    container.modeMap(CursorMode.NORMAL, (map) {
        map.add(KeyBind('h'), new MoveCursorKeyCommand(-1, 0));
        map.add(KeyBind('j'), new MoveCursorKeyCommand(0, 1));
        map.add(KeyBind('k'), new MoveCursorKeyCommand(0, -1));
        map.add(KeyBind('l'), new MoveCursorKeyCommand(1, 0));
        map.add(KeyBind('o'),
            new ChainedCommand([
                new InsertNewlineBelowCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
        map.add(KeyBind('O'),
            new ChainedCommand([
                new InsertNewlineAboveCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
        map.add(KeyBind('i'), new EnterModeCommand(CursorMode.INSERT));
        map.add(KeyBind('a'),
            new ChainedCommand([
                new MoveCursorKeyCommand(1, 0),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
        map.add(KeyBind('A'),
            new ChainedCommand([
                new MoveCursorToEndOfLineCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
        map.add(KeyBind('I'),
            new ChainedCommand([
                new MoveCursorToBeginningOfLineCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
        map.add(KeyBind('G'),
            new MoveCursorToEndOfDocumentCommand(),
        );
    });

    return container;
}

abstract class Hydra {
    KeyBind trigger;
    string name;

    abstract Hydra descend(KeyEvent key);

}

class HydraExec : Hydra {
    void delegate() command;

    this(KeyBind trigger, string name, void delegate() command) {
        this.trigger = trigger;
        this.name = name;
        this.command = command;
    }

    override Hydra descend(KeyEvent key) {
        return this;
    }
}

class HydraSleeping : Hydra {
    Hydra contents;

    this(Hydra contents) {
        this.trigger = contents.trigger;
        this.name = contents.name;
        this.contents = contents;
    }

    override Hydra descend(KeyEvent key) {
        if(contents.trigger.match(key))
            return contents;
        return this;
    }
}

class HydraHead : Hydra {
    Hydra[] choices;

    this(KeyBind trigger, string name, Hydra[] choices) {
        this.name = name;
        this.trigger = trigger;
        this.choices = choices;
    }

    override Hydra descend(KeyEvent key) {
        foreach(hydra; choices) {
            if(hydra.trigger.match(key)) {
                return hydra;
            }
        }
        return this;
    }
}

class CommandPalette {
    Hydra traversal;
    Hydra initial;
    KeyEvent[] chord;

    this(Hydra initial) {
        this.initial = initial;
        this.traversal = initial;
        this.chord = new KeyEvent[0];
    }

    void onKeyUp(KeyEvent event) {
        auto next = traversal.descend(event);

        if(auto t = cast(HydraExec)next) {
            t.command();
            reset();
        } else if(next != traversal) {
            chord ~= event;
            traversal = next;
        }
    }

    void reset() {
        chord = new KeyEvent[0];
        traversal = initial;
    }

    void draw() {
        import std.algorithm;
        auto height = 150;
        auto padding =  50;
        auto corner = Vector2(padding , height);
        if(auto t = cast(HydraHead)traversal) {
            drawRectangle(
                corner,
                Vector2(Settings.windowWidth - padding * 2, height),
                Colors.DARKBLUE
            );

            drawText(
                chord.map!(c => c.toMnemonic).join(" "),
                corner, 32, Colors.WHITE
            );

            foreach(n, choice; t.choices) {
                drawText(
                    format("[%s] %s", choice.trigger.toMnemonic, choice.name),
                    corner + Vector2(10, Settings.lineHeight * (n + 1)),
                    32, Colors.MAGENTA
                );
            }
        }
    }
}

void handleInput(TextEditorState state) {
    auto keymap = state.keyContainer.current(state.editor.cursor.mode);
    foreach(event; state.keyboard) {
        /* state.commandPalette.onKeyUp(event); */
        if(auto match = keymap.match(event)) {
            match.run(state);
        }
    }
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
    setTargetFPS(60);
    SetExitKey(KeyboardKey.KEY_NULL); // don't close on escape-key press

    auto state = new TextEditorState();
    state.keyContainer = registerKeyCommands(state);
    state.editor = JSEditor.fromFile(resourcePath("jquery.js"));
    state.commandPalette = new CommandPalette(
            new HydraSleeping(
                new HydraHead(
                    KeyBind(';'),
                    "root",
                    [
                        new HydraExec(
                            KeyBind('q'),
                            "quit",
                            { state.shouldQuit = true; }
                        ),

                        new HydraHead(
                            KeyBind('f'),
                            "files",
                            [
                                new HydraExec(
                                    KeyBind('o'),
                                    "open",
                                    { writeln("should open a file"); }
                                ),
                                new HydraExec(
                                    KeyBind('s'),
                                    "save",
                                    { writeln("should save a file"); }
                                ),
                            ]
                        )
                    ]
                )
            )
    );

    while(!windowShouldClose() && !state.shouldQuit) {
        clearBackground(Colors.BLACK);
        beginDrawing();
        handleInput(state);
        draw(state);
        state.commandPalette.draw();
        drawFPS();
        endDrawing();
    }

    closeWindow();
}

void drawFPS() {
    drawText(getFPS().to!string, Vector2(0, 0), 10, Colors.WHITE);
}
