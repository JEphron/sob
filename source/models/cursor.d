module models.cursor;

import std.algorithm: clamp;
import models.document;

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
        import std.stdio;
        if (lineLen == 0) return 0;
        return clamp(_column, 0, lineLen);
    }

    void moveVertically(int dy) {
        if(dy == 0) return;
        _row = clamp(_row + dy, 0, document.lineCount - 1);
    }

    void moveHorizontally(int dx) {
        if(dx == 0) return;
        if(_column > column())
            _column = column();
        _column += dx;
        if(_column < 0) _column = 0;
    }

    void moveToBeginningOfLine() {
        _column = 0;
    }

    bool isAtEndOfLine() {
        return column() == document.lineLength(row);
    }
}
