module models.document;

import std.path;
import std.conv;
import std.file;
import std.algorithm;
import std.stdio;
import std.string;

import settings;
import std.array;
import std.conv;
import std.encoding : codePoints;
import models.cursor;
import models.viewport;
import models.point;
import utils;

struct ViewportCodePointIterator {
    const Viewport viewport;
    const Document document;

    int opApply(scope int delegate(Point, dchar) dg) {
        int result = 0;

        foreach(row; viewport.topRow..viewport.bottomRow) {
            if(row >= document.lineCount) break;
            auto line = document.lines[row];
            foreach(column, codePoint; line.codePoints) {
                if(column < viewport.leftColumn) continue;
                if(column > viewport.rightColumn) break;
                result = dg(Point(row.to!int, column.to!int), codePoint);
                if(result) break;
            }
        }

        return result;
    }
}

struct ViewportIterator {
    const Viewport viewport;
    const Document document;

    int opApply(scope int delegate(int, string) dg) {
        int result = 0;

        foreach(row, line; document.lines) {
            dg(row.to!int, line);
        }


        return result;
    }
}


class Document {
    const string filepath;
    private string[] lines;

    private this(string filepath, string contents) {
        this.filepath = filepath;
        this.lines = contents.split('\n');
    }

    static Document open(string filepath) {
        auto contents = std.file.readText(filepath);
        return new Document(filepath, contents);
    }

    static Document fromString(string contents) {
        return new Document("", contents);
    }

    string textContent() {
        return lines.join('\n');
    }

    string name() {
        return baseName(filepath);
    }

    const int lineCount() {
        return lines.length.to!int;
    }

    int lineLength(int line) {
        assert(line < lines.length);
        return getLine(line).length.to!int;
    }

    const ViewportIterator getViewport(Viewport viewport) {
        return ViewportIterator(viewport, this);
    }

    const ViewportCodePointIterator getCodepointsInViewport(Viewport viewport) {
        return ViewportCodePointIterator(viewport, this);
    }

    const string getLine(int row) {
        return lines[row];
    }

    void deleteCharacter(int row, int column) {
        if(row < 0 || column < 0) return;
        auto arr = getLine(row).array;
        arr = arr.remove(column);
        lines[row] = arr.to!string;
    }

    void insertCharacter(int row, int column, dchar ch) {
        if(row < 0 || column < 0) return;
        auto arr = getLine(row).array;
        arr.insertInPlace(column, ch);
        lines[row] = arr.to!string;
    }

    void insertNewLine(int row, int column) {
        if(row < 0 || column < 0) return;
        auto arr = lines[row].array;
        auto a1 = arr[0..column];
        auto a2 = arr[column..$];
        lines = lines.remove(row);
        lines.insertInPlace(row, a2.to!string);
        lines.insertInPlace(row, a1.to!string);
    }

    void joinLinesUpwards(int row) {
        auto line = lines[row];
        lines[row-1] = lines[row-1] ~ line;
        lines = lines.remove(row);
    }
}
