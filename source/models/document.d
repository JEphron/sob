module models.document;

import std.path;
import std.conv;
import std.file;
import std.algorithm;
import std.stdio;
import std.string;
import models.cursor;

struct Viewport {
    int top;
    int bottom;
    int left;
    int right;

    invariant {
        assert(top > 0);
        assert(left > 0);
        assert(top < bottom);
        assert(left < right);
    }
}

struct ViewportIterator {
    const Viewport viewport;
    const Document document;

    int opApply(scope int delegate(int, string) dg) {
        int result = 0;

        auto bottom = clamp(viewport.bottom, 0, document.lines.length);
        auto top = clamp(viewport.top, 0, document.lines.length);
        for(int i = top; i < bottom; i++) {
            auto right = clamp(viewport.right, 0, document.lines[i].length);
            result = dg(i, document.lines[i][viewport.left..right]);
            if (result)
                break;
        }

        return result;
    }
}

class Document {
    private this(string filepath) {
        this.filepath = filepath;
        this.lines = std.file.readText(filepath).split('\n');
    }

    static Document open(string filepath) {
        return new Document(filepath);
    }

    const string filepath;
    private string[] lines;

    string name() {
        return baseName(filepath);
    }

    int lineCount() {
        return lines.length.to!int;
    }

    int lineLength(int line) {
        assert(line < lines.length);
        return lines[line].length.to!int;
    }

    const ViewportIterator getViewport(Viewport viewport) {
        return ViewportIterator(viewport, this);
    }

    void deleteCharacter(int row, int column) {
        import std.array;
        import std.algorithm.mutation;
        import std.conv;

        if(row < 0 || column < 0) return;
        auto arr = lines[row].array;
        arr = arr.remove(column);
        lines[row] = arr.to!string;
    }

    void insertCharacter(int row, int column, dchar ch) {
        import std.array;
        import std.conv;

        writeln("inserting ", ch.to!int);
        if(row < 0 || column < 0) return;
        auto arr = lines[row].array;
        arr.insertInPlace(column, ch);
        lines[row] = arr.to!string;
    }
}
