/*

common.c ... Some simple functions.
Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
