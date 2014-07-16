/**
 * Name: CrashReporter
 * Type: iOS application
 * Desc: iOS app for viewing the details of a crash, determining the possible
 *       cause of said crash, and reporting this information to the developer(s)
 *       responsible.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

unsigned char nibble(char c) {
	if (c >= '0' && c <= '9')
		return c - '0';
	else if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	else if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	else
		return 0xFF;
}

int convertStringToInteger(const char* str, int len) {
	int res = 0;
	for (int i = 0; i < len; ++ i) {
		res *= 10;
		res += str[i] - '0';
	}
	return res;
}

unsigned long long convertHexStringToLongLong(const char* str, int len) {
	unsigned long long res = 0;
	for (int i = 0; i < len; ++ i) {
		unsigned char n = nibble(str[i]);
		if (n != 0xFF)
			res = res * 16 + n;
	}
	return res;
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
