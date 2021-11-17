module models.editor;

import models.document;
import models.cursor;

class Editor {
    Document document;
    Cursor cursor;

    private this(Document document, Cursor cursor) {
        this.document = document;
        this.cursor = cursor;
    }

    static Editor fromFilepath(string filepath) {
        auto document = Document.open(filepath);
        return new Editor(document, new Cursor(document));
    }

    void insertCharacter(dchar c) {
        document.insertCharacter(cursor.row, cursor.column, c);
        cursor.moveHorizontally(1);
    }

    void deleteBeforeCursor() {
        document.deleteCharacter(cursor.row, cursor.column - 1);
    }
}
