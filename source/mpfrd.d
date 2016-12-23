module mpfrd;

import deimos.mpfr;
import std.traits;

struct Mpfr {
    mpfr_t mpfr;
    alias mpfr this;

    @disable this();

    this(this) {
        mpfr_t new_mpfr;
        mpfr_init2(new_mpfr, mpfr_get_prec(mpfr));
        mpfr_set(new_mpfr, mpfr, mpfr_rnd_t.MPFR_RNDN);
        mpfr = new_mpfr;
    }

    this(T)(const T value, mpfr_prec_t p = 32) if(isNumeric!T) {
        mpfr_init2(mpfr, p);
        this = value;
    }

    ~this() {
        mpfr_clear(mpfr);
    }

    private static template isNumericValue(T) {
        enum isNumericValue = isNumeric!T || is(T == Mpfr);
    }

    private static string getTypeString(T)() {
        static if (isIntegral!T && isSigned!T) {
            return "_si";
        } else static if (isIntegral!T && !isSigned!T) {
            return "_ui";
        } else static if (is(T : double)) {
            return "_d";
        } else static if (is(T == Mpfr)) {
            return "";
        } else {
            static assert(false, "Unhandled type " ~ T.stringof);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // properties
    ////////////////////////////////////////////////////////////////////////////

    @property void precision(mpfr_prec_t p) {
        mpfr_set_prec(mpfr, p);
    }

    @property mpfr_prec_t precision() const {
        return mpfr_get_prec(mpfr);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Comparisons
    ////////////////////////////////////////////////////////////////////////////

    int opCmp(T)(const T value) const if(isNumericValue!T) {
        mixin("return mpfr_cmp" ~ getTypeString!T() ~ "(mpfr, value);");
    }

    int opCmp(ref const Mpfr value) {
        return this is value || mpfr_cmp(mpfr, value);
    }

    bool opEquals(T)(const T value) const if(isNumericValue!T) {
        return opCmp(value) == 0;
    }

    bool opEquals(ref const Mpfr value) {
        return this is value || opCmp(value) == 0;
    }

    private static string getOperatorString(string op)() {
        final switch(op) {
            case "+": return "_add";
            case "-": return "_sub";
            case "*": return "_mul";
            case "/": return "_div";
            case "^^": return "_pow";
        }
    }

    private static string getShiftOperatorString(string op)() {
        final switch(op) {
            case "<<": return "_mul";
            case ">>": return "_div";
        }
    }

    private static string getShiftTypeString(T)() {
        static if (isIntegral!T && isSigned!T) {
            return "_2si";
        } else static if (isIntegral!T && !isSigned!T) {
            return "_2ui";
        } else {
            static assert(false, "Unhandled type " ~ T.stringof);
        }
    }

    private static string getFunctionSuffix(string op, T, bool isRight) () {
        static if(op == "<<" || op == ">>") {
            static assert(!isRight, "Binary Right Shift not allowed, try using lower level mpfr_ui_pow.");
            return getShiftOperatorString!op() ~ getShiftTypeString!T();
        } else {
            return isRight ?
                getTypeString!T() ~ getOperatorString!op():
                getOperatorString!op() ~ getTypeString!T();
        }
    }

    private static string getFunction(string op, T, bool isRight) () {
        return "mpfr" ~ getFunctionSuffix!(op, T, isRight);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Arithmetic
    ////////////////////////////////////////////////////////////////////////////

    Mpfr opBinary(string op, T)(const T value) const if(isNumericValue!T) {
        auto output = Mpfr(0, mpfr_get_prec(mpfr));
        mixin(getFunction!(op, T, false)() ~ "(output, mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
        return output;
    }

    Mpfr opBinaryRight(string op, T)(const T value) const if(isNumericValue!T) {
        static if(op == "-" || op == "/" || op == "<<" || op == ">>") {
            auto output = Mpfr(0, mpfr_get_prec(mpfr));
            mixin(getFunction!(op, T, true)() ~ "(output, value, mpfr, mpfr_rnd_t.MPFR_RNDN);");
            return output;
        } else {
            return opBinary!op(value);
        }
    }

    Mpfr opUnary(string op)() const if(op == "-") {
        auto output = Mpfr(0, mpfr_get_prec(mpfr));
        mpfr_neg(output, mpfr, mpfr_rnd_t.MPFR_RNDN);
        return output;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Mutation
    ////////////////////////////////////////////////////////////////////////////

    ref Mpfr opAssign(T)(const T value) if(isNumericValue!T) {
        mixin("mpfr_set" ~ getTypeString!T() ~ "(mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
        return this;
    }

    ref Mpfr opAssign(ref const Mpfr value) {
        mpfr_set(mpfr, value, mpfr_rnd_t.MPFR_RNDN);
        return this;
    }

    ref Mpfr opOpAssign(string op, T)(const T value) if(isNumericValue!T) {
        static assert(!(op == "^^" && isFloatingPoint!T), "No operator ^^= with floating point.");
        mixin(getFunction!(op, T, false)() ~ "(mpfr, mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
        return this;
    }

    ref Mpfr opOpAssign(string op)(ref const Mpfr value) {
        if(value !is this) {
            mixin(getFunction!(op, T, false)() ~ "(mpfr, mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
        }
        return this;
    }

    ////////////////////////////////////////////////////////////////////////////
    // String
    ////////////////////////////////////////////////////////////////////////////

    string toString() const {
        char[1024] buffer;
        const count = mpfr_snprintf(buffer.ptr, buffer.sizeof, "%Rg".ptr, &mpfr);
        return buffer[0 .. count].idup;
    }
}

version (unittest)
{
    import std.meta;
    import std.stdio : writeln, writefln;
    alias AllNumericTypes = AliasSeq!(ubyte, ushort, uint, ulong, float, double, byte, short, int, long, Mpfr);
    alias AllIntegralTypes = AliasSeq!(ubyte, ushort, uint, ulong, byte, short, int, long, Mpfr);
    alias AllIntegralNoMpfr = AliasSeq!(ubyte, ushort, uint, ulong, byte, short, int, long);
}

unittest {
    // Assign from numeric type or another Mpfr
    auto value = Mpfr(0);
    value = 1;
    foreach(T ; AllNumericTypes) {
        value = T(1);
    }
}

unittest {
    // Copy
    auto a = Mpfr(0);
    auto b = Mpfr(0);
    a = 2;
    b = a;
    assert(b == 2);
}

unittest {
    // Comparisons
    auto value = Mpfr(0);
    value = 2;
    foreach(T ; AllNumericTypes) {
        assert(value == T(2));
        assert(value <= T(2));
        assert(value <= T(3));
        assert(value >= T(2));
        assert(value >= T(1));
    }
}

unittest {
    // opOpAssign
    auto value = Mpfr(1);
    assert(value == 1);
    value = value;
    assert(value == 1);
    foreach(T ; AllNumericTypes) {
        value = 2;
        value += T(2);
        assert(value == 4);
    }
    foreach(T ; AllNumericTypes) {
        value = 2;
        value -= T(2);
        assert(value == 0);
    }
    foreach(T ; AllNumericTypes) {
        value = 2;
        value *= T(3);
        assert(value == 6);
    }
    foreach(T ; AllNumericTypes) {
        value = 2;
        value /= T(2);
        assert(value == 1);
    }
    foreach(T ; AllIntegralTypes) {
        value = 2;
        value ^^= T(2);
        assert(value == 4);
    }
    foreach(T ; AllIntegralNoMpfr) {
        value = 2;
        value <<= 3;
        assert(value == 16);
    }
    foreach(T ; AllIntegralNoMpfr) {
        value = 16;
        value >>= 3;
        assert(value == 2);
    }
}

unittest {
    // opBinary && opRightBinary
    auto value = Mpfr(0);
    foreach(T ; AllNumericTypes) {
        value = 2;
        assert(value + T(2) == 4);
        assert(T(2) + value == 4);
    }
    foreach(T ; AllNumericTypes) {
        value = 3;
        assert(value - T(2) == 1);
        value = 2;
        assert(T(3) - value == 1);
    }
    foreach(T ; AllNumericTypes) {
        value = 2;
        assert(value * T(3) == 6);
        assert(T(3) * value == 6);
    }
    foreach(T ; AllNumericTypes) {
        value = 4;
        assert(value / T(2) == 2);
        value = 2;
        assert(T(6) / value == 3);
    }
    foreach(T ; AllIntegralTypes) {
        value = 2;
        assert(value ^^ T(2) == 4);
        assert(T(2) ^^ value == 4);
    }
    foreach(T ; AllIntegralNoMpfr) {
        value = 2;
        assert(value << T(3) == 16);
    }
    foreach(T ; AllIntegralNoMpfr) {
        value = 16;
        assert(value >> T(3) == 2);
    }
}

unittest {
    // precision
    auto value = Mpfr(0);
    assert(value.precision == 32);
    value.precision = 128;
    assert(value.precision == 128);
    assert((value + 1).precision == 128);
}