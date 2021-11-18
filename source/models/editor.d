module models.editor;

import models.document;
import models.cursor;

class Editor {
    Document document;
    Cursor cursor;
    Viewport viewport;

    private this(Document document, Cursor cursor) {
        this.document = document;
        this.cursor = cursor;
        this.viewport =  Viewport(0, 0, 40, 40);
    }

    static Editor fromFilepath(string filepath) {
        auto document = Document.open(filepath);
        return new Editor(document, new Cursor(document));
    }

    ViewportIterator visibleLines() {
        return document.getViewport(viewport);
    }

    void insertCharacter(dchar c) {
        document.insertCharacter(cursor.row, cursor.column, c);
        cursor.moveHorizontally(1);
    }

    void insertNewLine() {
        document.insertNewLine(cursor.row, cursor.column);
        cursor.moveVertically(1);
        cursor.moveToBeginningOfLine();
    }

    void deleteBeforeCursor() {
        document.deleteCharacter(cursor.row, cursor.column - 1);
    }

    void scrollToContain(Cursor cursor) {
        if(cursor.row > viewport.bottom - 1) {
            auto delta = cursor.row - viewport.bottom + 1;
            viewport.top += delta;
        }

        if(cursor.row < viewport.top) {
            auto delta = viewport.top - cursor.row;
            viewport.top -= delta;
        }

        if(cursor.column > viewport.right - 1) {
            auto delta = cursor.column - viewport.right + 1;
            viewport.left += delta;
        }

        if(cursor.column < viewport.left + 1) {
            auto delta = viewport.left - cursor.column;
            if (viewport.left - delta >= 0)
                viewport.left -= delta;
        }
    }
}
