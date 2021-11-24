module models.cursor;

import std.algorithm: clamp;
import models.document;
import graphics;
import settings;
import utils;

enum CursorMode {
    NORMAL,
    INSERT
}

class Cursor {
    Document document;
    CursorMode mode = CursorMode.NORMAL;
    private int _row = 5;
    private int _column = 5;

    this(Document document) {
        this.document = document;
    }

    int row() {
        return _row;
    }

    int column() {
        auto lineLen = document.lineLength(row);
        if (lineLen == 0) return 0;
        return clamp(_column, 0, lineLen);
    }

    void setColumn(int newColumn) {
        _column = newColumn;
    }

    void moveVertically(int dy) {
        if(dy == 0) return;
        _row = clamp(_row + dy, 0, document.lineCount - 1);
    }

    void moveToLine(int line) {
        _row = clamp(line, 0, document.lineCount - 1);
    }

    void moveHorizontally(int dx) {
        if(dx == 0) return;
        if(_column > column())
            _column = column();
        _column += dx;
        if(_column < 0) _column = 0;
    }

    void moveToEndOfLine() {
        _column = document.lineLength(row);
    }

    void moveToBeginningOfLine() {
        _column = 0;
    }

    bool isAtEndOfLine() {
        return column() == document.lineLength(row);
    }

    void draw(dchar codepoint, Rectangle glyphRect, Color color) {
        import raylib : DrawTextCodepoint;
        final switch(mode) {
            case CursorMode.NORMAL:
                drawRectangle(glyphRect, color);
                color = invertColor(color);
                DrawTextCodepoint(Settings.font, codepoint, glyphRect.pos, Settings.fontSize, color);
                break;
            case CursorMode.INSERT:
                drawRectangle(Vector2(glyphRect.x, glyphRect.y), Vector2(1, glyphRect.height), color);
                break;
        }
    }
}
