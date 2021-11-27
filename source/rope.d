module rope;

import std.algorithm;
import std.stdio;
import std.format;
import std.conv;
import std.typecons;
import std.range;

version(unittest) import fluent.asserts;

struct RopeValue {
    size_t byteOffset;
    /* Point pointOffset; */

    @safe @nogc nothrow int opCmp(ref const RopeValue other) const {
        if(byteOffset < other.byteOffset) return -1;
        if(byteOffset > other.byteOffset) return 1;
        return 0;
    }

    @safe nothrow RopeValue opBinary(string op)(ref const RopeValue other) const {
        auto newByteOffset = mixin("byteOffset "~op~" other.byteOffset");
        return RopeValue(newByteOffset);
    }
}

alias RopeSplitResult = Tuple!(Rope, "left", Rope, "right");

interface Rope {
    // Return a new rope with the string s inserted beginning at position i.
    final Rope insert(size_t i, string s) {
        auto t = split(i);
        auto r1 = t.left.concat(new StringRope(s));
        return r1.concat(t.right);
    }

    // Return the character at position i.
    char index(size_t i);

    // Split the Rope into two new Ropes.
    RopeSplitResult split(size_t i);
    RopeValue value();
    ubyte depth();
    size_t length();
    string toString();

    final size_t opDollar() {
        return length();
    }

    final char opIndex(size_t i) {
        return index(i);
    }

    // Return a new Rope in which the argument is appended to this Rope.
    final Rope concat(Rope r) {
        return new ConcatRope(this, r);
    }

    // Return a new Rope with the substring i..j removed.
    final Rope removeAt(size_t i, size_t j) in(i <= j) {
        auto result1 = split(i);
        auto result2 = result1.right.split(j - i);
        return result1.left.concat(result2.right);
    }

    final RopeRange range() {
        return RopeRange(this);
    }

    final int opApply(scope int delegate(char) dg) {
        int result;
        foreach(c; range) {
            result = dg(c);
            if(result) break;
        }
        return result;
    }

}

struct RopeRange {
    static assert(isInputRange!RopeRange);
    static assert(isForwardRange!RopeRange);
    static assert(isBidirectionalRange!RopeRange);

    Rope rope;
    ulong _front;
    long _back;

    this(Rope rope) {
        this.rope = rope;
        _front = 0;
        _back = rope.length - 1;
    }

    RopeRange save() {
        return this;
    }

    @property char front() {
        return rope[_front];
    }

    @property char back() {
        return rope[_back];
    }

    @property bool empty() {
        return _front >= rope.length || _back < 0;
    }

    void popFront() {
        _front++;
    }

    void popBack() {
        _back--;
    }
}

class StringRope : Rope {
    string str;

    this(string str) {
        this.str = str;
    }

    char index(size_t i) {
        return str[i];
    }

    ubyte depth() {
        return 0;
    }

    size_t length() {
        return str.length;
    }

    RopeSplitResult split(size_t i) {
        return RopeSplitResult(
            new StringRope(str[0..i]),
            new StringRope(str[i..$])
        );
    }

    RopeValue value() {
        return RopeValue(str.length);
    }

    override string toString() {
        return str;
    }
}

class ConcatRope : Rope {
    Rope left;
    Rope right;

    this(Rope left, Rope right) {
        this.left = left;
        this.right = right;
    }

    ubyte depth() {
        auto childDepth = max(left.depth(), right.depth());
        return (childDepth + 1).to!ubyte;
    }

    char index(size_t i) {
        assert(i < length());

        if (i < left.length) {
            return left.index(i);
        }
        return right.index(i - left.length);
    }

    RopeSplitResult split(size_t i) {
        return RopeSplitResult(
            new SubstringRope(this, 0, i),
            new SubstringRope(this, i, length)
        );
    }

    RopeValue value() {
        return RopeValue(length()); // TODO: this is sus
    }

    size_t length() {
        return left.length() + right.length();
    }

    override string toString() {
        return left.toString() ~ right.toString();
    }
}

class SubstringRope : Rope {
    Rope rope;
    size_t minByte, maxByte, byteOffset;

    this(Rope rope, size_t minByte, size_t maxByte) {
        this.rope = rope;
        assert(maxByte <= rope.length(),
                format("SubstringRope maxByte (%s) must be <= rope length (%s)",
                    maxByte, rope.length()));
        this.minByte = minByte;
        this.maxByte = maxByte;
    }

    char index(size_t i) {
        assert(i < maxByte);
        auto ix = i + minByte;
        return rope.index(ix);
    }

    RopeSplitResult split(size_t i) {
        return RopeSplitResult(
            new SubstringRope(this, 0, i),
            new SubstringRope(this, i, length())
        );
    }

    RopeValue value() {
        return RopeValue(maxByte);
    }

    size_t length() {
        return maxByte - minByte;
    }

    ubyte depth() {
        return (rope.depth() + 1).to!ubyte;
    }

    override string toString() {
        // todo: bad
        return rope.toString()[minByte..maxByte];
    }
}

unittest {
    void assertSplits(Rope r, size_t i, string a, string b) {
        auto res = r.split(i);
        Assert.equal(res.left.toString(), a, "expected left split of \"" ~ r.to!string ~ "\" to be \"" ~ a ~ "\" but was \"" ~ res.left.to!string ~ "\"");
        Assert.equal(res.right.toString(), b, "expected right split of \"" ~ r.to!string ~ "\" to be \"" ~ b ~ "\" but was \"" ~ res.right.to!string ~ "\"");
    }
    auto s1 = new StringRope("hello world");
    s1.toString().should.equal("hello world");
    s1.index(0).should.equal('h');
    s1.index(1).should.equal('e');
    s1.index(10).should.equal('d');
    s1[$ - 1].should.equal('d');
    s1.value().should.equal(RopeValue(11));
    s1.depth().should.equal(0);

    assert(s1.split(1).left.toString() == "h");
    assert(s1.split(1).right.toString() == "ello world");
    assert(s1.split(1).right.toString() == "ello world");

    auto concatted = s1.concat(new StringRope(", nice to meet you!"));
    concatted.toString().should.equal("hello world, nice to meet you!");
    concatted.index(0).should.equal('h');
    concatted.index(13).should.equal('n');
    concatted.value().should.equal(RopeValue("hello world, nice to meet you!".length));
    concatted.depth().should.equal(1);

    auto inserted = concatted.insert(0, "well, ");
    inserted.toString().should.equal("well, hello world, nice to meet you!");
    inserted.removeAt(0, 6).toString().should.equal("hello world, nice to meet you!");

    Assert.equal(inserted.removeAt(0, 6).removeAt(5, 11).toString(), "hello, nice to meet you!");
    assertSplits(s1.removeAt(5, 6), 5, "hello", "world");
    new StringRope("abc").range.retro.array.should.equal(['c','b','a']);
}
