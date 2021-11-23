module models.point;

struct Point {
    int row;
    int column;

    pure int opCmp(ref const Point other) const nothrow @nogc @safe {
        if(row < other.row) return -1;
        if(row > other.row) return 1;
        if(column < other.column) return -1;
        if(column > other.column) return 1;
        return 0;
    }
}
