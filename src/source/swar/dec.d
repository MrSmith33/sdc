module source.swar.dec;

/**
 * Check we have enough digits in front of us to use SWAR.
 */
bool startsWith8DecDigits(string s, ref ulong state) {
	ulong v;
	if (s.length >= 8) {
		import source.swar.util;
		v = read!ulong(s);
	} else {
		foreach (i; 0 .. s.length) {
			v |= s[i] << (i * 8);
		}
	}

	// Set the high bit if the character isn't between '0' and '9'.
	auto lessThan0 = v - 0x3030303030303030;
	auto moreThan9 = v + 0x4646464646464646;

	// Combine
	auto c = lessThan0 | moreThan9;

	// Check that none of the high bits are set.
	state = c & 0x8080808080808080;
	return state == 0;
}

uint getDigitCount(ulong state)
		in(state != 0 && (state & 0x8080808080808080) == state) {
	import core.bitop;
	return bsf((state * 0x0002040810204081) >> 56);
}

unittest {
	static check(string s, uint count) {
		ulong state;
		if (startsWith8DecDigits(s, state)) {
			assert(count >= 8);
		} else {
			assert(getDigitCount(state) == count);
		}
	}

	check("", 0);

	static bool isDecChar(char c) {
		return '0' <= c && c <= '9';
	}

	// Test all combinations of 2 characters.
	foreach (char c0; 0 .. 256) {
		immutable char[1] s0 = [c0];
		auto isC0Dec = isDecChar(c0);

		check(s0[], isC0Dec);

		foreach (char c1; 0 .. 256) {
			immutable char[2] s1 = [c0, c1];
			auto isC1Dec = isDecChar(c1);

			check(s1[], isC0Dec + (isC0Dec && isC1Dec));

			static immutable char[] Chars = ['0', '9'];
			foreach (char c3; Chars) {
				foreach (char c4; Chars) {
					immutable char[4] s2 = [c0, c1, c3, c4];
					check(s2[], isC0Dec + 3 * (isC0Dec && isC1Dec));

					immutable char[4] s3 = [c4, c3, c1, c0];
					check(s3[], 2 + isC1Dec + (isC0Dec && isC1Dec));

					immutable char[8] s4 = [c0, c1, c0, c1, c0, c1, c3, c4];
					check(s4[], isC0Dec + 7 * (isC0Dec && isC1Dec));

					immutable char[8] s5 = [c4, c3, c3, c4, c3, c4, c1, c0];
					check(s5[], 6 + isC1Dec + (isC0Dec && isC1Dec));
				}
			}
		}
	}
}

/**
 * Parse decimal numbers using SWAR.
 *
 * http://0x80.pl/notesen/2014-10-12-parsing-decimal-numbers-part-1-swar.html
 * Archive: https://archive.ph/1xl45
 *
 * https://lemire.me/blog/2022/01/21/swar-explained-parsing-eight-digits/
 * Archive: https://archive.ph/of2xZ
 */
private auto loadBuffer(T)(string s) in(s.length >= T.sizeof) {
	auto v = *(cast(T*) s.ptr);

	/**
	 * We could simply go for
	 *     return v & cast(T) 0x0f0f0f0f0f0f0f0f;
	 * but this form is prefered as the computation is
	 * already done in startsWith8DecDigits.
	 */
	return v - cast(T) 0x3030303030303030;
}

ubyte parseDecDigits(T : ubyte)(string s) in(s.length >= 2) {
	uint v = loadBuffer!ushort(s);
	v = (2561 * v) >> 8;
	return v & 0xff;
}

unittest {
	foreach (s, v; ["00": 0, "09": 9, "10": 10, "28": 28, "42": 42, "56": 56,
	                "73": 73, "99": 99]) {
		ulong state;
		assert(!startsWith8DecDigits(s, state), s);
		assert(getDigitCount(state) == 2, s);
		assert(parseDecDigits!ubyte(s) == v, s);
	}
}

ushort parseDecDigits(T : ushort)(string s) in(s.length >= 4) {
	// v = [a, b, c, d]
	auto v = loadBuffer!uint(s);

	// v = [ba, dc]
	v = (2561 * v) >> 8;
	v &= 0x00ff00ff;

	// dcba
	v *= 6553601;
	return v >> 16;
}

unittest {
	foreach (s, v; ["0000": 0, "0123": 123, "4567": 4567, "5040": 5040,
	                "8901": 8901, "9999": 9999]) {
		ulong state;
		assert(!startsWith8DecDigits(s, state), s);
		assert(getDigitCount(state) == 4, s);
		assert(parseDecDigits!ushort(s) == v, s);
	}
}

uint parseDecDigits(T : uint)(string s) in(s.length >= 8) {
	// v = [a, b, c, d, e, f, g, h]
	auto v = loadBuffer!ulong(s);

	// v = [ba, dc, fe, hg]
	v *= 2561;

	// a = [fe00ba, fe]
	auto a = (v >> 24) & 0x000000ff000000ff;
	a *= 0x0000271000000001;

	// b = [hg00dc00, hg00]
	auto b = (v >> 8) & 0x000000ff000000ff;
	b *= 0x000F424000000064;

	// hgfedcba
	return (a + b) >> 32;
}

unittest {
	foreach (s, v;
		["00000000": 0, "01234567": 1234567, "10000019": 10000019,
		 "34567890": 34567890, "52350178": 52350178, "99999999": 99999999]) {
		ulong state;
		assert(startsWith8DecDigits(s, state), s);
		assert(parseDecDigits!uint(s) == v, s);
	}
}
